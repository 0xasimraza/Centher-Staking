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

    address public executor;

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

    constructor(address _registration, address _platform) {
        register = IRegistration(_registration);
        _unlocked = 1;
        platform = _platform;
        platformFees = 0.00001 ether;
        referralDeep = 6;
    }

    // function initialize(address _registration, address _platform) public {
    //     require(!initialized);
    //     initialized = true;
    //     register = IRegistration(_registration);
    //     _unlocked = 1;
    //     platform = _platform;
    //     platformFees = 1 ether;
    //     referralDeep = 6;
    // }

    ///@inheritdoc ICentherStaking
    function createPool(PoolCreationInputs calldata _info)
        external
        payable
        override
        returns (
            // onlyCitizen
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

    function updateExecutor(address _newExecutor) external onlyPlatform {
        if (_newExecutor == address(0)) {
            revert ZeroAddressNotAllowed();
        }
        emit ExecutorUpdated(executor, executor = _newExecutor);
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

            if (poolsInfo[_poolId].rewardModeForRef == RefMode.TimeBasedReward) {
                totalReward += _calculateTimeBaseReward(_poolId, _amount);
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

    function restakeByIds(uint256 _poolId, uint256[] memory _stakeIds) external {
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

        uint256 totalReward;
        uint256 passdTime;
        uint256 claimableReward;

        for (uint256 i; i < _stakeIds.length; i++) {
            Stake memory _stakes = userStakes[_poolId][msg.sender][_stakeIds[i]];

            unchecked {
                passdTime = block.timestamp > _stakes.stakingDuration
                    ? _stakes.stakingDuration - _stakes.lastRewardClaimed
                    : _getLastClaimWindow(poolsInfo[_poolId].claimDuration, _stakes.lastRewardClaimed);
            }

            if (passdTime >= poolsInfo[_poolId].claimDuration) {
                uint256 reward = _calcReward(_poolId, passdTime, _stakes.stakedAmount);

                if (
                    _stakes.lastRewardClaimed == _stakes.stakedTime
                        && passdTime < poolsInfo[_poolId].setting.firstRewardDuration
                ) {
                    reward = 0;
                }

                if (reward != 0) {
                    claimableReward += reward;

                    userStakes[_poolId][msg.sender][i].claimedReward += reward;
                    if (block.timestamp > _stakes.stakingDuration) {
                        userStakes[_poolId][msg.sender][_stakeIds[i]].lastRewardClaimed = _stakes.stakingDuration;
                    } else {
                        userStakes[_poolId][msg.sender][_stakeIds[i]].lastRewardClaimed =
                            _stakes.lastRewardClaimed + passdTime;
                    }
                }
            }
        }

        if (claimableReward <= 0) {
            revert InvalidStakeAmount();
        }

        Stake memory _stake = Stake({
            stakingDuration: block.timestamp + poolsInfo[_poolId].stakingDurationPeriod,
            stakedAmount: claimableReward,
            stakedTime: block.timestamp,
            lastRewardClaimed: block.timestamp,
            claimedReward: 0
        });

        userStakes[_poolId][msg.sender].push(_stake);

        if (poolsInfo[_poolId].setting.isLP) {
            totalReward = _calcReward(_poolId, poolsInfo[_poolId].stakingDurationPeriod, claimableReward);

            if (poolsInfo[_poolId].rewardModeForRef == RefMode.TimeBasedReward) {
                totalReward += _calculateTimeBaseReward(_poolId, claimableReward);
            }

            IERC20(poolsInfo[_poolId].rewardToken).transferFrom(
                poolsInfo[_poolId].poolOwner, address(this), totalReward
            );
        }

        if (poolsInfo[_poolId].rewardModeForRef == RefMode.FixedReward) {
            address[] memory referrers = _getReferrerAddresses(_poolId, msg.sender);

            for (uint8 i; i < referrers.length; i++) {
                if (referrers[i] != address(0) && affiliateSettings[_poolId][i].percent != 0) {
                    uint256 _rewardAmount = (claimableReward * affiliateSettings[_poolId][i].percent) / 10000;
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

        emit AmountRestaked(_poolId, msg.sender, claimableReward, false, userReferrer[_poolId][msg.sender], totalReward);
    }

    function autoUserRestakeByIds(uint256 _poolId, address _user, uint256[] memory _stakeIds) external {
        if (msg.sender != executor) {
            revert OnlyExecutor();
        }

        (,,, uint256 totalStakeAmount) = calculateTotalReward(_poolId, _user);

        if (totalStakeAmount == 0) {
            revert UserStakesNotFound();
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

        uint256 passdTime;
        uint256 claimableReward;

        for (uint256 i; i < _stakeIds.length; i++) {
            Stake memory _stakes = userStakes[_poolId][_user][_stakeIds[i]];

            unchecked {
                passdTime = block.timestamp > _stakes.stakingDuration
                    ? _stakes.stakingDuration - _stakes.lastRewardClaimed
                    : _getLastClaimWindow(poolsInfo[_poolId].claimDuration, _stakes.lastRewardClaimed);
            }

            if (passdTime >= poolsInfo[_poolId].claimDuration) {
                uint256 reward = _calcReward(_poolId, passdTime, _stakes.stakedAmount);

                if (
                    _stakes.lastRewardClaimed == _stakes.stakedTime
                        && passdTime < poolsInfo[_poolId].setting.firstRewardDuration
                ) {
                    reward = 0;
                }

                if (reward != 0) {
                    claimableReward += reward;

                    userStakes[_poolId][_user][i].claimedReward += reward;
                    if (block.timestamp > _stakes.stakingDuration) {
                        userStakes[_poolId][_user][_stakeIds[i]].lastRewardClaimed = _stakes.stakingDuration;

                        Stake memory _stake = Stake({
                            stakingDuration: block.timestamp + poolsInfo[_poolId].stakingDurationPeriod,
                            stakedAmount: reward,
                            stakedTime: block.timestamp,
                            lastRewardClaimed: block.timestamp,
                            claimedReward: 0
                        });

                        userStakes[_poolId][_user].push(_stake);
                        emit AutoRestaked(_poolId, _user, userStakes[_poolId][_user].length - 1, reward, true);
                    } else {
                        userStakes[_poolId][_user][_stakeIds[i]].lastRewardClaimed =
                            _stakes.lastRewardClaimed + passdTime;

                        userStakes[_poolId][_user][_stakeIds[i]].stakedAmount += reward;
                        emit AutoRestaked(_poolId, _user, _stakeIds[i], reward, false);
                    }
                }
            }
        }

        if (claimableReward <= 0) {
            revert InvalidStakeAmount();
        }

        if (poolsInfo[_poolId].setting.isLP) {
            uint256 totalReward = _calcReward(_poolId, poolsInfo[_poolId].stakingDurationPeriod, claimableReward);

            IERC20(poolsInfo[_poolId].rewardToken).transferFrom(
                poolsInfo[_poolId].poolOwner, address(this), totalReward
            );
        }
    }

    function batchTxByRef(uint256 _poolId, address[] memory _user, address _referrer, bool isRestakeTx) external {
        for (uint256 i; i < _user.length; i++) {
            isRestakeTx ? restakeByRef(_poolId, _user[i], _referrer) : claimRewardForRef(_poolId, _user[i]);
        }
    }

    function unstake(uint256 _poolId, uint256[] memory _stakeIds) external override nonReentrant {
        if (nonRefundable[_poolId]) {
            revert NonRefundable();
        }

        uint256 totalUnstakeAmount;
        uint256 totalclaimableReward;

        (totalclaimableReward,) = _calculateClaimableReward(_poolId, msg.sender, _stakeIds);

        if (totalclaimableReward > 0) {
            revert ClaimedRewardExist();
        }

        for (uint256 i; i < _stakeIds.length; i++) {
            uint256 unstakeAmount;
            Stake memory _stakes = userStakes[_poolId][msg.sender][_stakeIds[i]];

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
                    : _getLastClaimWindow(poolsInfo[_poolId].claimDuration, _stakes.lastRewardClaimed);
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
                    if (block.timestamp > _stakes.stakingDuration) {
                        userStakes[_poolId][msg.sender][_stakedIds[i]].lastRewardClaimed = _stakes.stakingDuration;
                    } else {
                        userStakes[_poolId][msg.sender][_stakedIds[i]].lastRewardClaimed =
                            _stakes.lastRewardClaimed + passdTime;
                    }

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

    function restakeByRef(uint256 _poolId, address _user, address _referrer) public {
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

        uint256 passdTime;
        uint256 claimableReward;

        uint256 levels = _checkLevel(_poolId, _user, msg.sender);

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
                        passdTime = _getLastClaimWindow(
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

            _stakeByRef(_poolId, claimableReward, _user, _referrer, levels);
        }
    }

    function claimRewardForRef(uint256 _poolId, address _user) public {
        uint256 passdTime;
        if (poolsInfo[_poolId].rewardModeForRef != RefMode.TimeBasedReward) {
            revert PoolRefModeIsNotTimeBased();
        }

        uint256 totalReward;

        uint256 levels = _checkLevel(_poolId, _user, msg.sender);

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
                        passdTime = _getLastClaimWindow(
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
            emit LinkRefReward(_poolId, msg.sender, _user, levels);
        } else {
            revert AmountIsZero();
        }
    }

    function createKey(uint256 poolId, address referrer, address referral, uint256 stakingDuration)
        public
        pure
        returns (bytes32 key)
    {
        key = keccak256(abi.encodePacked(poolId, referrer, referral, stakingDuration));
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
        uint256[] memory _stakedIds = new uint256[](userStakes[poolId][user].length);
        for (uint256 i = 0; i < _stakedIds.length; i++) {
            _stakedIds[i] = i;
        }
        (totalClaimableReward, totalStakeAmount) = _calculateClaimableReward(poolId, user, _stakedIds);

        unchecked {
            totalReward =
                (totalStakeAmount * poolsInfo[poolId].annualStakingRewardRate * poolsInfo[poolId].rate) / (10000 * 1e18);
            totolUnclaimableReward = totalReward - totalClaimableReward;
        }
    }

    function calculateTotalRewardPerStake(uint256 poolId, address user, uint256 stakeId)
        external
        view
        returns (uint256 totalClaimableReward, uint256 nextClaimTime)
    {
        Stake memory _stake = userStakes[poolId][user][stakeId];

        uint256 passdTime;
        unchecked {
            passdTime = block.timestamp > _stake.stakingDuration
                ? _stake.stakingDuration - _stake.lastRewardClaimed
                : _getLastClaimWindow(poolsInfo[poolId].claimDuration, _stake.lastRewardClaimed);
        }

        if (block.timestamp - _stake.lastRewardClaimed >= poolsInfo[poolId].claimDuration) {
            totalClaimableReward = _calcReward(poolId, passdTime, _stake.stakedAmount);

            if (
                _stake.lastRewardClaimed == _stake.stakedTime
                    && passdTime < poolsInfo[poolId].setting.firstRewardDuration
            ) {
                totalClaimableReward = 0;
            }
        }

        if (
            _stake.lastRewardClaimed == _stake.stakedTime
                && block.timestamp - _stake.lastRewardClaimed < poolsInfo[poolId].setting.firstRewardDuration
        ) {
            nextClaimTime = _stake.lastRewardClaimed + poolsInfo[poolId].setting.firstRewardDuration;
        } else {
            nextClaimTime = _stake.lastRewardClaimed + poolsInfo[poolId].claimDuration;
        }
    }

    function calculateClaimableRewardForRef(uint256 _poolId, address _user, address _referrer)
        external
        view
        returns (uint256 claimableReward, uint256 passdTime, uint256 nextTimeToClaim)
    {
        if (poolsInfo[_poolId].rewardModeForRef != RefMode.TimeBasedReward) {
            revert PoolRefModeIsNotTimeBased();
        }

        uint256 levels = _checkLevel(_poolId, _user, _referrer);

        uint256 lastClaimedByRef;
        if (levels != type(uint256).max) {
            Stake[] memory _stakes = userStakes[_poolId][_user];

            for (uint256 i; i < _stakes.length; i++) {
                lastClaimedByRef = _stakes[i].stakedTime;
                if (refDetails[createKey(_poolId, _referrer, _user, _stakes[i].stakingDuration)] != 0) {
                    lastClaimedByRef = refDetails[createKey(_poolId, _referrer, _user, _stakes[i].stakingDuration)];
                }
                unchecked {
                    if (block.timestamp > _stakes[i].stakingDuration) {
                        if (
                            refDetails[createKey(_poolId, _referrer, _user, _stakes[i].stakingDuration)]
                                > _stakes[i].stakingDuration
                        ) {
                            passdTime = 0;
                        } else {
                            passdTime = _stakes[i].stakingDuration - lastClaimedByRef;
                        }
                    } else {
                        passdTime = _getLastClaimWindow(poolsInfo[_poolId].claimDuration, lastClaimedByRef);
                    }
                }

                unchecked {
                    claimableReward += (
                        _stakes[i].stakedAmount * (passdTime) * affiliateSettings[_poolId][levels].percent
                    ) / (_MONTH * 10000);
                }

                if (
                    lastClaimedByRef == _stakes[i].stakedTime
                        && block.timestamp - lastClaimedByRef < poolsInfo[_poolId].setting.firstRewardDuration
                ) {
                    nextTimeToClaim = lastClaimedByRef + poolsInfo[_poolId].setting.firstRewardDuration;
                } else {
                    nextTimeToClaim = lastClaimedByRef + poolsInfo[_poolId].claimDuration;
                }
            }
        }
    }

    function _stakeByRef(uint256 _poolId, uint256 _amount, address _user, address _referrer, uint256 _levels)
        internal
    {
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
                totalReward += _calculateTimeBaseReward(_poolId, _amount);
            }
            IERC20(poolsInfo[_poolId].rewardToken).transferFrom(
                poolsInfo[_poolId].poolOwner, address(this), totalReward
            );
        }

        emit AmountRestaked(_poolId, msg.sender, _amount, true, _referrer, totalReward);
        emit LinkRefReward(_poolId, msg.sender, _user, _levels);
    }

    function _calcReward(uint256 _poolId, uint256 _duration, uint256 _amount) internal view returns (uint256 reward) {
        unchecked {
            reward = (_amount * poolsInfo[_poolId].annualStakingRewardRate * _duration * poolsInfo[_poolId].rate)
                / (10000 * _YEAR * 1e18);
        }
    }

    function _calculateClaimableReward(uint256 _poolId, address _user, uint256[] memory stakeIds)
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
                    : _getLastClaimWindow(
                        poolsInfo[_poolId].claimDuration, userStakes[_poolId][_user][stakeIds[i]].lastRewardClaimed
                    );
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

    function _getLastClaimWindow(uint256 poolClaimPeriod, uint256 lastClaimTime)
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

    function _checkLevel(uint256 _poolId, address _user, address _caller) internal view returns (uint256 level) {
        level = type(uint256).max;
        address[] memory referrers = _getReferrerAddresses(_poolId, _user);

        for (uint256 i; i < referrers.length; i++) {
            if (referrers[i] != address(0) && affiliateSettings[_poolId][i].percent != 0) {
                if (_caller == referrers[i]) {
                    level = i;
                    break;
                }
            }
        }
    }

    function _calculateTimeBaseReward(uint256 _poolId, uint256 _amount) internal view returns (uint256 totalReward) {
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
}
