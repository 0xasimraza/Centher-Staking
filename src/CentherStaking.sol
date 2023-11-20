// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./interfaces/ICentherStaking.sol";

/// @title Centher Staking as a service
/// @notice Users can launch their staking projects
/// @notice Users can stake on different pools for juicy rewards.
contract CentherStaking is ICentherStaking {
    uint8 private _unlocked;

    uint256 constant _HOURLY = 1 hours;
    uint256 constant _DAY = 1 days;
    uint256 constant _WEEK = 1 weeks;
    uint256 constant _MONTH = 30 days;
    uint256 constant _QUARTER = 90 days;
    uint256 constant _HALF_YEAR = 180 days;
    uint256 constant _YEAR = 360 days;

    IRegistration public register;

    uint256 referralDeep;
    uint256 public platformFees;
    address public platform;

    uint256 public poolIds;

    mapping(uint256 => PoolInfo) public poolsInfo;
    mapping(uint256 => AffiliateSetting[]) public affiliateSettings;
    mapping(uint256 => mapping(address => Stake[])) public userStakes;
    mapping(uint256 => mapping(address => address)) public userReferrer;

    mapping(bytes32 => uint256) public refDetails;

    bool private initialized;

    modifier onlyCitizen() {
        if (register.isCitizen(msg.sender) < block.timestamp) {
            revert NotCitizen();
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

    function initialize(address _registration, address _platform) public {
        require(!initialized, "Contract instance has already been initialized");
        initialized = true;
        register = IRegistration(_registration);
        _unlocked = 1;
        platform = _platform;
        platformFees = 1 ether;
        referralDeep = 6;
    }

    ///@inheritdoc ICentherStaking
    function createPool(PoolCreationInputs calldata _info)
        external
        payable
        override
        onlyCitizen
        returns (uint256 newPoolId)
    {
        if (_info.stakeToken == address(0)) {
            revert InvalidTokenAddress();
        }

        if (_info.annualStakingRewardRate > 10000 || _info.annualStakingRewardRate == 0) {
            revert InvalidRewardRate();
        }

        if (_info.showOnCenther) {
            if (msg.value < platformFees) {
                revert ValueNotEqualToPlatformFees();
            }

            payable(platform).transfer(msg.value);
        }
        if (_info.rewardModeForRef >= 3) {
            revert InvalidRewardMode();
        }

        if (_info.startTime < block.timestamp) {
            revert InvalidStartTime();
        }

        if (_info.isLP) {
            if (_info.maxStakableAmount < 0) {
                revert InvalidMaxStakableAmount();
            }
        }

        if (_info.taxationPercent > 10000) {
            revert InvalidTaxationPercent();
        }

        poolIds++;
        newPoolId = poolIds;

        RefMode refMode = RefMode(_info.rewardModeForRef);

        PoolSetting memory _setting = PoolSetting({
            firstRewardDuration: _info.firstReward,
            maxStakableAmount: _info.maxStakableAmount,
            cancellationFees: _info.cancellationFees,
            isUnstakable: _info.isUnstakable,
            isLP: _info.isLP,
            isActive: refMode == RefMode.NoReward ? true : false,
            showOnCenther: _info.showOnCenther
        });

        poolsInfo[newPoolId] = PoolInfo({
            minStakeAmount: _info.minStakeAmount,
            maxStakeAmount: _info.maxStakeAmount,
            rewardModeForRef: refMode,
            poolOwner: msg.sender,
            stakeToken: _info.stakeToken,
            rewardToken: _info.rewardToken == address(0) ? _info.stakeToken : _info.rewardToken,
            annualStakingRewardRate: _info.annualStakingRewardRate,
            stakingDurationPeriod: _info.stakingDurationPeriod,
            claimDuration: _info.claimDuration,
            rate: _info.rate == 0 ? 1e18 : _info.rate,
            setting: _setting,
            startTime: _info.startTime,
            taxationPercent: _info.taxationPercent
        });

        uint256 rewardAllowance = IERC20(poolsInfo[newPoolId].rewardToken).allowance(msg.sender, address(this));

        if (_info.isLP) {
            if (rewardAllowance != type(uint256).max) {
                revert GiveMaxAllowanceOfRewardToken();
            }
        } else {
            uint256 stakeTknAllowance = IERC20(poolsInfo[newPoolId].stakeToken).allowance(msg.sender, address(this));

            if (stakeTknAllowance != type(uint256).max) {
                revert GiveMaxAllowanceOfStakeToken();
            }

            if (poolsInfo[newPoolId].stakeToken != poolsInfo[newPoolId].rewardToken) {
                if (rewardAllowance != type(uint256).max) {
                    revert GiveMaxAllowanceOfRewardToken();
                }
            }
        }

        emit PoolCreated(newPoolId, poolsInfo[newPoolId], msg.value, _info.name, _info.poolMetadata);
    }

    ///@inheritdoc ICentherStaking
    function setAffiliateSetting(uint256 _poolId, AffiliateSettingInput memory _setting)
        external
        override
        onlyPoolOwner(_poolId)
    {
        PoolInfo memory pool = poolsInfo[_poolId];
        if (pool.setting.isActive) {
            revert CannotSetAffiliateSettingForActivePool();
        }

        affiliateSettings[_poolId].push(AffiliateSetting({level: 1, percent: _setting.levelOne}));

        affiliateSettings[_poolId].push(AffiliateSetting({level: 2, percent: _setting.levelTwo}));

        affiliateSettings[_poolId].push(AffiliateSetting({level: 3, percent: _setting.levelThree}));

        affiliateSettings[_poolId].push(AffiliateSetting({level: 4, percent: _setting.levelFour}));

        affiliateSettings[_poolId].push(AffiliateSetting({level: 5, percent: _setting.levelFive}));

        affiliateSettings[_poolId].push(AffiliateSetting({level: 6, percent: _setting.levelSix}));

        poolsInfo[_poolId].setting.isActive = true;

        emit AffiliateSettingSet(_poolId, affiliateSettings[_poolId], poolsInfo[_poolId].setting.isActive);
    }

    ///@inheritdoc ICentherStaking
    function togglePoolState(uint256 _poolId, bool _newState) external override onlyPoolOwner(_poolId) {
        if (poolsInfo[_poolId].setting.isActive == _newState) {
            revert AlreadySetted();
        }

        poolsInfo[_poolId].setting.isActive = _newState;
        emit PoolStateChanged(_poolId, _newState);
    }

    ///@inheritdoc ICentherStaking
    function stake(uint256 _poolId, uint256 _amount, address referrer) external override {
        if (poolIds < _poolId) {
            revert PoolNotExist();
        }

        PoolInfo memory _poolInfo = poolsInfo[_poolId];
        uint256 totalReward;

        if (_poolInfo.setting.showOnCenther) {
            if (!(register.isRegistered(msg.sender))) {
                revert NotRegistered();
            }
        }

        if (_poolInfo.startTime > block.timestamp) {
            revert PoolStakingNotStarted();
        }

        if (!_poolInfo.setting.isActive) {
            revert PoolNotActive();
        }

        if (msg.sender == _poolInfo.poolOwner) {
            revert PoolOwnerNotEligibleToStake();
        }

        if (_poolInfo.minStakeAmount > 0 && _poolInfo.minStakeAmount > _amount) {
            revert InvalidStakeAmount();
        }

        if (_poolInfo.maxStakeAmount > 0 && _poolInfo.maxStakeAmount < _amount) {
            revert InvalidStakeAmount();
        }

        if (_poolInfo.setting.isLP) {
            if (_poolInfo.setting.maxStakableAmount < _amount) {
                revert MaxStakableAmountReached();
            }
        }

        (,,, uint256 totalStakeAmount) = calculateTotalReward(_poolId, msg.sender);
        if (totalStakeAmount == 0) {
            userReferrer[_poolId][msg.sender] = referrer;

            refDetails[createKey(_poolId, referrer, msg.sender, block.timestamp + _poolInfo.stakingDurationPeriod)] =
                block.timestamp;
        }

        Stake memory _stake = Stake({
            stakingDuration: block.timestamp + _poolInfo.stakingDurationPeriod,
            stakedAmount: _amount,
            stakedTime: block.timestamp,
            lastRewardClaimed: block.timestamp,
            claimedReward: 0
        });

        userStakes[_poolId][msg.sender].push(_stake);

        if (_poolInfo.setting.isLP) {
            totalReward = _calcReward(_poolId, _poolInfo.stakingDurationPeriod, _amount);

            if (_poolInfo.rewardModeForRef == RefMode.TimeBasedReward) {
                address[] memory referrers = _getReferrerAddresses(_poolId, msg.sender);
                AffiliateSetting[] memory levelsInfo = affiliateSettings[_poolId];

                uint256 refReward;
                for (uint8 i; i < referrers.length; i++) {
                    if (referrers[i] != address(0) && levelsInfo[i].percent != 0) {
                        unchecked {
                            refReward +=
                                (((_amount * levelsInfo[i].percent) / 10000) * _poolInfo.stakingDurationPeriod) / _MONTH;
                        }
                    }
                }
                totalReward += refReward;
            }

            IERC20(_poolInfo.rewardToken).transferFrom(_poolInfo.poolOwner, address(this), totalReward);

            IERC20(_poolInfo.stakeToken).transferFrom(msg.sender, address(this), _amount);
        } else {
            IERC20(_poolInfo.stakeToken).transferFrom(msg.sender, _poolInfo.poolOwner, _amount);
        }

        if (_poolInfo.rewardModeForRef == RefMode.FixedReward) {
            address[] memory referrers = _getReferrerAddresses(_poolId, msg.sender);
            AffiliateSetting[] memory levelsInfo = affiliateSettings[_poolId];

            for (uint8 i; i < referrers.length; i++) {
                if (referrers[i] != address(0) && levelsInfo[i].percent != 0) {
                    uint256 _rewardAmount = (_amount * levelsInfo[i].percent) / 10000;

                    if (_poolInfo.taxationPercent > 0) {
                        unchecked {
                            IERC20(_poolInfo.rewardToken).transferFrom(
                                _poolInfo.poolOwner, address(1), (_rewardAmount * _poolInfo.taxationPercent) / 10000
                            );

                            _rewardAmount = _rewardAmount - ((_rewardAmount * _poolInfo.taxationPercent) / 10000);
                        }
                    }

                    IERC20(_poolInfo.rewardToken).transferFrom(_poolInfo.poolOwner, referrers[i], _rewardAmount);

                    emit RefRewardPaid(_poolId, msg.sender, _rewardAmount, referrers[i]);
                }
            }
        }

        emit AmountStaked(_poolId, msg.sender, _amount, referrer, totalReward);
    }

    function restake(uint256 _poolId) external override {
        PoolInfo memory _poolInfo = poolsInfo[_poolId];
        uint256 totalReward;

        if (msg.sender == _poolInfo.poolOwner) {
            revert PoolOwnerNotEligibleToStake();
        }

        if (_poolInfo.stakeToken != _poolInfo.rewardToken) {
            revert PoolNotEligibleForRestake();
        }

        if (_poolInfo.startTime > block.timestamp) {
            revert PoolStakingNotStarted();
        }

        if (!_poolInfo.setting.isActive) {
            revert PoolNotActive();
        }

        Stake[] memory _stakes = userStakes[_poolId][msg.sender];
        uint256 passdTime;
        uint256 _claimableReward;

        for (uint256 i; i < _stakes.length; i++) {
            unchecked {
                passdTime = block.timestamp > _stakes[i].stakingDuration
                    ? _stakes[i].stakingDuration - _stakes[i].lastRewardClaimed
                    : _getLastClaimWindow(_stakes[i], _poolInfo.claimDuration);
            }

            if (passdTime >= _poolInfo.claimDuration) {
                uint256 reward = _calcReward(_poolId, passdTime, _stakes[i].stakedAmount);

                if (
                    _stakes[i].lastRewardClaimed == _stakes[i].stakedTime
                        && passdTime < _poolInfo.setting.firstRewardDuration
                ) {
                    reward = 0;
                }

                if (reward != 0) {
                    _claimableReward += reward;

                    userStakes[_poolId][msg.sender][i].claimedReward += reward;
                    userStakes[_poolId][msg.sender][i].lastRewardClaimed = _stakes[i].lastRewardClaimed + passdTime;
                }
            }
        }

        if (_claimableReward <= 0) {
            revert InvalidStakeAmount();
        }

        emit RewardClaimed(_poolId, msg.sender, _claimableReward, false, 0);

        Stake memory _stake = Stake({
            stakingDuration: block.timestamp + _poolInfo.stakingDurationPeriod,
            stakedAmount: _claimableReward,
            stakedTime: block.timestamp,
            lastRewardClaimed: block.timestamp,
            claimedReward: 0
        });

        userStakes[_poolId][msg.sender].push(_stake);

        if (_poolInfo.setting.isLP) {
            totalReward = _calcReward(_poolId, _poolInfo.stakingDurationPeriod, _claimableReward);

            if (_poolInfo.rewardModeForRef == RefMode.TimeBasedReward) {
                address[] memory referrers = _getReferrerAddresses(_poolId, msg.sender);
                AffiliateSetting[] memory levelsInfo = affiliateSettings[_poolId];

                uint256 refReward;
                for (uint8 i; i < referrers.length; i++) {
                    if (referrers[i] != address(0) && levelsInfo[i].percent != 0) {
                        unchecked {
                            refReward += (
                                ((_claimableReward * levelsInfo[i].percent) / 10000) * _poolInfo.stakingDurationPeriod
                            ) / _MONTH;
                        }
                    }
                }
                totalReward += refReward;
            }

            IERC20(_poolInfo.rewardToken).transferFrom(_poolInfo.poolOwner, address(this), totalReward);
        }

        if (_poolInfo.rewardModeForRef == RefMode.FixedReward) {
            address[] memory referrers = _getReferrerAddresses(_poolId, msg.sender);
            AffiliateSetting[] memory levelsInfo = affiliateSettings[_poolId];

            for (uint8 i; i < referrers.length; i++) {
                if (referrers[i] != address(0) && levelsInfo[i].percent != 0) {
                    uint256 _rewardAmount = (_claimableReward * levelsInfo[i].percent) / 10000;

                    IERC20(_poolInfo.rewardToken).transferFrom(_poolInfo.poolOwner, referrers[i], _rewardAmount);

                    emit RefRewardPaid(_poolId, msg.sender, _rewardAmount, referrers[i]);
                }
            }
        }

        emit AmountStaked(_poolId, msg.sender, _claimableReward, address(0), totalReward);
    }

    ///@inheritdoc ICentherStaking
    function unstake(uint256 _poolId, uint256 _amount) external override nonReentrant {
        if (_amount <= 0) {
            revert InvalidUnstakeAmount();
        }

        (, uint256 amountToCancel) = _calculateClaimableReward(_poolId, msg.sender);

        if (amountToCancel < _amount) {
            revert UserNotEnoughStake();
        }

        (uint256 extraSlot, Stake[] memory unstakablesStakes) = _calcUserUnstakable(_poolId, msg.sender);

        if (extraSlot == 0 && poolsInfo[_poolId].setting.isUnstakable == false) {
            revert Locked();
        }

        amountToCancel = 0;
        uint256 sendingAmountToStaker;
        uint256 sendingAmountToOwner;

        if (extraSlot > 0) {
            uint256 _remained = _amount;
            for (uint256 i; i < unstakablesStakes.length; i++) {
                if (unstakablesStakes[i].stakedAmount >= _remained) {
                    unstakablesStakes[i].stakedAmount -= _remained;
                    userStakes[_poolId][msg.sender][i].stakedAmount -= _remained;

                    _remained = 0;
                    break;
                } else {
                    _remained -= unstakablesStakes[i].stakedAmount;
                    userStakes[_poolId][msg.sender][i].stakedAmount = 0;
                    unstakablesStakes[i].stakedAmount = 0;
                }
            }

            if (_remained > 0) {
                amountToCancel = _remained;
            }
        } else {
            amountToCancel = _amount;
        }

        extraSlot = 0;

        if (amountToCancel > 0) {
            Stake[] memory stakes = _getUserValidStakes(_poolId, msg.sender);

            uint256 remainedToCancel = amountToCancel;
            uint256 refundRefReward;

            address[] memory referrers = _getReferrerAddresses(_poolId, msg.sender);
            AffiliateSetting[] memory levelsInfo = affiliateSettings[_poolId];

            for (uint256 i; i < stakes.length; i++) {
                if (stakes[i].stakedAmount >= remainedToCancel) {
                    sendingAmountToOwner += _returnRewardAmountToOwner(_poolId, msg.sender, remainedToCancel, i);

                    stakes[i].stakedAmount -= remainedToCancel;
                    userStakes[_poolId][msg.sender][i].stakedAmount -= remainedToCancel;

                    if (poolsInfo[_poolId].rewardModeForRef == RefMode.TimeBasedReward) {
                        for (uint8 i = 0; i < referrers.length; i++) {
                            if (referrers[i] != address(0) && levelsInfo[i].percent != 0) {
                                unchecked {
                                    refundRefReward += (
                                        ((remainedToCancel * levelsInfo[i].percent) / 10000) * stakes[i].stakingDuration
                                            - stakes[i].lastRewardClaimed
                                    ) / _MONTH;
                                }
                            }
                        }
                    }

                    break;
                } else {
                    sendingAmountToOwner += _returnRewardAmountToOwner(_poolId, msg.sender, stakes[i].stakedAmount, i);

                    if (poolsInfo[_poolId].rewardModeForRef == RefMode.TimeBasedReward) {
                        for (uint8 i = 0; i < referrers.length; i++) {
                            if (referrers[i] != address(0) && levelsInfo[i].percent != 0) {
                                unchecked {
                                    refundRefReward += (
                                        ((stakes[i].stakedAmount * levelsInfo[i].percent) / 10000)
                                            * stakes[i].stakingDuration - stakes[i].lastRewardClaimed
                                    ) / _MONTH;
                                }
                            }
                        }
                    }

                    stakes[i].stakedAmount = 0;
                    userStakes[_poolId][msg.sender][i].stakedAmount = 0;
                }
            }
            unchecked {
                extraSlot = (amountToCancel * poolsInfo[_poolId].setting.cancellationFees) / 10000;
                sendingAmountToStaker = _amount - extraSlot;
            }

            sendingAmountToOwner += refundRefReward;
        } else {
            sendingAmountToStaker = _amount;
            sendingAmountToOwner = 0;
        }

        if (poolsInfo[_poolId].setting.isLP) {
            if (extraSlot > 0) {
                IERC20(poolsInfo[_poolId].stakeToken).transfer(poolsInfo[_poolId].poolOwner, extraSlot);
            }

            if (sendingAmountToOwner > 0) {
                IERC20(poolsInfo[_poolId].rewardToken).transfer(poolsInfo[_poolId].poolOwner, sendingAmountToOwner);
            }

            if (sendingAmountToStaker > 0) {
                IERC20(poolsInfo[_poolId].stakeToken).transfer(msg.sender, sendingAmountToStaker);
            }
        } else {
            IERC20(poolsInfo[_poolId].stakeToken).transferFrom(
                poolsInfo[_poolId].poolOwner, msg.sender, sendingAmountToStaker
            );
        }

        emit AmountUnstaked(_poolId, msg.sender, _amount, extraSlot, sendingAmountToOwner);
    }

    ///@inheritdoc ICentherStaking
    function claimReward(uint256 _poolId) external override {
        PoolInfo memory _poolInfo = poolsInfo[_poolId];
        Stake[] memory _stakes = userStakes[_poolId][msg.sender];
        uint256 passdTime;
        uint256 _claimableReward;

        for (uint256 i; i < _stakes.length; i++) {
            unchecked {
                passdTime = block.timestamp > _stakes[i].stakingDuration
                    ? _stakes[i].stakingDuration - _stakes[i].lastRewardClaimed
                    : _getLastClaimWindow(_stakes[i], _poolInfo.claimDuration);
            }

            if (block.timestamp - _stakes[i].lastRewardClaimed >= _poolInfo.claimDuration) {
                uint256 reward = _calcReward(_poolId, passdTime, _stakes[i].stakedAmount);

                if (
                    _stakes[i].lastRewardClaimed == _stakes[i].stakedTime
                        && block.timestamp - _stakes[i].lastRewardClaimed < _poolInfo.setting.firstRewardDuration
                ) {
                    reward = 0;
                }

                if (reward != 0) {
                    _claimableReward += reward;

                    userStakes[_poolId][msg.sender][i].claimedReward += reward;
                    userStakes[_poolId][msg.sender][i].lastRewardClaimed = _stakes[i].lastRewardClaimed + passdTime;
                }
            }
        }

        if (_claimableReward > 0) {
            uint256 burnedAmount;
            if (_poolInfo.taxationPercent > 0) {
                unchecked {
                    burnedAmount = (_claimableReward * _poolInfo.taxationPercent) / 10000;
                    _claimableReward = _claimableReward - burnedAmount;
                }
            }
            if (_poolInfo.setting.isLP) {
                IERC20(_poolInfo.rewardToken).transfer(msg.sender, _claimableReward);
                if (burnedAmount > 0) {
                    IERC20(_poolInfo.rewardToken).transfer(address(1), burnedAmount);
                }
            } else {
                IERC20(_poolInfo.rewardToken).transferFrom(_poolInfo.poolOwner, msg.sender, _claimableReward);
                if (burnedAmount > 0) {
                    IERC20(_poolInfo.rewardToken).transferFrom(_poolInfo.poolOwner, address(1), burnedAmount);
                }
            }
            emit RewardClaimed(_poolId, msg.sender, _claimableReward, false, burnedAmount);
        } else {
            revert AmountIsZero();
        }
    }

    ///@inheritdoc ICentherStaking
    function claimRewardForRef(uint256 _poolId, address _user) external override {
        uint256 passdTime;
        if (poolsInfo[_poolId].rewardModeForRef != RefMode.TimeBasedReward) {
            revert PoolRefModeIsNotTimeBased();
        }

        AffiliateSetting[] memory affilateSetting = affiliateSettings[_poolId];
        uint256 levels = type(uint256).max;

        uint256 totalReward;

        address[] memory referrers = _getReferrerAddresses(_poolId, _user);
        AffiliateSetting[] memory levelsInfo = affiliateSettings[_poolId];

        for (uint8 i = 0; i < referrers.length; i++) {
            if (referrers[i] != address(0) && levelsInfo[i].percent != 0) {
                if (msg.sender == referrers[i]) {
                    levels = i;
                    break;
                }
            }
        }

        if (levels != type(uint256).max) {
            Stake[] memory _stakes = userStakes[_poolId][_user];

            for (uint256 i; i < _stakes.length; i++) {
                if (refDetails[createKey(_poolId, msg.sender, _user, _stakes[i].stakingDuration)] == 0) {
                    refDetails[createKey(_poolId, msg.sender, _user, _stakes[i].stakingDuration)] =
                        _stakes[i].stakedTime;
                }

                unchecked {
                    if (block.timestamp > _stakes[i].stakingDuration) {
                        if (
                            refDetails[createKey(_poolId, msg.sender, _user, _stakes[i].stakingDuration)]
                                > _stakes[i].stakingDuration
                        ) {
                            passdTime = 0;
                        } else {
                            passdTime = _stakes[i].stakingDuration
                                - refDetails[createKey(_poolId, msg.sender, _user, _stakes[i].stakingDuration)];
                        }
                    } else {
                        passdTime = _getLastRefClaimWindow(
                            poolsInfo[_poolId].claimDuration,
                            refDetails[createKey(_poolId, msg.sender, _user, _stakes[i].stakingDuration)]
                        );
                    }
                }

                unchecked {
                    totalReward +=
                        (_stakes[i].stakedAmount * (passdTime) * affilateSetting[levels].percent) / (_MONTH * 10000);
                }

                refDetails[createKey(_poolId, msg.sender, _user, _stakes[i].stakingDuration)] =
                    refDetails[createKey(_poolId, msg.sender, _user, _stakes[i].stakingDuration)] + passdTime;
            }
        }

        if (totalReward != 0) {
            uint256 burnedAmount;
            if (poolsInfo[_poolId].taxationPercent > 0) {
                unchecked {
                    burnedAmount = (totalReward * poolsInfo[_poolId].taxationPercent) / 10000;
                    totalReward = totalReward - burnedAmount;
                }
            }
            if (poolsInfo[_poolId].setting.isLP) {
                IERC20(poolsInfo[_poolId].rewardToken).transfer(msg.sender, totalReward);
                if (burnedAmount > 0) IERC20(poolsInfo[_poolId].rewardToken).transfer(address(1), burnedAmount);
            } else {
                IERC20(poolsInfo[_poolId].rewardToken).transferFrom(
                    poolsInfo[_poolId].poolOwner, msg.sender, totalReward
                );
                if (burnedAmount > 0) {
                    IERC20(poolsInfo[_poolId].rewardToken).transferFrom(
                        poolsInfo[_poolId].poolOwner, address(1), burnedAmount
                    );
                }
            }
            emit RewardClaimed(_poolId, msg.sender, totalReward, true, burnedAmount);
        } else {
            revert AmountIsZero();
        }
    }

    function calculateTotalReward(uint256 poolId, address user)
        public
        view
        returns (
            uint256 totalReward,
            uint256 totalClaimableReward,
            uint256 totolUnclaimableReward,
            uint256 totalStakeAmount
        )
    {
        (totalClaimableReward, totalStakeAmount) = _calculateClaimableReward(poolId, user);
        unchecked {
            totalReward =
                (totalStakeAmount * poolsInfo[poolId].annualStakingRewardRate * poolsInfo[poolId].rate) / (10000 * 1e18);
            totolUnclaimableReward = totalReward - totalClaimableReward;
        }
    }

    function createKey(uint256 poolId, address referrer, address referral, uint256 stakingDuration)
        public
        pure
        returns (bytes32 key)
    {
        key = keccak256(abi.encodePacked(poolId, referrer, referral, stakingDuration));
    }

    function calculateClaimableRewardForRef(uint256 _poolId, address _user)
        external
        view
        returns (uint256 claimableReward, uint256 passdTime)
    {
        if (poolsInfo[_poolId].rewardModeForRef != RefMode.TimeBasedReward) {
            revert PoolRefModeIsNotTimeBased();
        }

        AffiliateSetting[] memory affilateSetting = affiliateSettings[_poolId];
        uint256 levels = type(uint256).max;

        address[] memory referrers = _getReferrerAddresses(_poolId, _user);
        AffiliateSetting[] memory levelsInfo = affiliateSettings[_poolId];
        uint256 i;
        for (i; i < referrers.length; i++) {
            if (referrers[i] != address(0) && levelsInfo[i].percent != 0) {
                if (msg.sender == referrers[i]) {
                    levels = i;
                    break;
                }
            }
        }

        //clear iterations
        i = 0;

        if (levels != type(uint256).max) {
            Stake[] memory _stakes = userStakes[_poolId][_user];

            for (i; i < _stakes.length; i++) {
                uint256 lastClaimed = _stakes[i].stakedTime;
                if (refDetails[createKey(_poolId, msg.sender, _user, _stakes[i].stakingDuration)] != 0) {
                    lastClaimed = refDetails[createKey(_poolId, msg.sender, _user, _stakes[i].stakingDuration)];
                }
                unchecked {
                    if (block.timestamp > _stakes[i].stakingDuration) {
                        if (
                            refDetails[createKey(_poolId, msg.sender, _user, _stakes[i].stakingDuration)]
                                > _stakes[i].stakingDuration
                        ) {
                            passdTime = 0;
                        } else {
                            passdTime = _stakes[i].stakingDuration - lastClaimed;
                        }
                    } else {
                        passdTime = _getLastRefClaimWindow(poolsInfo[_poolId].claimDuration, lastClaimed);
                    }
                }

                unchecked {
                    claimableReward +=
                        (_stakes[i].stakedAmount * (passdTime) * affilateSetting[levels].percent) / (_MONTH * 10000);
                }
            }
        }
    }

    function _calcReward(uint256 _poolId, uint256 _duration, uint256 _amount) internal view returns (uint256 reward) {
        unchecked {
            reward = (_amount * poolsInfo[_poolId].annualStakingRewardRate * _duration * poolsInfo[_poolId].rate)
                / (10000 * _YEAR * 1e18);
        }
    }

    function _calculateClaimableReward(uint256 _poolId, address _user)
        internal
        view
        returns (uint256 claimableReward, uint256 totalStakedAmount)
    {
        PoolInfo memory _poolInfo = poolsInfo[_poolId];
        Stake[] memory _stakes = userStakes[_poolId][_user];
        uint256 passdTime;

        for (uint256 i; i < _stakes.length; i++) {
            totalStakedAmount += _stakes[i].stakedAmount;

            unchecked {
                passdTime = block.timestamp > _stakes[i].stakingDuration
                    ? _stakes[i].stakingDuration - _stakes[i].lastRewardClaimed
                    : _getLastClaimWindow(_stakes[i], _poolInfo.claimDuration);
            }

            if (block.timestamp - _stakes[i].lastRewardClaimed >= _poolInfo.claimDuration) {
                uint256 reward = _calcReward(_poolId, passdTime, _stakes[i].stakedAmount);

                if (
                    _stakes[i].lastRewardClaimed == _stakes[i].stakedTime
                        && passdTime < _poolInfo.setting.firstRewardDuration
                ) {
                    reward = 0;
                }

                claimableReward += reward;
            }
        }
    }

    function _calcUserUnstakable(uint256 _poolId, address _user)
        internal
        view
        returns (uint256 unstakableAmount, Stake[] memory)
    {
        Stake[] memory _stakes = userStakes[_poolId][_user];
        Stake[] memory unstakablesStakes = new Stake[](_stakes.length);

        for (uint256 i; i < _stakes.length; i++) {
            if (_stakes[i].stakingDuration < block.timestamp && _stakes[i].stakedAmount > 0) {
                unstakablesStakes[i] = (_stakes[i]);
                unstakableAmount += _stakes[i].stakedAmount;
            }
        }

        return (unstakableAmount, unstakablesStakes);
    }

    function _getUserValidStakes(uint256 _poolId, address _user) internal view returns (Stake[] memory) {
        Stake[] memory _stakes = userStakes[_poolId][_user];

        Stake[] memory stakes = new Stake[](_stakes.length);

        for (uint256 i; i < _stakes.length; i++) {
            if (_stakes[i].stakingDuration > block.timestamp && _stakes[i].stakedAmount > 0) {
                stakes[i] = _stakes[i];
            }
        }

        return stakes;
    }

    function _getReferrerAddresses(uint256 _poolId, address _user)
        internal
        view
        returns (address[] memory referrerAddresses)
    {
        address userAddress = _user;
        referrerAddresses = new address[](referralDeep);

        for (uint8 i; i < referralDeep; i++) {
            address referrerAddress = userReferrer[_poolId][userAddress];
            referrerAddresses[i] = referrerAddress;
            userAddress = referrerAddress;
        }
        return referrerAddresses;
    }

    function _returnRewardAmountToOwner(uint256 _poolId, address _user, uint256 cancelStake, uint256 i)
        internal
        view
        returns (uint256 amount)
    {
        Stake memory _stakes = userStakes[_poolId][_user][i];

        uint256 reward = _calcReward(_poolId, _stakes.stakingDuration - _stakes.lastRewardClaimed, cancelStake);

        amount += reward;
    }

    function _getLastClaimWindow(Stake memory _stake, uint256 claimPeriod)
        internal
        view
        returns (uint256 lastWindowEndTime)
    {
        unchecked {
            uint256 totalPassedTime = block.timestamp - _stake.lastRewardClaimed;

            lastWindowEndTime = totalPassedTime / claimPeriod;

            lastWindowEndTime = lastWindowEndTime * claimPeriod;
        }
    }

    function _getLastRefClaimWindow(uint256 poolClaimPeriod, uint256 lastClaimTime)
        internal
        view
        returns (uint256 lastWindowEndTime)
    {
        unchecked {
            uint256 totalPassedTime = block.timestamp - lastClaimTime;

            lastWindowEndTime = totalPassedTime / poolClaimPeriod;

            lastWindowEndTime = lastWindowEndTime * poolClaimPeriod;
        }
    }
}
