// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./interfaces/ICentherStaking.sol";

enum ClaimDuration {
    Hourly,
    Daily,
    Weekly,
    Monthly,
    Quarterly,
    HalfYearly,
    Yearly
}

enum RefMode {
    NoReward,
    FixedReward,
    TimeBasedReward
}

struct PoolCreationInputs {
    address stakeToken;
    address rewardToken;
    uint256 annualStakingRewardRate;
    uint256 minStakeAmount;
    uint256 maxStakeAmount;
    uint256 stakingDurationPeriod;
    uint8 claimDuration;
    uint8 rewardModeForRef;
    uint256 firstReward;
    uint256 maxStakableAmount;
    uint256 cancellationFees;
    string poolMetadata;
    bool isUnstakable;
    bool isLP;
    string metadata;
}

struct PoolInfo {
    address poolOwner;
    address stakeToken;
    address rewardToken;
    uint256 rewardSupply;
    uint256 annualStakingRewardRate;
    uint256 stakingDurationPeriod;
    uint8 claimDuration;
    uint256 totalStakedAmount;
    uint256 minStakeAmount;
    uint256 maxStakeAmount;
    uint256 firstRewardDuration;
    uint256 maxStakableAmount;
    RefMode rewardModeForRef;
    uint256 cancellationFees;
    bool isUnstakable;
    bool isLP;
    bool isActive;
}

struct AffiliateSetting {
    uint256 level;
    uint256 percent;
}

struct AffiliateSettingInput {
    uint256 level_one;
    uint256 level_two;
    uint256 level_three;
    uint256 level_four;
    uint256 level_five;
    uint256 level_six;
}

struct Stake {
    uint256 stakingDuration;
    uint256 stakedAmount;
    uint256 stakedTime;
    uint256 lastRewardClaimed;
    uint256 claimedReward;
}

