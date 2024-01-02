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

    mapping(uint256 => uint256) public poolTax;

    mapping(uint256 => bool) public nonRefundable;

    modifier onlyCitizen() {
        if (register.isCitizen(msg.sender) < block.timestamp) {
            revert NotCitizen();
        }
        _;
    }

    modifier onlyPlatform() {
        if (msg.sender != platform) {
            revert OnlyOwner();
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

    //remove before live on mainnet
    // constructor(address _registration, address _platform) {
    //     initialized = true;
    //     register = IRegistration(_registration);
    //     _unlocked = 1;
    //     platform = _platform;
    //     platformFees = 0.00001 ether; //1 ether;
    //     referralDeep = 6;
    // }

    ///@inheritdoc ICentherStaking
    function createPool(PoolCreationInputs calldata _info)
        external
        payable
        override
              onlyCitizen
        returns (
      
            uint256 newPoolId
        )
    {
        if (_info.stakeToken == address(0)) {
            revert InvalidTokenAddress();
        }

        if (_info.annualStakingRewardRate == 0) {
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
            taxationPercent: 0
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

        emit PoolCreated(
            newPoolId,
            PoolInfoForEvent({
                minStakeAmount: poolsInfo[newPoolId].minStakeAmount,
                maxStakeAmount: poolsInfo[newPoolId].maxStakeAmount,
                rewardModeForRef: refMode,
                poolOwner: msg.sender,
                stakeToken: poolsInfo[newPoolId].stakeToken,
                rewardToken: poolsInfo[newPoolId].rewardToken,
                annualStakingRewardRate: poolsInfo[newPoolId].annualStakingRewardRate,
                stakingDurationPeriod: poolsInfo[newPoolId].stakingDurationPeriod,
                claimDuration: poolsInfo[newPoolId].claimDuration,
                rate: poolsInfo[newPoolId].rate,
                setting: _setting,
                startTime: poolsInfo[newPoolId].startTime
            }),
            msg.value,
            _info.name,
            _info.poolMetadata
        );

        if (_info.taxationPercent > 0) {
            poolTax[newPoolId] = _info.taxationPercent;
            emit PoolCreatedWithTax(newPoolId, poolTax[newPoolId]);
        }
    }

    ///@inheritdoc ICentherStaking
    function setAffiliateSetting(uint256 _poolId, AffiliateSettingInput memory _setting)
        external
        override
        onlyPoolOwner(_poolId)
    {
        // PoolInfo memory pool = poolsInfo[_poolId];
        if (poolsInfo[_poolId].setting.isActive) {
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

    function togglePoolNonRefundable(uint256 _poolId, bool _newStatus) external onlyPlatform {
        if (nonRefundable[_poolId] == _newStatus) {
            revert AlreadySelected();
        }
        nonRefundable[_poolId] = _newStatus;

        emit UpdateNonRefundableStatus(_poolId, nonRefundable[_poolId]);
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

                uint256 refReward;
                for (uint8 i; i < referrers.length; i++) {
                    if (referrers[i] != address(0) && affiliateSettings[_poolId][i].percent != 0) {
                        unchecked {
                            refReward += (
                                ((_amount * affiliateSettings[_poolId][i].percent) / 10000)
                                    * _poolInfo.stakingDurationPeriod
                            ) / _MONTH;
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

            for (uint8 i; i < referrers.length; i++) {
                if (referrers[i] != address(0) && affiliateSettings[_poolId][i].percent != 0) {
                    uint256 _rewardAmount = (_amount * affiliateSettings[_poolId][i].percent) / 10000;
                    uint256 burnedAmount;

                    if (poolTax[_poolId] > 0) {
                        unchecked {
                            burnedAmount = (_rewardAmount * poolTax[_poolId]) / 10000;
                            IERC20(_poolInfo.rewardToken).transferFrom(_poolInfo.poolOwner, address(1), burnedAmount);
                        }
                    }

                    IERC20(_poolInfo.rewardToken).transferFrom(
                        _poolInfo.poolOwner, referrers[i], _rewardAmount - burnedAmount
                    );

                    emit RewardClaimed(_poolId, referrers[i], _rewardAmount - burnedAmount, true);
                    emit TaxBurn(_poolId, referrers[i], true, burnedAmount);
                }
            }
        }

        emit AmountStaked(_poolId, msg.sender, _amount, referrer, totalReward);
    }

    function restake(uint256 _poolId) external override {
        uint256 totalReward;

        if (msg.sender == poolsInfo[_poolId].poolOwner) {
            revert PoolOwnerNotEligibleToStake();
        }

        if (poolsInfo[_poolId].stakeToken != poolsInfo[_poolId].rewardToken) {
            revert PoolNotEligibleForRestake();
        }

        if (poolsInfo[_poolId].startTime > block.timestamp) {
            revert PoolStakingNotStarted();
        }

        if (!poolsInfo[_poolId].setting.isActive) {
            revert PoolNotActive();
        }

        Stake[] memory _stakes = userStakes[_poolId][msg.sender];
        uint256 passdTime;
        uint256 _claimableReward;

        for (uint256 i; i < _stakes.length; i++) {
            unchecked {
                passdTime = block.timestamp > _stakes[i].stakingDuration
                    ? _stakes[i].stakingDuration - _stakes[i].lastRewardClaimed
                    : _getLastClaimWindow(_stakes[i], poolsInfo[_poolId].claimDuration);
            }

            if (passdTime >= poolsInfo[_poolId].claimDuration) {
                uint256 reward = _calcReward(_poolId, passdTime, _stakes[i].stakedAmount);

                if (
                    _stakes[i].lastRewardClaimed == _stakes[i].stakedTime
                        && passdTime < poolsInfo[_poolId].setting.firstRewardDuration
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

        Stake memory _stake = Stake({
            stakingDuration: block.timestamp + poolsInfo[_poolId].stakingDurationPeriod,
            stakedAmount: _claimableReward,
            stakedTime: block.timestamp,
            lastRewardClaimed: block.timestamp,
            claimedReward: 0
        });

        userStakes[_poolId][msg.sender].push(_stake);

        if (poolsInfo[_poolId].setting.isLP) {
            totalReward = _calcReward(_poolId, poolsInfo[_poolId].stakingDurationPeriod, _claimableReward);

            if (poolsInfo[_poolId].rewardModeForRef == RefMode.TimeBasedReward) {
                address[] memory referrers = _getReferrerAddresses(_poolId, msg.sender);

                uint256 refReward;
                for (uint8 i; i < referrers.length; i++) {
                    if (referrers[i] != address(0) && affiliateSettings[_poolId][i].percent != 0) {
                        unchecked {
                            refReward += (
                                ((_claimableReward * affiliateSettings[_poolId][i].percent) / 10000)
                                    * poolsInfo[_poolId].stakingDurationPeriod
                            ) / _MONTH;
                        }
                    }
                }
                totalReward += refReward;
            }

            IERC20(poolsInfo[_poolId].rewardToken).transferFrom(
                poolsInfo[_poolId].poolOwner, address(this), totalReward
            );
        }

        if (poolsInfo[_poolId].rewardModeForRef == RefMode.FixedReward) {
            address[] memory referrers = _getReferrerAddresses(_poolId, msg.sender);

            for (uint8 i; i < referrers.length; i++) {
                if (referrers[i] != address(0) && affiliateSettings[_poolId][i].percent != 0) {
                    uint256 _rewardAmount = (_claimableReward * affiliateSettings[_poolId][i].percent) / 10000;
                    uint256 burnedAmount;

                    if (poolTax[_poolId] > 0) {
                        unchecked {
                            burnedAmount = (_rewardAmount * poolTax[_poolId]) / 10000;
                            IERC20(poolsInfo[_poolId].rewardToken).transferFrom(
                                poolsInfo[_poolId].poolOwner, address(1), burnedAmount
                            );
                        }
                    }

                    IERC20(poolsInfo[_poolId].rewardToken).transferFrom(
                        poolsInfo[_poolId].poolOwner, referrers[i], _rewardAmount - burnedAmount
                    );
                }
            }
        }

        emit AmountRestaked(
            _poolId, msg.sender, _claimableReward, false, userReferrer[_poolId][msg.sender], totalReward
        );
    }

    function restakeByRef(uint256 _poolId, address _user, address _referrer) external override {
        if (msg.sender == poolsInfo[_poolId].poolOwner) {
            revert PoolOwnerNotEligibleToStake();
        }

        if (poolsInfo[_poolId].stakeToken != poolsInfo[_poolId].rewardToken) {
            revert PoolNotEligibleForRestake();
        }

        if (poolsInfo[_poolId].startTime > block.timestamp) {
            revert PoolStakingNotStarted();
        }

        if (!poolsInfo[_poolId].setting.isActive) {
            revert PoolNotActive();
        }

        if (poolsInfo[_poolId].rewardModeForRef != RefMode.TimeBasedReward) {
            revert PoolRefModeIsNotTimeBased();
        }

        uint256 levels;
        uint256 passdTime;
        uint256 claimableReward;

        address[] memory referrers = _getReferrerAddresses(_poolId, _user);

        for (uint256 i; i < referrers.length; i++) {
            if (referrers[i] != address(0) && affiliateSettings[_poolId][i].percent != 0) {
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
                    claimableReward += (
                        _stakes[i].stakedAmount * (passdTime) * affiliateSettings[_poolId][levels].percent
                    ) / (_MONTH * 10000);
                }

                refDetails[createKey(_poolId, msg.sender, _user, _stakes[i].stakingDuration)] =
                    refDetails[createKey(_poolId, msg.sender, _user, _stakes[i].stakingDuration)] + passdTime;
            }

            if (claimableReward <= 0) revert InvalidStakeAmount();

            _stakeByRef(_poolId, claimableReward, _referrer);
        }
    }

    function unstake(uint256 _poolId, uint256[] memory _stakeIds) external override nonReentrant {
        if (nonRefundable[_poolId]) {
            revert NonRefundable();
        }

        uint256 totalUnstakeAmount;
        uint256 totalclaimableReward;

        (totalclaimableReward,) = _calculateClaimableReward2(_poolId, msg.sender, _stakeIds);

        if (totalclaimableReward > 0) {
            revert ClaimedRewardExist();
        }

        for (uint256 i = 0; i < _stakeIds.length; i++) {
            uint256 unstakeAmount;
            Stake memory _stakes = userStakes[_poolId][msg.sender][_stakeIds[i]];

            // if amount is valid for unstake
            if (_stakes.stakedAmount > 0) {
                if (_stakes.stakingDuration > block.timestamp) {
                    revert Locked();
                }

                unstakeAmount = userStakes[_poolId][msg.sender][_stakeIds[i]].stakedAmount;
                totalUnstakeAmount += unstakeAmount;
                userStakes[_poolId][msg.sender][_stakeIds[i]].stakedAmount = 0;
            }

            emit AmountUnstaked(_poolId, msg.sender, unstakeAmount, _stakeIds[i], 0);
        }

        // check LP workings
        if (poolsInfo[_poolId].setting.isLP) {
            IERC20(poolsInfo[_poolId].stakeToken).transfer(msg.sender, totalUnstakeAmount);
        } else {
            IERC20(poolsInfo[_poolId].stakeToken).transferFrom(
                poolsInfo[_poolId].poolOwner, msg.sender, totalUnstakeAmount
            );
        }
    }

    ///@inheritdoc ICentherStaking
    function claimReward(uint256 _poolId, uint256[] memory _stakedIds) external override {
        uint256 passdTime;
        uint256 _claimableReward;
        uint256 burnedAmount;

        for (uint256 i; i < _stakedIds.length; i++) {
            Stake memory _stakes = userStakes[_poolId][msg.sender][_stakedIds[i]];
            unchecked {
                passdTime = block.timestamp > _stakes.stakingDuration
                    ? _stakes.stakingDuration - _stakes.lastRewardClaimed
                    : _getLastClaimWindow(_stakes, poolsInfo[_poolId].claimDuration);
            }

            if (block.timestamp - _stakes.lastRewardClaimed >= poolsInfo[_poolId].claimDuration) {
                uint256 burn;
                uint256 reward = _calcReward(_poolId, passdTime, _stakes.stakedAmount);

                if (
                    _stakes.lastRewardClaimed == _stakes.stakedTime
                        && block.timestamp - _stakes.lastRewardClaimed < poolsInfo[_poolId].setting.firstRewardDuration
                ) {
                    reward = 0;
                }

                if (reward != 0) {
                    _claimableReward += reward;

                    userStakes[_poolId][msg.sender][_stakedIds[i]].claimedReward += reward;
                    userStakes[_poolId][msg.sender][_stakedIds[i]].lastRewardClaimed =
                        _stakes.lastRewardClaimed + passdTime;
                    emit RewardClaimed(_poolId, msg.sender, reward, false);
                }

                if (poolTax[_poolId] > 0 && reward > 0) {
                    unchecked {
                        burn = (reward * poolTax[_poolId]) / 10000;
                        burnedAmount += burn;
                        emit TaxBurn(_poolId, msg.sender, false, burn);
                    }
                }
            }
        }

        if (_claimableReward > 0) {
            unchecked {
                _claimableReward = _claimableReward - burnedAmount;
            }

            if (poolsInfo[_poolId].setting.isLP) {
                IERC20(poolsInfo[_poolId].rewardToken).transfer(msg.sender, _claimableReward);
                if (burnedAmount > 0) {
                    IERC20(poolsInfo[_poolId].rewardToken).transfer(address(1), burnedAmount);
                }
            } else {
                IERC20(poolsInfo[_poolId].rewardToken).transferFrom(
                    poolsInfo[_poolId].poolOwner, msg.sender, _claimableReward
                );
                if (burnedAmount > 0) {
                    IERC20(poolsInfo[_poolId].rewardToken).transferFrom(
                        poolsInfo[_poolId].poolOwner, address(1), burnedAmount
                    );
                }
            }
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

        uint256 levels = type(uint256).max;

        uint256 totalReward;

        address[] memory referrers = _getReferrerAddresses(_poolId, _user);

        for (uint8 i = 0; i < referrers.length; i++) {
            if (referrers[i] != address(0) && affiliateSettings[_poolId][i].percent != 0) {
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
                    totalReward += (_stakes[i].stakedAmount * (passdTime) * affiliateSettings[_poolId][levels].percent)
                        / (_MONTH * 10000);
                }

                refDetails[createKey(_poolId, msg.sender, _user, _stakes[i].stakingDuration)] =
                    refDetails[createKey(_poolId, msg.sender, _user, _stakes[i].stakingDuration)] + passdTime;
            }
        }

        if (totalReward != 0) {
            uint256 burnedAmount;
            if (poolTax[_poolId] > 0) {
                unchecked {
                    burnedAmount = (totalReward * poolTax[_poolId]) / 10000;
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
            emit RewardClaimed(_poolId, msg.sender, totalReward, true);
            emit TaxBurn(_poolId, msg.sender, true, burnedAmount);
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

        uint256 levels = type(uint256).max;

        address[] memory referrers = _getReferrerAddresses(_poolId, _user);

        uint256 i;
        for (i; i < referrers.length; i++) {
            if (referrers[i] != address(0) && affiliateSettings[_poolId][i].percent != 0) {
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
                    claimableReward += (
                        _stakes[i].stakedAmount * (passdTime) * affiliateSettings[_poolId][levels].percent
                    ) / (_MONTH * 10000);
                }
            }
        }
    }

    function _stakeByRef(uint256 _poolId, uint256 _amount, address _referrer) internal {
        (,,, uint256 totalStakeAmount) = calculateTotalReward(_poolId, msg.sender);

        if (totalStakeAmount == 0) {
            userReferrer[_poolId][msg.sender] = _referrer;

            refDetails[createKey(
                _poolId, _referrer, msg.sender, block.timestamp + poolsInfo[_poolId].stakingDurationPeriod
            )] = block.timestamp;
        }

        Stake memory _stake = Stake({
            stakingDuration: block.timestamp + poolsInfo[_poolId].stakingDurationPeriod,
            stakedAmount: _amount,
            stakedTime: block.timestamp,
            lastRewardClaimed: block.timestamp,
            claimedReward: 0
        });

        userStakes[_poolId][msg.sender].push(_stake);
        uint256 totalReward;

        if (poolsInfo[_poolId].setting.isLP) {
            totalReward = _calcReward(_poolId, poolsInfo[_poolId].stakingDurationPeriod, _amount);

            if (poolsInfo[_poolId].rewardModeForRef == RefMode.TimeBasedReward) {
                address[] memory _referrers = _getReferrerAddresses(_poolId, msg.sender);

                for (uint256 i; i < _referrers.length; i++) {
                    if (_referrers[i] != address(0) && affiliateSettings[_poolId][i].percent != 0) {
                        unchecked {
                            totalReward += (
                                ((_amount * affiliateSettings[_poolId][i].percent) / 10000)
                                    * poolsInfo[_poolId].stakingDurationPeriod
                            ) / _MONTH;
                        }
                    }
                }
            }

            IERC20(poolsInfo[_poolId].rewardToken).transferFrom(
                poolsInfo[_poolId].poolOwner, address(this), totalReward
            );
        }

        emit AmountRestaked(_poolId, msg.sender, _amount, true, userReferrer[_poolId][msg.sender], totalReward);
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
        uint256 passdTime;

        for (uint256 i; i < userStakes[_poolId][_user].length; i++) {
            totalStakedAmount += userStakes[_poolId][_user][i].stakedAmount;

            unchecked {
                passdTime = block.timestamp > userStakes[_poolId][_user][i].stakingDuration
                    ? userStakes[_poolId][_user][i].stakingDuration - userStakes[_poolId][_user][i].lastRewardClaimed
                    : _getLastClaimWindow(userStakes[_poolId][_user][i], poolsInfo[_poolId].claimDuration);
            }

            if (block.timestamp - userStakes[_poolId][_user][i].lastRewardClaimed >= poolsInfo[_poolId].claimDuration) {
                uint256 reward = _calcReward(_poolId, passdTime, userStakes[_poolId][_user][i].stakedAmount);

                if (
                    userStakes[_poolId][_user][i].lastRewardClaimed == userStakes[_poolId][_user][i].stakedTime
                        && passdTime < poolsInfo[_poolId].setting.firstRewardDuration
                ) {
                    reward = 0;
                }

                claimableReward += reward;
            }
        }
    }

    function _calculateClaimableReward2(uint256 _poolId, address _user, uint256[] memory stakeIds)
        internal
        view
        returns (uint256 claimableReward, uint256 totalStakedAmount)
    {
        uint256 passdTime;

        for (uint256 i; i < stakeIds.length; i++) {
            totalStakedAmount += userStakes[_poolId][_user][stakeIds[i]].stakedAmount;

            unchecked {
                passdTime = block.timestamp > userStakes[_poolId][_user][stakeIds[i]].stakingDuration
                    ? userStakes[_poolId][_user][stakeIds[i]].stakingDuration
                        - userStakes[_poolId][_user][stakeIds[i]].lastRewardClaimed
                    : _getLastClaimWindow(userStakes[_poolId][_user][stakeIds[i]], poolsInfo[_poolId].claimDuration);
            }

            if (
                block.timestamp - userStakes[_poolId][_user][stakeIds[i]].lastRewardClaimed
                    >= poolsInfo[_poolId].claimDuration
            ) {
                uint256 reward = _calcReward(_poolId, passdTime, userStakes[_poolId][_user][stakeIds[i]].stakedAmount);

                if (
                    userStakes[_poolId][_user][stakeIds[i]].lastRewardClaimed
                        == userStakes[_poolId][_user][stakeIds[i]].stakedTime
                        && passdTime < poolsInfo[_poolId].setting.firstRewardDuration
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
