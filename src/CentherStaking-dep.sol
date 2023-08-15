// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./interfaces/ICentherStaking2.sol";

import "forge-std/console2.sol";

contract CentherStakingV1 is ICentherStaking {
    address public platform;
    IRegistration public register;

    uint32 private _unlocked = 1;

    uint256 constant _HOURLY = 1 hours;
    uint256 constant _DAY = 1 days;
    uint256 constant _WEEK = 1 weeks;
    uint256 constant _MONTH = 2620800;
    uint256 constant _QUARTER = 10483200;
    uint256 constant _HALF_YEAR = _MONTH * 6;
    uint256 constant _YEAR = 31449600;

    uint256 public platformFees = 0.00001 ether; // default 1 bnb
    uint256 public poolIds;

    mapping(uint256 => PoolInfo) public idToPoolInfo;
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;

    mapping(uint256 => ReferralSetting[]) public idToSettings;
    // mapping(uint256 => mapping(address => address[])) public poolUserReferrals;
    mapping(uint256 => mapping(address => address)) public userAddressToReferrerAddress;

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

    constructor(address _registration, address _platform) {
        register = IRegistration(_registration);
        platform = _platform;
    }

    function createPool(PoolCreationInputs calldata _info, uint256[] memory _settings)
        external
        payable
        override
        onlyRegisterUser
    {
        if (_info.stakeToken == address(0)) {
            revert InvalidTokenAddress();
        }

        if (_info.annualStakingRewardRate > 10000 && _info.annualStakingRewardRate == 0) {
            revert InvalidRewardRate();
        }

        // only lp else lp false stakingDuration(forever)
        // if (
        //     // _info.stakingDuration == 0 ||
        //     _info.stakingDurationPeriod < block.timestamp
        // ) {
        //     revert InvalidStakingDuration();
        // }

        poolIds++;
        uint256 newPoolId = poolIds;

        PoolSetting memory _poolSetting = PoolSetting({
            minStakeAmount: _info.minStakeAmount,
            maxStakeAmount: _info.maxStakeAmount,
            rewardModeForRef: RefMode(_info.rewardModeForRef),
            firstReward: _info.firstReward,
            maxStakableAmount: _info.maxStakableAmount,
            cancellationFees: _info.cancellationFees,
            isUnstakable: _info.isUnstakable,
            isLP: _info.isLP,
            isActive: true
        });

        idToPoolInfo[newPoolId] = PoolInfo({
            poolOwner: msg.sender,
            stakeToken: _info.stakeToken,
            rewardToken: _info.rewardToken == address(0) ? _info.stakeToken : _info.rewardToken,
            rewardSupply: 0,
            annualStakingRewardRate: _info.annualStakingRewardRate,
            stakingDurationPeriod: _info.stakingDurationPeriod,
            totalStakedAmount: 0,
            claimDuration: _info.claimDuration,
            poolSetting: _poolSetting
        });

        if (
            RefMode(_info.rewardModeForRef) == RefMode.FixedReward
                || RefMode(_info.rewardModeForRef) == RefMode.TimeBasedReward
        ) {
            for (uint8 i = 0; i < _settings.length; i++) {
                ReferralSetting memory _referralSetting = ReferralSetting({level: i, percent: _settings[i]});
                idToSettings[poolIds].push(_referralSetting);
            }
        }

        uint256 rewardAllowance = IERC20(idToPoolInfo[newPoolId].rewardToken).allowance(msg.sender, address(this));

        if (rewardAllowance != type(uint256).max) {
            revert GiveMaxAllowanceOfRewardToken();
        }

        if (msg.value < platformFees) {
            revert ValueNotEqualToPlatformFees();
        }

        payable(platform).transfer(msg.value);

        emit StakingPoolCreated(idToPoolInfo[newPoolId], _info.poolMetadata);
    }

    function stake(uint256 _poolId, uint256 _amount, address referral) external override {
        PoolInfo memory _poolInfo = idToPoolInfo[_poolId];
        if (poolIds < _poolId) {
            revert PoolNotExist();
        }

        if (!_poolInfo.poolSetting.isActive) {
            revert PoolNotActive();
        }

        if (msg.sender == _poolInfo.poolOwner) {
            revert PoolOwnerNotEligibleToStake();
        }

        if (_poolInfo.poolSetting.minStakeAmount > 0 && _poolInfo.poolSetting.minStakeAmount > _amount) {
            revert InvalidStakeAmount();
        }

        if (_poolInfo.poolSetting.maxStakeAmount > 0 && _poolInfo.poolSetting.maxStakeAmount < _amount) {
            revert InvalidStakeAmount(); //update msg
        }

        if (_poolInfo.poolSetting.maxStakableAmount < _poolInfo.totalStakedAmount + _amount) {
            revert MaxStakableAmountReached();
        }

        address poolOwner = _poolInfo.poolOwner;

        if (userInfo[_poolId][msg.sender].stakedAmount > 0) {
            idToPoolInfo[_poolId].totalStakedAmount += _amount;

            uint256 stakingDuration = idToPoolInfo[_poolId].stakingDurationPeriod + block.timestamp;

            userInfo[_poolId][msg.sender].totalStakes += _amount;

            userInfo[_poolId][msg.sender].restakes.push(
                UserAdditionalStakes(stakingDuration, _amount, block.timestamp, block.timestamp, 0)
            );

            if (_poolInfo.poolSetting.isLP) {
                uint256 totalReward = _calculateUserTotalAccReward(_poolId, _amount);

                idToPoolInfo[_poolId].rewardSupply += totalReward;

                IERC20(_poolInfo.rewardToken).transferFrom(poolOwner, address(this), totalReward);

                IERC20(_poolInfo.stakeToken).transferFrom(msg.sender, address(this), _amount);
            } else {
                // add cond
                // if(!_poolInfo.IsBalance){
                //     revert ThisPoolIsNotBalance
                // }
                IERC20(_poolInfo.stakeToken).transferFrom(msg.sender, poolOwner, _amount);
            }
        } else {
            userInfo[_poolId][msg.sender].stakedAmount += _amount;
            userInfo[_poolId][msg.sender].totalStakes += _amount;
            userInfo[_poolId][msg.sender].stakedTime = block.timestamp;

            idToPoolInfo[_poolId].totalStakedAmount += _amount;

            userInfo[_poolId][msg.sender].stakingDuration =
                idToPoolInfo[_poolId].stakingDurationPeriod + block.timestamp;

            // poolUserReferrals[_poolId][referral].push(msg.sender);
            userAddressToReferrerAddress[_poolId][msg.sender] = referral;

            if (_poolInfo.poolSetting.isLP) {
                uint256 totalReward = _calculateUserTotalAccReward(_poolId, _amount);

                idToPoolInfo[_poolId].rewardSupply += totalReward;

                IERC20(_poolInfo.rewardToken).transferFrom(poolOwner, address(this), totalReward);

                IERC20(_poolInfo.stakeToken).transferFrom(msg.sender, address(this), _amount);
            } else {
                // add cond
                // if(!_poolInfo.IsBalance){
                //     revert ThisPoolIsNotBalance
                // }
                IERC20(_poolInfo.stakeToken).transferFrom(msg.sender, poolOwner, _amount);
            }

            if (_poolInfo.poolSetting.rewardModeForRef == RefMode.FixedReward) {
                _transferFixRewardToReferrals(_poolId, msg.sender, _amount);
            }

            emit AmountStaked(_poolId, msg.sender, _amount);
        }
    }

    function claimRewardsForRestakers(uint256 _poolId) public {
        PoolInfo memory _info = idToPoolInfo[_poolId];
        uint256 userStakesLength = userInfo[_poolId][msg.sender].restakes.length;

        (uint256[] memory amounts, uint256 totalReward) = calculateBatchReward(_poolId, msg.sender);
        for (uint256 i = 0; i < userStakesLength; i++) {
            // if reward is 0, revert zero reward

            if (amounts[i] > 0) {
                userInfo[_poolId][msg.sender].restakes[i].lastRewardClaimed = block.timestamp;
                userInfo[_poolId][msg.sender].restakes[i].claimedReward += amounts[i];
            }
        }
        if (_info.poolSetting.isLP) {
            idToPoolInfo[_poolId].rewardSupply -= totalReward;
            IERC20(_info.rewardToken).transfer(msg.sender, totalReward);
        } else {
            uint256 ownerBalance = IERC20(_info.rewardToken).balanceOf(_info.poolOwner);

            if (ownerBalance < totalReward) {
                //isBalance = false // for future
                revert InsufficientBalance();
            }

            IERC20(_info.rewardToken).transferFrom(_info.poolOwner, msg.sender, totalReward);

            emit RewardClaimed(_poolId, msg.sender, totalReward);
        }
    }

    function unstake(uint256 _poolId, uint256 _amount) external override nonReentrant {
        PoolInfo memory _info = idToPoolInfo[_poolId];

        if (userInfo[_poolId][msg.sender].totalStakes < _amount) {
            revert AmountGreaterThanStakedAmount();
        }

        //remove these claims
        claimReward(_poolId);

        if (userInfo[_poolId][msg.sender].isRestaked) {
            claimRewardsForRestakers(_poolId);
        }

        //update claimableReward in state
        // remaining work for restakers

        // first stake
        uint256 stakingLockPeriod = userInfo[_poolId][msg.sender].stakingDuration;

        if (
            stakingLockPeriod != 0 && stakingLockPeriod > block.timestamp
                && !idToPoolInfo[_poolId].poolSetting.isUnstakable
        ) {
            revert Locked();
        }

        uint256 unstakeFromFirstStake =
            _amount > userInfo[_poolId][msg.sender].stakedAmount ? userInfo[_poolId][msg.sender].stakedAmount : _amount;

        uint256 unstakeAmount;
        uint256 fees;
        uint256 feesFromExtraStakes;

        if (idToPoolInfo[_poolId].poolSetting.isUnstakable && stakingLockPeriod > block.timestamp) {
            fees += (unstakeFromFirstStake * _info.poolSetting.cancellationFees) / 10000;
        }

        if (_amount > userInfo[_poolId][msg.sender].stakedAmount) {
            if (userInfo[_poolId][msg.sender].restakes.length > 0) {
                (unstakeAmount, feesFromExtraStakes) = _additionalUnstake(
                    _poolId, msg.sender, userInfo[_poolId][msg.sender].totalStakes - unstakeFromFirstStake
                );
                fees += feesFromExtraStakes;
            }
            // else revert Itne stake nahi hain
        }

        if (_info.poolSetting.isLP) {
            if (fees > 0) {
                IERC20(idToPoolInfo[_poolId].stakeToken).transfer(_info.poolOwner, fees);
                IERC20(idToPoolInfo[_poolId].stakeToken).transfer(
                    msg.sender, unstakeFromFirstStake + unstakeAmount - fees
                );
            } else {
                IERC20(idToPoolInfo[_poolId].stakeToken).transfer(msg.sender, unstakeFromFirstStake + unstakeAmount);
            }
        } else {
            uint256 ownerStakeTknBalance = IERC20(idToPoolInfo[_poolId].stakeToken).balanceOf(_info.poolOwner);

            if (ownerStakeTknBalance < unstakeFromFirstStake + unstakeAmount) {
                // idToPoolInfo[_poolId].isBalance = false; //consider this future
                revert OwnerNotEnoughBalanceToReturnStakeAmount();
            }

            if (fees > 0) {
                IERC20(idToPoolInfo[_poolId].stakeToken).transferFrom(_info.poolOwner, msg.sender, fees);
                IERC20(idToPoolInfo[_poolId].stakeToken).transferFrom(
                    _info.poolOwner, msg.sender, unstakeFromFirstStake + unstakeAmount - fees
                );
            } else {
                IERC20(idToPoolInfo[_poolId].stakeToken).transferFrom(
                    _info.poolOwner, msg.sender, unstakeFromFirstStake + unstakeAmount
                );
            }
        }

        unchecked {
            idToPoolInfo[_poolId].totalStakedAmount -= unstakeFromFirstStake;

            userInfo[_poolId][msg.sender].stakedAmount -= unstakeFromFirstStake;

            userInfo[_poolId][msg.sender].totalStakes -= unstakeFromFirstStake;
        }

        emit AmountUnstaked(_poolId, msg.sender, unstakeFromFirstStake + unstakeAmount);
    }

    function _additionalUnstake(uint256 _poolId, address _user, uint256 _amount)
        internal
        returns (uint256 unstakeAmount, uint256 fees)
    {
        PoolInfo memory _info = idToPoolInfo[_poolId];
        UserAdditionalStakes[] memory _userInfo = userInfo[_poolId][_user].restakes;

        for (uint256 i = 0; i < _userInfo.length; i++) {
            uint256 cutAmount = _amount > _userInfo[i].stakedAmount ? _userInfo[i].stakedAmount : _amount;
            if ((_userInfo[i].stakingDuration < block.timestamp) || _info.poolSetting.isUnstakable) {
                userInfo[_poolId][_user].restakes[i].stakedAmount -= cutAmount;

                userInfo[_poolId][_user].totalStakes -= cutAmount;

                idToPoolInfo[_poolId].totalStakedAmount -= cutAmount;

                unstakeAmount += cutAmount;

                if (_info.poolSetting.isUnstakable) {
                    fees += (unstakeAmount * _info.poolSetting.cancellationFees) / 10000;
                    unstakeAmount -= fees;
                }
                _amount -= cutAmount;
            } else if (!_info.poolSetting.isUnstakable) {
                revert Locked();
            }
        }

        return (unstakeAmount, fees);
    }

    function claimReward(uint256 _poolId) public override {
        PoolInfo memory _info = idToPoolInfo[_poolId];

        if (userInfo[_poolId][msg.sender].stakedAmount < 0) {
            revert UserStakeNotFound();
        }

        uint256 reward = calculateReward(_poolId, msg.sender);

        // if reward is 0, revert zero reward

        userInfo[_poolId][msg.sender].lastRewardClaimed = block.timestamp;
        userInfo[_poolId][msg.sender].claimedReward += reward;

        if (_info.poolSetting.isLP) {
            idToPoolInfo[_poolId].rewardSupply -= reward;
            IERC20(_info.rewardToken).transfer(msg.sender, reward);
        } else {
            uint256 ownerBalance = IERC20(_info.rewardToken).balanceOf(_info.poolOwner);

            if (ownerBalance < reward) {
                //isBalance = false // for future
                revert InsufficientBalance();
            }

            IERC20(_info.rewardToken).transferFrom(_info.poolOwner, msg.sender, reward);
        }

        emit RewardClaimed(_poolId, msg.sender, reward);
    }

    function claimTimeBasedRewardForRef(uint256 _poolId) external {
        // step1 calculateReward according time
        // -> PASSED TIME >  ref CLAIM Duration (add new field)
        // -> calculate reward:
        //find all user referrals
        // each ref check passed time
        //-> PASSED TIME >  ref CLAIM Duration (add new field)
        // calculate reward for each level and its percentage
        // formula: reward = stakedAmount of user * % of level of referral * time passed / (Year Duration *10000 )
        // transfer funds to these referrals
        uint256 totalReward = calculateTimeBasedRewardForRef(_poolId, msg.sender);

        IERC20(idToPoolInfo[_poolId].rewardToken).transferFrom(idToPoolInfo[_poolId].poolOwner, msg.sender, totalReward);
        emit ReferralRewardTransfer(_poolId, idToPoolInfo[_poolId].rewardToken, msg.sender, msg.sender, totalReward);
    }

    function togglePoolState(uint256 _poolId, bool _newState) external onlyPoolOwner(_poolId) {
        if (idToPoolInfo[_poolId].poolSetting.isActive == _newState) {
            revert AlreadySetted();
        }
        idToPoolInfo[_poolId].poolSetting.isActive = _newState;
    }

    function _transferFixRewardToReferrals(uint256 _poolId, address _user, uint256 _amount) internal {
        ReferralSetting[] memory _setting = idToSettings[_poolId];

        address referrer = userAddressToReferrerAddress[_poolId][_user];
        uint256 reward;
        for (uint256 i; i < _setting.length; i++) {
            if (referrer == address(0)) break;

            uint256 percent = _setting[i].percent;

            unchecked {
                reward = ((percent * _amount) / 10000); // * only with stake amount of User
            }
            //calc and transfer
            IERC20(idToPoolInfo[_poolId].rewardToken).transferFrom(idToPoolInfo[_poolId].poolOwner, referrer, reward);

            //emit event
            emit ReferralRewardTransfer(_poolId, idToPoolInfo[_poolId].rewardToken, msg.sender, referrer, reward);

            referrer = userAddressToReferrerAddress[_poolId][referrer];
        }
    }

    function calculateTimeBasedRewardForRef(uint256 _poolId, address _user) public view returns (uint256 totalReward) {
        ReferralSetting[] memory affilateSetting = idToSettings[_poolId];

        address referrer = userAddressToReferrerAddress[_poolId][_user];

        uint256 levels = type(uint256).max;

        for (uint256 i; i < affilateSetting.length; i++) {
            if (referrer == msg.sender) {
                levels = i;
            } else {
                referrer = userAddressToReferrerAddress[_poolId][_user];
            }
        }

        if (levels == type(uint256).max) {
            revert NotValidReferral();
        } else {
            //todo=> here we need changes,
            //here we should iterate on all user stakes
            //right now seems like you check just one stake, but we need to check all this users stakes(mayber he restaked)
            //and for each calc reward and check if its collectible add it to totalReward

            uint256 percent = affilateSetting[levels].percent;
            UserInfo memory _userInfo = userInfo[_poolId][referrer];

            if (block.timestamp - userInfo[_poolId][referrer].lastRewardClaimed > 0) {
                uint256 reward = (
                    userInfo[_poolId][referrer].stakedAmount
                        * (block.timestamp - userInfo[_poolId][referrer].lastRewardClaimed) * percent
                ) / (_MONTH * 10000);
                totalReward += reward;
            }

            if (_userInfo.restakes.length > 0) {
                for (uint256 i = 0; i < _userInfo.restakes.length; i++) {
                    totalReward += calculateRewardForReStakers(_poolId, referrer, i);
                }
            }
        }
    }

    function calculateReward(uint256 poolId, address user) public view returns (uint256 reward) {
        PoolInfo memory _info = idToPoolInfo[poolId];
        UserInfo memory _userInfo = userInfo[poolId][user];

        uint256 stakingDuration = _userInfo.stakingDuration;

        uint256 timeForClaim;
        uint256 claimDurationInSec = _checkClaimPeriod(ClaimDuration(_info.claimDuration));
        if (_info.poolSetting.firstReward > claimDurationInSec && block.timestamp < _info.poolSetting.firstReward) {
            timeForClaim = _info.poolSetting.firstReward;
        } else {
            timeForClaim = claimDurationInSec;
        }

        uint256 timePassed = (block.timestamp - _userInfo.lastRewardClaimed);
        // old condition removed -> _info.stakingDuration < timePassed
        if (timeForClaim < timePassed) {
            if (stakingDuration < block.timestamp) {
                uint256 totalReward = _calculateUserTotalAccReward(poolId, _userInfo.stakedAmount);
                unchecked {
                    reward = totalReward - _userInfo.claimedReward;
                }
            } else {
                unchecked {
                    reward = (_userInfo.stakedAmount * _info.annualStakingRewardRate * timePassed) / (10000 * _YEAR);
                }
            }
        } else {
            return 0;
        }
    }

    function calculateRewardForReStakers(uint256 poolId, address user, uint256 i)
        internal
        view
        returns (uint256 reward)
    {
        PoolInfo memory _info = idToPoolInfo[poolId];

        UserAdditionalStakes memory _restake = userInfo[poolId][user].restakes[i];

        uint256 stakingDuration = _restake.stakingDuration;

        uint256 timeForClaim;
        uint256 claimDurationInSec = _checkClaimPeriod(ClaimDuration(_info.claimDuration));
        if (_info.poolSetting.firstReward > claimDurationInSec && block.timestamp < _info.poolSetting.firstReward) {
            timeForClaim = _info.poolSetting.firstReward;
        } else {
            timeForClaim = claimDurationInSec;
        }

        uint256 timePassed = (block.timestamp - _restake.lastRewardClaimed);
        // old condition removed -> _info.stakingDuration < timePassed
        if (timeForClaim < timePassed) {
            if (stakingDuration < block.timestamp) {
                uint256 totalReward = _calculateUserTotalAccReward(poolId, _restake.stakedAmount);
                unchecked {
                    reward = totalReward - _restake.claimedReward;
                }
            } else {
                unchecked {
                    reward = (_restake.stakedAmount * _info.annualStakingRewardRate * timePassed) / (10000 * _YEAR);
                }
            }
        } else {
            return 0;
        }
    }

    function calculateBatchReward(uint256 poolId, address user)
        public
        view
        returns (uint256[] memory amounts, uint256 totalReward)
    {
        uint256 length = userInfo[poolId][user].restakes.length;

        for (uint256 i = 0; i < length; i++) {
            uint256 reward = calculateRewardForReStakers(poolId, user, i);
            amounts[i] = reward;
            totalReward += reward;
        }
    }

    function _calculateUserTotalAccReward(uint256 _poolId, uint256 stakedAmount)
        internal
        view
        returns (uint256 totalReward)
    {
        unchecked {
            totalReward = (
                (
                    stakedAmount * idToPoolInfo[_poolId].annualStakingRewardRate
                        * idToPoolInfo[_poolId].stakingDurationPeriod
                ) / (10000 * _YEAR)
            );
        }
    }

    function _checkClaimPeriod(ClaimDuration _duration) internal pure returns (uint256 period) {
        if (_duration == ClaimDuration.Hourly) return period = _HOURLY;
        if (_duration == ClaimDuration.Daily) return period = _DAY;
        if (_duration == ClaimDuration.Weekly) return period = _WEEK;
        if (_duration == ClaimDuration.Monthly) return period = _MONTH;
        if (_duration == ClaimDuration.Quarterly) return period = _QUARTER;
        if (_duration == ClaimDuration.HalfYearly) return period = _HALF_YEAR;
        if (_duration == ClaimDuration.Yearly) return period = _YEAR;
    }

    //scrab
    // function _calculateRewardsForReferrals(
    //     uint256 _poolId,
    //     address _user
    // ) public view returns (uint256[] memory _amounts, uint256 totalRewards) {
    //     ReferralSetting[] memory _setting = idToSettings[_poolId];

    //     uint256 userRefLength = poolUserReferrals[_poolId][_user].length;

    //     uint256[] memory rewardAmounts = new uint256[](userRefLength);

    //     for (uint256 i = 0; i < userRefLength; i++) {
    //         if (poolUserReferrals[_poolId][_user][i] == address(0)) {
    //             break;
    //         }
    //         uint256 reward;
    //         unchecked {
    //             reward = ((_setting[i].percent *
    //                 _calculateUserTotalAccReward(_poolId, _user)) / 10000); // * only with stake amount of User
    //         }

    //         rewardAmounts[i] = reward;
    //         totalRewards += reward;
    //     }

    //     _amounts = rewardAmounts;
    // }

    // function restake(uint256 _poolId, uint256 _amount) external {
    //     // 1-check staking token and reward token are the same
    //     // 2-check if project stakable amount allows to stake more,check project is active and check project is balance(for lp false)
    //     // 3-find claimable reward
    //     // 4-if project has max stake amount, is this amount passing this condition
    //     // 5-if project has min stake amount, is amount bigger than minimum
    //     // 6-if project has min stake amount, then rewardAmount / minimum stake amount for example : 800 / 250 = 3.2 => we stake 3*250 and transfer 800 - 3*250  to staker wallet
    //     //  check if project stakable amount allows to stake more  its better to do this when we find claimabale reward,
    //     //    maybe user wants to restake 500 and pool has capacity for 200, so we can handle that 200

    //     PoolInfo memory _info = idToPoolInfo[_poolId];
    //     // UserInfo memory _userInfo = userInfo[_poolId][msg.sender];

    //     if (poolIds < _poolId) {
    //         revert PoolNotExist();
    //     }

    //     if (_info.rewardToken != _info.stakeToken) {
    //         revert ThisPoolNotValidForRestaking();
    //     }

    //     if (!_info.poolSetting.isActive) {
    //         revert PoolNotActive();
    //     }

    //     uint256 rewardAmount = calculateReward(_poolId, msg.sender);

    //     if (_amount >= rewardAmount) {
    //         revert InvalidStakeAmount();
    //     }

    //     if (
    //         _info.poolSetting.minStakeAmount > 0 &&
    //         _info.poolSetting.minStakeAmount > _amount
    //     ) {
    //         revert InvalidStakeAmount();
    //     }

    //     if (
    //         _info.poolSetting.maxStakeAmount > 0 &&
    //         _info.poolSetting.maxStakeAmount < _amount
    //     ) {
    //         revert InvalidStakeAmount(); //update msg
    //     }

    //     if (
    //         _info.poolSetting.maxStakableAmount <
    //         _info.totalStakedAmount + _amount
    //     ) {
    //         unchecked {
    //             _amount =
    //                 _info.poolSetting.maxStakableAmount -
    //                 _info.totalStakedAmount;
    //         }
    //     }

    //     idToPoolInfo[_poolId].totalStakedAmount += rewardAmount;

    //     userInfo[_poolId][msg.sender].totalStakes += rewardAmount;

    //     userInfo[_poolId][msg.sender].claimedReward += rewardAmount - _amount;

    //     UserAdditionalStakes memory _restake = UserAdditionalStakes({
    //         stakingDuration: _info.stakingDurationPeriod + block.timestamp,
    //         stakedAmount: rewardAmount,
    //         stakedTime: block.timestamp,
    //         lastRewardClaimed: block.timestamp,
    //         claimedReward: rewardAmount - _amount
    //     });

    //     userInfo[_poolId][msg.sender].restakes.push(_restake);

    //     if (_info.poolSetting.isLP) {
    //         IERC20(_info.stakeToken).transferFrom(
    //             msg.sender,
    //             address(this),
    //             _amount
    //         );

    //         IERC20(_info.rewardToken).transferFrom(
    //             address(this),
    //             msg.sender,
    //             rewardAmount - _amount
    //         );
    //     } else {
    //         IERC20(_info.rewardToken).transferFrom(
    //             _info.poolOwner,
    //             msg.sender,
    //             rewardAmount - _amount
    //         );
    //     }

    //     if (!userInfo[_poolId][msg.sender].isRestaked) {
    //         userInfo[_poolId][msg.sender].isRestaked = true;
    //     }
    // }
}
