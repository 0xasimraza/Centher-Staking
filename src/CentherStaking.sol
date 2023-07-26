// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./interfaces/ICentherStaking.sol";

contract CentherStaking is ICentherStaking {
    uint8 private _unlocked;

    uint256 constant _HOURLY = 1 hours;
    uint256 constant _DAY = 1 days;
    uint256 constant _WEEK = 1 weeks;
    uint256 constant _MONTH = 2620800;
    uint256 constant _QUARTER = 10483200;
    uint256 constant _HALF_YEAR = _MONTH * 6;
    uint256 constant _YEAR = 31449600;

    IRegistration public register;

    uint256 referralDeep;
    uint256 public platformFees;
    address public platform;

    uint256 public poolIds;

    mapping(uint256 => PoolInfo) public poolsInfo;
    mapping(uint256 => AffiliateSetting[]) public affiliateSettings;
    mapping(uint256 => mapping(address => Stake[])) public userStakes;
    mapping(uint256 => mapping(address => address)) public userReferrer;

    constructor(address _registration, address _platform) {
        register = IRegistration(_registration);
        platform = _platform;
        _unlocked = 1;
        platformFees = 0.00001 ether;
        referralDeep = 6;
    }

    //uncomment before deployment
    // function initialize(address _registration, address _platform) public {
    //     register = IRegistration(_registration);
    //     platform = _platform;
    //     _unlocked = 1;
    //     platformFees = 0.00001 ether;
    //     referralDeep = 6;
    // }

    modifier onlyRegisterUser() {
        if (!(register.isRegistered(msg.sender))) {
            revert NotRegistered();
        }
        _;
    }

    modifier onlyPoolOwner(uint256 _poolId) {
        if (msg.sender != poolsInfo[_poolId].poolOwner) {
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
    ) external payable override onlyRegisterUser {
        if (_info.stakeToken == address(0)) {
            revert InvalidTokenAddress();
        }

        if (
            _info.annualStakingRewardRate > 10000 ||
            _info.annualStakingRewardRate == 0
        ) {
            revert InvalidRewardRate();
        }

        poolIds++;
        uint256 newPoolId = poolIds;

        if (msg.value < platformFees) {
            revert ValueNotEqualToPlatformFees();
        }

        payable(platform).transfer(msg.value);

        if (_info.rewardModeForRef >= 3) {
            revert InvalidRewardMode();
        }

        RefMode refMode = RefMode(_info.rewardModeForRef);

        PoolSetting memory _setting = PoolSetting({
            firstRewardDuration: _info.firstReward,
            maxStakableAmount: _info.maxStakableAmount,
            cancellationFees: _info.cancellationFees,
            isUnstakable: _info.isUnstakable,
            isLP: _info.isLP,
            isActive: refMode == RefMode.NoReward ? true : false //it stays false untill owner set affiliate settings
        });

        poolsInfo[newPoolId] = PoolInfo({
            minStakeAmount: _info.minStakeAmount,
            maxStakeAmount: _info.maxStakeAmount,
            rewardModeForRef: refMode,
            poolOwner: msg.sender,
            stakeToken: _info.stakeToken,
            rewardToken: _info.rewardToken == address(0)
                ? _info.stakeToken
                : _info.rewardToken,
            annualStakingRewardRate: _info.annualStakingRewardRate,
            stakingDurationPeriod: _info.stakingDurationPeriod,
            claimDuration: _info.claimDuration,
            setting: _setting
        });

        uint256 rewardAllowance = IERC20(poolsInfo[newPoolId].rewardToken)
            .allowance(msg.sender, address(this));

        if (rewardAllowance != type(uint256).max) {
            revert GiveMaxAllowanceOfRewardToken();
        }

        emit StakingPoolCreated(poolsInfo[newPoolId], _info.poolMetadata);
    }

    function setAffiliateSetting(
        uint256 _poolId,
        AffiliateSettingInput memory _setting
    ) external onlyPoolOwner(_poolId) {
        PoolInfo memory pool = poolsInfo[_poolId];
        if (pool.setting.isActive) {
            revert CannotSetAffiliateSettingForActivePool();
        }

        affiliateSettings[_poolId].push(
            AffiliateSetting({level: 1, percent: _setting.levelOne})
        );

        affiliateSettings[_poolId].push(
            AffiliateSetting({level: 2, percent: _setting.levelTwo})
        );

        affiliateSettings[_poolId].push(
            AffiliateSetting({level: 3, percent: _setting.levelThree})
        );

        affiliateSettings[_poolId].push(
            AffiliateSetting({level: 4, percent: _setting.levelFour})
        );

        affiliateSettings[_poolId].push(
            AffiliateSetting({level: 5, percent: _setting.levelFive})
        );

        affiliateSettings[_poolId].push(
            AffiliateSetting({level: 6, percent: _setting.levelSix})
        );

        poolsInfo[_poolId].setting.isActive = true;

        emit AffiliateSettingSet(_poolId, affiliateSettings[_poolId]);
    }

    function togglePoolState(
        uint256 _poolId,
        bool _newState
    ) external onlyPoolOwner(_poolId) {
        if (poolsInfo[_poolId].setting.isActive == _newState) {
            revert AlreadySetted();
        }

        poolsInfo[_poolId].setting.isActive = _newState;
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

        PoolInfo memory _poolInfo = poolsInfo[_poolId];

        if (!_poolInfo.setting.isActive) {
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

        if (_poolInfo.setting.maxStakableAmount < _amount) {
            revert MaxStakableAmountReached();
        }

        //this condition not working fine, mostly on some decimal precision stake values
        // if (
        //     _poolInfo.minStakeAmount > 0 &&
        //     _amount % _poolInfo.minStakeAmount != 0
        // ) {
        //     revert InvalidStakeAmount();
        // }

        address poolOwner = _poolInfo.poolOwner;
        Stake memory _stake = Stake({
            stakingDuration: block.timestamp + _poolInfo.stakingDurationPeriod, //fixed replace claimDuration with staking duration
            stakedAmount: _amount,
            stakedTime: block.timestamp,
            lastRewardClaimed: block.timestamp,
            claimedReward: 0
        });

        userStakes[_poolId][msg.sender].push(_stake);
        userReferrer[_poolId][msg.sender] = referrer;

        if (_poolInfo.setting.isLP) {
            uint256 totalReward = _calcReward(
                _poolId,
                _poolInfo.stakingDurationPeriod,
                _amount
            );

            if (_poolInfo.rewardModeForRef == RefMode.TimeBasedReward) {
                address[] memory referrers = _getReferrerAddresses(
                    _poolId,
                    msg.sender
                );
                AffiliateSetting[] memory levelsInfo = affiliateSettings[
                    _poolId
                ];

                uint256 refReward;
                for (uint8 i; i < referrers.length; i++) {
                    if (
                        referrers[i] != address(0) && levelsInfo[i].percent != 0
                    ) {
                        unchecked {
                            refReward +=
                                (((_amount * levelsInfo[i].percent) / 10000) *
                                    _poolInfo.stakingDurationPeriod) /
                                _MONTH;
                        }
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
            address[] memory referrers = _getReferrerAddresses(
                _poolId,
                msg.sender
            );
            AffiliateSetting[] memory levelsInfo = affiliateSettings[_poolId];

            for (uint8 i; i < referrers.length; i++) {
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
        (
            uint256 unstakableAmount,
            Stake[] memory unstakablesStakes
        ) = _calcUserUnstakable(_poolId);

        if (
            unstakableAmount == 0 &&
            poolsInfo[_poolId].setting.isUnstakable == false
        ) {
            revert Locked();
        }

        uint256 _amountToCancel;
        uint256 sendingAmountToStaker;
        uint256 sendingAmountToOwner;

        if (unstakableAmount > 0) {
            uint256 _remained = _amount;
            for (uint256 i; i < unstakablesStakes.length; i++) {
                if (unstakablesStakes[i].stakedAmount >= _remained) {
                    unstakablesStakes[i].stakedAmount -= _remained;
                    userStakes[_poolId][msg.sender][i]
                        .stakedAmount -= _remained;

                    _remained = 0;
                    break;
                } else {
                    _remained -= unstakablesStakes[i].stakedAmount;
                    // console2.log("***2***: ", _remained);
                    userStakes[_poolId][msg.sender][i].stakedAmount = 0;
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
            Stake[] memory stakes = _getUserValidStakes(_poolId);

            uint256 remainedToCancel = _amountToCancel;
            uint256 refundRefReward = 0;

            address[] memory referrers = _getReferrerAddresses(
                _poolId,
                msg.sender
            );
            AffiliateSetting[] memory levelsInfo = affiliateSettings[_poolId];

            for (uint256 i; i < stakes.length; i++) {
                if (stakes[i].stakedAmount >= remainedToCancel) {
                    stakes[i].stakedAmount -= remainedToCancel;
                    userStakes[_poolId][msg.sender][i]
                        .stakedAmount -= remainedToCancel;

                    if (
                        poolsInfo[_poolId].rewardModeForRef ==
                        RefMode.TimeBasedReward
                    ) {
                        for (uint8 i = 0; i < referrers.length; i++) {
                            if (
                                referrers[i] != address(0) &&
                                levelsInfo[i].percent != 0
                            ) {
                                unchecked {
                                    refundRefReward +=
                                        (((remainedToCancel *
                                            levelsInfo[i].percent) / 10000) *
                                            stakes[i].stakingDuration -
                                            stakes[i].lastRewardClaimed) /
                                        _MONTH;
                                }
                            }
                        }
                    }

                    remainedToCancel = 0;
                    break;
                } else {
                    remainedToCancel -= stakes[i].stakedAmount;

                    if (
                        poolsInfo[_poolId].rewardModeForRef ==
                        RefMode.TimeBasedReward
                    ) {
                        for (uint8 i = 0; i < referrers.length; i++) {
                            if (
                                referrers[i] != address(0) &&
                                levelsInfo[i].percent != 0
                            ) {
                                unchecked {
                                    refundRefReward +=
                                        (((stakes[i].stakedAmount *
                                            levelsInfo[i].percent) / 10000) *
                                            stakes[i].stakingDuration -
                                            stakes[i].lastRewardClaimed) /
                                        _MONTH;
                                }
                            }
                        }
                    }

                    stakes[i].stakedAmount = 0;
                    userStakes[_poolId][msg.sender][i].stakedAmount = 0;
                }
            }

            uint256 fee = (_amountToCancel *
                poolsInfo[_poolId].setting.cancellationFees) / 10000;
            sendingAmountToStaker = _amount - fee;
            sendingAmountToOwner = fee + refundRefReward;
        } else {
            sendingAmountToStaker = _amount;
            sendingAmountToOwner = 0;
        }

        if (poolsInfo[_poolId].setting.isLP) {
            if (sendingAmountToOwner > 0) {
                IERC20(poolsInfo[_poolId].stakeToken).transfer(
                    poolsInfo[_poolId].poolOwner,
                    sendingAmountToOwner
                );
            }

            if (sendingAmountToStaker > 0) {
                IERC20(poolsInfo[_poolId].stakeToken).transfer(
                    msg.sender,
                    sendingAmountToStaker
                );
            }
        } else {
            IERC20(poolsInfo[_poolId].stakeToken).transferFrom(
                poolsInfo[_poolId].poolOwner,
                msg.sender,
                sendingAmountToStaker
            );
        }

        emit AmountUnstaked(_poolId, msg.sender, _amount);
    }

    function claimReward(uint256 _poolId) public override {
        PoolInfo memory _poolInfo = poolsInfo[_poolId];
        Stake[] memory _stakes = userStakes[_poolId][msg.sender];
        uint256 _claimableReward;

        for (uint256 i; i < _stakes.length; i++) {
            uint256 passdTime = block.timestamp - _stakes[i].lastRewardClaimed;

            passdTime = block.timestamp + passdTime > _stakes[i].stakingDuration
                ? _stakes[i].stakingDuration - _stakes[i].lastRewardClaimed
                : passdTime;

            if (passdTime >= _poolInfo.claimDuration) {
                uint256 reward = _calcReward(
                    _poolId,
                    passdTime,
                    _stakes[i].stakedAmount
                );

                if (
                    _stakes[i].lastRewardClaimed == _stakes[i].stakedTime &&
                    passdTime < _poolInfo.setting.firstRewardDuration
                ) {
                    reward = 0;
                }

                if (reward != 0) {
                    _claimableReward += reward;
                    // _stakes[i].claimedReward += reward;              bug -> updating memory state
                    // _stakes[i].lastRewardClaimed = block.timestamp;

                    userStakes[_poolId][msg.sender][i].claimedReward += reward;
                    userStakes[_poolId][msg.sender][i].lastRewardClaimed = block
                        .timestamp;
                }
            }
        }

        if (_claimableReward > 0) {
            if (_poolInfo.setting.isLP) {
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

    function claimRewardForRef(
        uint256 _poolId,
        address _user
    ) external override {
        PoolInfo memory poolInfo = poolsInfo[_poolId];
        if (poolInfo.rewardModeForRef != RefMode.TimeBasedReward) {
            revert PoolRefModeIsNotTimeBased();
        }

        AffiliateSetting[] memory affilateSetting = affiliateSettings[_poolId];

        address referrer = userReferrer[_poolId][_user];

        uint256 levels = type(uint256).max;

        uint256 totalReward;
        uint256 reward;

        for (uint256 i; i < affilateSetting.length; i++) {
            if (referrer == msg.sender) {
                levels = i;
            } else {
                referrer = userReferrer[_poolId][_user];
            }
        }

        if (levels == type(uint256).max) {
            revert NotValidReferral();
        }

        uint256 percent = affilateSetting[levels].percent;
        Stake[] memory _stakes = userStakes[_poolId][referrer];

        for (uint256 i; i < _stakes.length; i++) {
            uint256 passdTime = block.timestamp - _stakes[i].lastRewardClaimed;

            passdTime = block.timestamp + passdTime > _stakes[i].stakingDuration
                ? _stakes[i].stakingDuration - _stakes[i].lastRewardClaimed
                : passdTime;
            if (passdTime > _MONTH) {
                unchecked {
                    reward =
                        (_stakes[i].stakedAmount * (passdTime) * percent) /
                        (_MONTH * 10000);
                }

                userStakes[_poolId][referrer][i].lastRewardClaimed = block
                    .timestamp;
                userStakes[_poolId][referrer][i].claimedReward += reward;
                totalReward += reward;
            }
        }

        if (poolInfo.setting.isLP) {
            IERC20(poolInfo.rewardToken).transfer(msg.sender, totalReward);
        } else {
            IERC20(poolInfo.rewardToken).transferFrom(
                poolInfo.poolOwner,
                msg.sender,
                totalReward
            );
        }
        emit RewardClaimed(_poolId, msg.sender, totalReward);
    }

    // utility functions
    function _calcReward(
        uint256 _poolId,
        uint256 _duration,
        uint256 _amount
    ) internal view returns (uint256) {
        PoolInfo memory _poolInfo = poolsInfo[_poolId];
        return
            (_amount * _poolInfo.annualStakingRewardRate * _duration) /
            (10000 * _YEAR);
    }

    function _calcUserUnstakable(
        uint256 _poolId
    ) internal view returns (uint256 unstakableAmount, Stake[] memory) {
        Stake[] memory _stakes = userStakes[_poolId][msg.sender];
        Stake[] memory unstakablesStakes = new Stake[](_stakes.length);

        for (uint256 i; i < _stakes.length; i++) {
            if (
                _stakes[i].stakingDuration < block.timestamp &&
                _stakes[i].stakedAmount > 0
            ) {
                unstakablesStakes[i] = (_stakes[i]);
                unstakableAmount += _stakes[i].stakedAmount;
            }
        }

        return (unstakableAmount, unstakablesStakes);
    }

    function _getUserValidStakes(
        uint256 _poolId
    ) internal view returns (Stake[] memory) {
        Stake[] memory _stakes = userStakes[_poolId][msg.sender];

        Stake[] memory stakes = new Stake[](_stakes.length);

        for (uint256 i; i < _stakes.length; i++) {
            if (
                _stakes[i].stakingDuration > block.timestamp &&
                _stakes[i].stakedAmount > 0
            ) {
                stakes[i] = _stakes[i];
            }
        }

        return stakes;
    }

    function _getReferrerAddresses(
        uint256 _poolId,
        address _user
    ) internal view returns (address[] memory referrerAddresses) {
        address userAddress = _user;
        referrerAddresses = new address[](referralDeep);

        for (uint8 i; i < referralDeep; i++) {
            address referrerAddress = userReferrer[_poolId][userAddress];
            referrerAddresses[i] = referrerAddress;
            userAddress = referrerAddress;
        }
        return referrerAddresses;
    }
}