contract CentherStaking {
    error Locked();
    error PoolNotExist();
    error NotRegistered();
    error PoolNotActive();
    error AlreadySetted();
    error InvalidRewardRate();
    error InvalidStakeAmount();
    error InvalidTokenAddress();
    error OnlyPoolOwnerCanAccess();
    error MaxStakableAmountReached();
    error PoolOwnerNotEligibleToStake();
    error ValueNotEqualToPlatformFees();
    error GiveMaxAllowanceOfRewardToken();
    error CannotSetAffiliateSettingForActivePool();

    event StakingPoolCreated(PoolInfo poolInfo, string metadataUri);
    event AmountStaked(uint256 poolId, address user, uint256 amount);
    event AmountUnstaked(uint256 poolId, address user, uint256 amount);
    event RewardClaimed(uint256 poolId, address user, uint256 amount);
    event AffiliateSettingSet(uint256, AffiliateSetting[]);
    event PoolStateChanged(uint256, bool);
    event RefRewardPaid(uint256, address, uint256, address);

    mapping(uint256 => PoolInfo) public _poolsInfo;
    mapping(uint256 => AffiliateSetting[]) public _affiliateSettings;
    mapping(uint256 => mapping(address => Stake[])) public _userStakes;
    mapping(uint256 => mapping(address => address)) public _userReferrer;

    uint256 referralDeep = 6;
    uint256 public platformFees = 0.00001 ether;
    address public platform;
    IRegistration public register;
    uint256 public poolIds;

    uint256 constant _HOURLY = 1 hours;
    uint256 constant _DAY = _HOURLY * 24;
    uint256 constant _WEEK = _DAY * 7;
    uint256 constant _MONTH = _WEEK * 4;
    uint256 constant _QUARTER = _MONTH * 4;
    uint256 constant _HALF_YEAR = _MONTH * 6;
    uint256 constant _YEAR = _MONTH * 12;

    constructor(address _registration, address _platform) {
        register = IRegistration(_registration);
        platform = _platform;
    }

    modifier onlyRegisterUser() {
        if (!(register.isRegistered(msg.sender))) {
            revert NotRegistered();
        }
        _;
    }

    modifier onlyPoolOwner(uint256 _poolId) {
        if (msg.sender != idToPoolInfo[_poolId].poolOwner) {
            revert OnlyPoolOwnerCanAccess();
        }
        _;
    }

    modifier nonReentrant() {
        require(_unlocked == 1);
        _unlocked = 2;
        _;
        _unlocked = 1;
    }

    // main functions:
    function createPool(
        PoolCreationInputs calldata _info
    ) external payable onlyRegisterUser {
        if (_info.stakeToken == address(0)) {
            revert InvalidTokenAddress();
        }

        if (
            _info.annualStakingRewardRate > 10000 &&
            _info.annualStakingRewardRate == 0
        ) {
            revert InvalidRewardRate();
        }

        if (rewardAllowance != type(uint256).max) {
            revert GiveMaxAllowanceOfRewardToken();
        }

        if (msg.value < platformFees) {
            revert ValueNotEqualToPlatformFees();
        }

        uint256 rewardAllowance = IERC20(idToPoolInfo[newPoolId].rewardToken)
            .allowance(msg.sender, address(this));

        payable(platform).transfer(msg.value);

        poolIds++;
        uint256 newPoolId = poolIds;

        RefMode memory refMode = RefMode(_info.rewardModeForRef);

        _poolsInfo[newPoolId] = PoolInfo({
            minStakeAmount: _info.minStakeAmount,
            maxStakeAmount: _info.maxStakeAmount,
            rewardModeForRef: refMode,
            firstRewardDuration: _info.firstReward,
            maxStakableAmount: _info.maxStakableAmount,
            cancellationFees: _info.cancellationFees,
            isUnstakable: _info.isUnstakable,
            isLP: _info.isLP,
            isActive: refMode == RefMode.NoReward ? true : false, //it stays false untill owner set affiliate settings
            poolOwner: msg.sender,
            stakeToken: _info.stakeToken,
            rewardToken: _info.rewardToken == address(0)
                ? _info.stakeToken
                : _info.rewardToken,
            rewardSupply: 0,
            annualStakingRewardRate: _info.annualStakingRewardRate,
            stakingDurationPeriod: _info.stakingDurationPeriod,
            totalStakedAmount: 0,
            claimDuration: _info.claimDuration
        });

        emit StakingPoolCreated(_poolsInfo[newPoolId], _info.metadata);
    }

    function setAffiliateSetting(
        uint256 _poolId,
        AffiliateSettingInput _setting
    ) external onlyPoolOwner(_poolId) {
        PoolInfo memory pool = _poolsInfo[_poolId];
        if (pool.isActive) {
            revert CannotSetAffiliateSettingForActivePool();
        }

        _affiliateSettings[_poolId].push(
            AffiliateSetting({level: 1, percent: _setting.level_one})
        );

        _affiliateSettings[_poolId].push(
            AffiliateSetting({level: 2, percent: _setting.level_two})
        );

        _affiliateSettings[_poolId].push(
            AffiliateSetting({level: 3, percent: _setting.level_three})
        );

        _affiliateSettings[_poolId].push(
            AffiliateSetting({level: 4, percent: _setting.level_four})
        );

        _affiliateSettings[_poolId].push(
            AffiliateSetting({level: 5, percent: _setting.level_five})
        );

        _affiliateSettings[_poolId].push(
            AffiliateSetting({level: 6, percent: _setting.level_six})
        );

        pool.isActive = true;

        emit AffiliateSettingSet(newPoolId, _affiliateSettings[_poolId]);
    }

    function togglePoolState(
        uint256 _poolId,
        bool _newState
    ) external onlyPoolOwner(_poolId) {
        if (_poolsInfo[_poolId].isActive == _newState) {
            revert AlreadySetted();
        }

        idToPoolInfo[_poolId].poolSetting.isActive = _newState;
        emit PoolStateChanged(_poolId, _newState);
    }

    function stake(
        uint256 _poolId,
        uint256 _amount,
        address referrer
    ) external override {
        if (poolIds < _poolId) {
            revert PoolNotExist();
        }

        PoolInfo memory _poolInfo = _poolsInfo[_poolId];

        if (!_poolInfo.isActive) {
            revert PoolNotActive();
        }

        if (msg.sender == _poolInfo.poolOwner) {
            revert PoolOwnerNotEligibleToStake();
        }

        if (
            _poolInfo.minStakeAmount > 0 && _poolInfo.minStakeAmount > _amount
        ) {
            revert InvalidStakeAmount();
        }

        if (
            _poolInfo.maxStakeAmount > 0 && _poolInfo.maxStakeAmount < _amount
        ) {
            revert InvalidStakeAmount();
        }

        if (
            _poolInfo.maxStakableAmount < _poolInfo.totalStakedAmount + _amount
        ) {
            revert MaxStakableAmountReached();
        }

        if (
            _poolInfo.minStakeAmount > 0 &&
            _amount % _poolInfo.minStakeAmount != 0
        ) {
            revert InvalidStakeAmount();
        }

        address poolOwner = _poolInfo.poolOwner;
        Stake memory stake = Stake({
            stakingDuration: block.timestamp + _poolInfo.claimDuration,
            stakedAmount: msg.value,
            stakedTime: block.timestamp,
            lastRewardClaimed: block.timestamp,
            claimedReward: 0
        });

        _userStakes[_poolId][msg.sender].push(stake);
        _userReferrer[_poolId][msg.sender] = referrer;

        if (_poolInfo.poolSetting.isLP) {
            uint256 totalReward = _calcReward(
                _poolId,
                _poolInfo.stakingDurationPeriod,
                msg.value
            );

            if (_poolInfo.rewardModeForRef == RefMode.TimeBasedReward) {
                address[] memory referrers = getReferrerAddresses(msg.sender);
                AffiliateSetting[] memory levelsInfo = _affiliateSettings[
                    _poolId
                ];

                uint256 refReward;
                for (uint8 i = 0; i < referrers.length; i++) {
                    if (
                        referrers[i] != address(0) && levelsInfo[i].percent != 0
                    ) {
                        refReward +=
                            (((_amount * levelsInfo[i].percent) / 10000) *
                                _poolInfo.stakingDurationPeriod) /
                            _MONTH;
                    }
                }
                totalReward += refReward;
            }

            IERC20(_poolInfo.rewardToken).transferFrom(
                poolOwner,
                address(this),
                totalReward
            );

            IERC20(_poolInfo.stakeToken).transferFrom(
                msg.sender,
                address(this),
                _amount
            );
        } else {
            IERC20(_poolInfo.stakeToken).transferFrom(
                msg.sender,
                poolOwner,
                _amount
            );
        }

        if (_poolInfo.rewardModeForRef == RefMode.FixedReward) {
            address[] memory referrers = getReferrerAddresses(msg.sender);
            AffiliateSetting[] memory levelsInfo = _affiliateSettings[_poolId];

            for (uint8 i = 0; i < referrers.length; i++) {
                if (referrers[i] != address(0) && levelsInfo[i].percent != 0) {
                    uint256 _rewardAmount = (_amount * levelsInfo[i].percent) /
                        10000;

                    IERC20(_poolInfo.rewardToken).transferFrom(
                        poolOwner,
                        referrers[i],
                        _rewardAmount
                    );

                    emit RefRewardPaid(
                        _poolId,
                        msg.sender,
                        _rewardAmount,
                        referrers[i]
                    );
                }
            }
        }

        emit AmountStaked(_poolId, msg.sender, _amount);
    }

    function unstake(
        uint256 _poolId,
        uint256 _amount
    ) external override nonReentrant {
        PoolInfo memory _poolInfo = _poolsInfo[_poolId];

        (unstakableAmount, unstakablesStakes) = _calcUserUnstakable(_poolId);

        if (unstakableAmount == 0 && _poolInfo.isUnstakable == false) {
            revert Lock();
        }

        uint256 _amountToCancel = 0;
        uint256 sendingAmountToStaker = 0;
        uint256 sendingAmountToOwner = 0;

        if (unstakableAmount > 0) {
            uint256 _remained = _amount;
            for (uint256 i; i < unstakablesStakes.length; i++) {
                if (unstakablesStakes[i].stakedAmount >= _remained) {
                    unstakablesStakes[i].stakedAmount -= _remained;
                    _remained = 0;
                    break;
                } else {
                    _remained -= unstakablesStakes[i].stakedAmount;
                    unstakablesStakes[i].stakedAmount = 0;
                }
            }

            if (_remained > 0) {
                _amountToCancel = _remained;
            }
        } else {
            _amountToCancel = _amount;
        }

        if (_amountToCancel > 0) {
            Stake[] stakes = _getUserValidStakes(_poolId);
            //TODO => sort stakes by desc
            uint256 remainedToCancel = _amountToCancel;
            uint256 refundRefReward = 0;

            address[] memory referrers = getReferrerAddresses(msg.sender);
            AffiliateSetting[] memory levelsInfo = _affiliateSettings[_poolId];

            for (uint256 i; i < stakes.length; i++) {
                if (stakes[i].stakedAmount >= remainedToCancel) {
                    stakes[i].stakedAmount -= remainedToCancel;

                    if (_poolInfo.rewardModeForRef == RefMode.TimeBasedReward) {
                        for (uint8 i = 0; i < referrers.length; i++) {
                            if (
                                referrers[i] != address(0) &&
                                levelsInfo[i].percent != 0
                            ) {
                                refundRefReward +=
                                    (((remainedToCancel *
                                        levelsInfo[i].percent) / 10000) *
                                        stakes[i].stakingDuration -
                                        stakes[i].lastRewardClaimed) /
                                    _MONTH;
                            }
                        }
                    }

                    remainedToCancel = 0;
                    break;
                } else {
                    remainedToCancel -= stakes[i].stakedAmount;

                    if (_poolInfo.rewardModeForRef == RefMode.TimeBasedReward) {
                        for (uint8 i = 0; i < referrers.length; i++) {
                            if (
                                referrers[i] != address(0) &&
                                levelsInfo[i].percent != 0
                            ) {
                                refundRefReward +=
                                    (((stakes[i].stakedAmount *
                                        levelsInfo[i].percent) / 10000) *
                                        stakes[i].stakingDuration -
                                        stakes[i].lastRewardClaimed) /
                                    _MONTH;
                            }
                        }
                    }

                    stakes[i].stakedAmount = 0;
                }
            }

            uint256 fee = (_amountToCancel * _poolInfo.cancellationFees) /
                10000;
            sendingAmountToStaker = _amount - fee;
            sendingAmountToOwner = fee + refundRefReward;
        } else {
            sendingAmountToStaker = _amount;
            sendingAmountToOwner = 0;
        }

        if (_poolInfo.isLP) {
            if (sendingAmountToOwner > 0) {
                IERC20(_poolInfo[_poolId].stakeToken).transfer(
                    _poolInfo.poolOwner,
                    sendingAmountToOwner
                );
            }

            if (sendingAmountToStaker > 0) {
                IERC20(_poolInfo[_poolId].stakeToken).transfer(
                    _poolInfo.poolOwner,
                    sendingAmountToStaker
                );
            }
        } else {
            uint256 _amountToSendFromOwnerToStaker = sendingAmountToStaker -
                sendingAmountToOwner;
            IERC20(_poolInfo[_poolId].stakeToken).transferFrom(
                _info.poolOwner,
                msg.sender,
                _amountToSendFromOwnerToStaker
            );
        }

        emit AmountUnstaked(_poolId, msg.sender, _amount);
    }

    function claimReward(uint256 _poolId) public override {
        PoolInfo memory _poolInfo = _poolsInfo[_poolId];
        Stake[] memory stakes = _getUserValidStakes(_poolId);
        uint256 _claimableReward;
        for (uint256 i; i < _stakes.length; i++) {
            uint256 passdTime = block.timestamp - _stakes[i].lastRewardClaimed;
            if (passdTime >= _poolInfo.claimDuration) {
                uint256 reward = _calcReward(
                    _poolId,
                    passdTime,
                    _stakes[i].stakedAmount
                );

                if (
                    _stakes[i].lastRewardClaimed == _stakes[i].stakedTime &&
                    passdTime < _poolInfo.firstRewardDuration
                ) {
                    reward = 0;
                }

                if (reward != 0) {
                    _claimableReward += reward;
                    _stakes[i].claimedReward += reward;
                    _stakes[i].lastRewardClaimed = block.timestamp;
                }
            }
        }

        if (_claimableReward > 0) {
            if (_poolInfo.isLP) {
                IERC20(_poolInfo.rewardToken).transfer(
                    msg.sender,
                    _claimableReward
                );
            } else {
                IERC20(_poolInfo.rewardToken).transferFrom(
                    _poolInfo.poolOwner,
                    msg.sender,
                    _claimableReward
                );
            }
        }

        emit RewardClaimed(_poolId, msg.sender, _claimableReward);
    }

    // utility functions
    function _calcReward(
        uint256 _poolId,
        uint256 _duration,
        uint256 _amount
    ) internal view returns (uint256) {
        PoolInfo memory _poolInfo = _poolsInfo[_poolId];
        return
            (_amount * _poolInfo.annualStakingRewardRate * _duration) /
            (10000 * _YEAR);
    }

    function _calcUserUnstakable(
        uint256 _poolId
    )
        internal
        view
        returns (uint256 unstakableAmount, Stake[] unstakablesStakes)
    {
        Stake[] memory _stakes = _userStakes[_poolId][msg.sender];
        for (uint256 i; i < _stakes.length; i++) {
            if (
                _stakes[i].stakingDuration > block.timestamp &&
                _stakes[i].stakedAmount > 0
            ) {
                stakes.push(_stakes[i]);
                unstakableAmount += _stakes[i].stakedAmount;
            }
        }

        return (unstakableAmount, unstakablesStakes);
    }

    function _getUserValidStakes(
        uint256 _poolId
    ) internal view returns (Stake[] stakes) {
        Stake[] memory _stakes = _userStakes[_poolId][msg.sender];

        for (uint256 i; i < _stakes.length; i++) {
            if (
                _stakes[i].stakingDuration < block.timestamp &&
                _stakes[i].stakedAmount > 0
            ) {
                stakes.push(_stakes[i]);
            }
        }

        return stakes;
    }

    function getReferrerAddresses(
        address _user
    ) external view returns (address[] memory referrerAddresses) {
        address userAddress = _user;
        referrerAddresses = new address[](referralDeep);

        for (uint8 i = 0; i < referralDeep; i++) {
            address referrerAddress = _userReferrer[userAddress];
            referrerAddresses[i] = referrerAddress;
            userAddress = referrerAddress;
        }
        return referrerAddresses;
    }
}
