// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IRegistration {
    function isRegistered(address _user) external view returns (bool);
}

interface ICentherStaking {
    error Locked();
    error PoolNotExist();
    error NotRegistered();
    error PoolNotActive();
    error AlreadySetted();
    error NotValidReferral();
    error InvalidRewardMode();
    error InvalidRewardRate();
    error InvalidStakeAmount();
    error InvalidTokenAddress();
    error OnlyPoolOwnerCanAccess();
    error MaxStakableAmountReached();
    error PoolRefModeIsNotTimeBased();
    error PoolOwnerNotEligibleToStake();
    error ValueNotEqualToPlatformFees();
    error GiveMaxAllowanceOfRewardToken();
    error CannotSetAffiliateSettingForActivePool();

    // enum ClaimDuration {
    //     Hourly,
    //     Daily,
    //     Weekly,
    //     Monthly,
    //     Quarterly,
    //     HalfYearly,
    //     Yearly
    // }

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
        uint256 claimDuration;
        uint8 rewardModeForRef;
        uint256 firstReward;
        uint256 maxStakableAmount;
        uint256 cancellationFees;
        string poolMetadata;
        bool isUnstakable;
        bool isLP;
    }

    struct PoolInfo {
        address poolOwner;
        address stakeToken;
        address rewardToken;
        uint256 annualStakingRewardRate;
        uint256 stakingDurationPeriod;
        uint256 claimDuration;
        uint256 minStakeAmount;
        uint256 maxStakeAmount;
        RefMode rewardModeForRef;
        PoolSetting setting;
    }

    struct PoolSetting {
        uint256 firstRewardDuration;
        uint256 maxStakableAmount;
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
        uint256 levelOne;
        uint256 levelTwo;
        uint256 levelThree;
        uint256 levelFour;
        uint256 levelFive;
        uint256 levelSix;
    }

    struct Stake {
        uint256 stakingDuration;
        uint256 stakedAmount;
        uint256 stakedTime;
        uint256 lastRewardClaimed;
        uint256 claimedReward;
    }

    event StakingPoolCreated(PoolInfo poolInfo, string metadataUri);
    event AmountStaked(uint256 poolId, address user, uint256 amount);
    event AmountUnstaked(uint256 poolId, address user, uint256 amount);
    event RewardClaimed(uint256 poolId, address user, uint256 amount);
    event AffiliateSettingSet(uint256, AffiliateSetting[]);
    event PoolStateChanged(uint256, bool);
    event RefRewardPaid(
        uint256 poolId,
        address staker,
        uint256 reward,
        address referrer
    );

    function createPool(PoolCreationInputs calldata _info) external payable;

    function stake(uint256 _poolId, uint256 _amount, address referrer) external;

    function unstake(uint256 _poolId, uint256 _amount) external;

    function claimReward(uint256 _poolId) external;

    function claimRewardForRef(uint256 _poolId, address _user) external;
}
