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
    error InvalidPoolOwner();
    error NotValidReferral();
    error UserStakeNotFound();
    error InvalidRewardRate();
    error InvalidStakeAmount();
    error InsufficientBalance();
    error InvalidTokenAddress();
    error OnlyPoolOwnerCanAccess();
    error InvalidStakingDuration();
    error MaxStakableAmountReached();
    error PoolOwnerNotEligibleToStake();
    error ValueNotEqualToPlatformFees();
    error GiveMaxAllowanceOfRewardToken();
    error ThisPoolNotValidForRestaking();
    error AmountGreaterThanStakedAmount();
    error OwnerNotEnoughBalanceToReturnStakeAmount();

    event StakingPoolCreated(PoolInfo poolInfo, string metadataUri);
    event AmountStaked(uint256 poolId, address user, uint256 amount);
    event AmountUnstaked(uint256 poolId, address user, uint256 amount);
    event RewardClaimed(uint256 poolId, address user, uint256 amount);
    event ReferralRewardTransfer(
        uint256 poolId,
        address rewardToken,
        address user,
        address refferer,
        uint256 amount
    );

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
        uint256 maxStakeAmount; // bool isBalance :true (LP false)
        uint256 stakingDurationPeriod;
        uint8 claimDuration;
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
        uint256 rewardSupply;
        uint256 annualStakingRewardRate;
        uint256 stakingDurationPeriod;
        uint8 claimDuration;
        uint256 totalStakedAmount;
        PoolSetting poolSetting;
    }

    struct PoolSetting {
        uint256 minStakeAmount;
        uint256 maxStakeAmount;
        uint256 firstReward;
        uint256 maxStakableAmount;
        RefMode rewardModeForRef;
        uint256 cancellationFees;
        bool isUnstakable;
        bool isLP;
        bool isActive;
    }

    // struct AffilateSetting {
    //     uint8 mode; // conversion into enum
    //     ReferralSetting[] levelInfo;
    // }

    struct ReferralSetting {
        uint8 level;
        uint256 percent;
    }

    struct UserInfo {
        uint256 stakedTime;
        uint256 stakedAmount;
        uint256 lastRewardClaimed;
        uint256 claimedReward;
        uint256 stakingDuration;
        uint256 totalStakes;
        bool isRestaked;
        UserAdditionalStakes[] restakes;
    }

    struct UserAdditionalStakes {
        uint256 stakingDuration;
        uint256 stakedAmount;
        uint256 stakedTime;
        uint256 lastRewardClaimed;
        uint256 claimedReward;
    }

    function createPool(
        PoolCreationInputs calldata info,
        uint256[] memory _settings
    ) external payable;

    function stake(uint256 poolId, uint256 amount, address referral) external;

    function unstake(uint256 pooldId, uint256 amount) external;

    function claimReward(uint256 pooldId) external;

    function claimTimeBasedRewardForRef(uint256 pooldId) external; //check mode and calculate according to that (execute by ref)
}
