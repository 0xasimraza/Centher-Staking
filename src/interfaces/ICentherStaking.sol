// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IRegistration {
    function isRegistered(address _user) external view returns (bool);
}

/// @title The interface for the Centher Staking
interface ICentherStaking {
    struct PoolCreationInputs {
        string name;
        uint256 startTime;
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
        uint256 rate;
        string poolMetadata;
        bool isUnstakable;
        bool isLP;
        bool showOnCenther;
    }

    struct PoolInfo {
        address poolOwner;
        address stakeToken;
        address rewardToken;
        uint256 rate;
        uint256 annualStakingRewardRate;
        uint256 startTime;
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
        bool showOnCenther;
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

    enum RefMode {
        NoReward,
        FixedReward,
        TimeBasedReward
    }

    /// @notice PoolCreated event which contains pool Id, pool details, platform fees, project name and it metadata
    /// @param poolId a parameter, new created pool Id
    /// @param poolInfo a parameter, pool details
    /// @param platformFees a parameter, platform fees (in native token) paid by pool owner
    /// @param name a parameter, contain staking project name
    /// @param metadataUri a parameter, contain staking project metadata
    event PoolCreated(uint256 poolId, PoolInfo poolInfo, uint256 platformFees, string name, string metadataUri);

    /// @notice AmountStaked event which contains user stake details
    /// @param poolId a parameter, stake amount on this pool Id
    /// @param user a parameter, depositor address
    /// @param amount a parameter, stake amount
    /// @param referrer a parameter, referrer address
    event AmountStaked(uint256 poolId, address user, uint256 amount, address referrer, uint256 topupRewardAmount);

    /// @notice AmountUnstaked event which contains user unstake details
    /// @param poolId a parameter, unstake amount on this pool Id
    /// @param user a parameter, withdrawer address
    /// @param amount a parameter, unstake amount
    event AmountUnstaked(uint256 poolId, address user, uint256 amount, uint256 cancellationFees, uint256 refundToOwner);

    /// @notice RewardClaimed event which contains user claimed reward details
    /// @param poolId a parameter, claimed amount on this pool Id
    /// @param user a parameter, claimer address
    /// @param amount a parameter, claimed reward amount
    event RewardClaimed(uint256 poolId, address user, uint256 amount);

    /// @notice AffiliateSettingSet event which contains affiliateSetting details on specific pool Id
    /// @param affiliateSetting a parameter, affiliate setting details about level and its percentages
    /// @param isActive a parameter, pool status is active or not
    event AffiliateSettingSet(uint256, AffiliateSetting[] affiliateSetting, bool isActive);

    /// @notice PoolStateChanged event which contains state of pool is active or not
    /// @param poolId a parameter, id of specific pool
    /// @param poolState a parameter, pool status is active or not
    event PoolStateChanged(uint256 poolId, bool poolState);

    /// @notice RefRewardPaid event which contains referrer claimed reward details
    /// @param poolId a parameter, referrer claimed amount on this pool Id
    /// @param staker a parameter, claimer address
    /// @param reward a parameter, claimed reward amount
    /// @param referrer a parameter, referrer address
    event RefRewardPaid(uint256 poolId, address staker, uint256 reward, address referrer);

    error Locked();
    error PoolNotExist();
    error NotRegistered();
    error PoolNotActive();
    error AlreadySetted();
    error InvalidStartTime();
    error NotValidReferral();
    error InvalidRewardMode();
    error InvalidRewardRate();
    error InvalidStakeAmount();
    error InvalidTokenAddress();
    error PoolStakingNotStarted();
    error OnlyPoolOwnerCanAccess();
    error MaxStakableAmountReached();
    error PoolRefModeIsNotTimeBased();
    error PoolOwnerNotEligibleToStake();
    error ValueNotEqualToPlatformFees();
    error GiveMaxAllowanceOfRewardToken();
    error CannotSetAffiliateSettingForActivePool();

    /// @notice Creates a pool for staking
    /// @dev In _info params all the duration should pass in epoch seconds except startTime. Percentages calculations according to 10000 ~= 100%.
    /// @param _info a parameter which contains pool details like stake,reward token and its project relevant details
    /// @return uint256 the return new created pool Id
    function createPool(PoolCreationInputs calldata _info) external payable returns (uint256);

    /// @notice Creates a pool for staking
    /// @dev In _setting params Percentages calculations according to 10000 ~= 100%.
    /// @param _poolId a parameter, pass pool Id to update its affiliate setting
    /// @param _poolId a parameter, pass affiliate setting details
    function setAffiliateSetting(uint256 _poolId, AffiliateSettingInput memory _setting) external;

    /// @notice Stake amount in specific pool
    /// @dev In referrer params, pass either address of referrer (exist staker of centher staking) or address zero
    /// @param _poolId a parameter, pass pool Id to stake amount on the desired pool
    /// @param _amount a parameter , pass stake amount to deposit in the desired pool
    /// @param referrer a parameter, pass referrer address
    function stake(uint256 _poolId, uint256 _amount, address referrer) external;

    /// @notice Untake amount from specific pool
    /// @param _poolId a parameter, pass pool Id to unstake amount on the specific pool
    /// @param _amount a parameter , pass unstake amount from specific pool
    function unstake(uint256 _poolId, uint256 _amount) external;

    /// @notice Claim reward from specific pool
    /// @param _poolId a parameter, pass pool Id to claim reward amount from the specific pool
    function claimReward(uint256 _poolId) external;

    /// @notice Claim referral reward from specific pool
    /// @param _poolId a parameter, pass pool Id to claim referral reward amount from the specific pool
    /// @param _user a parameter, pass user address
    function claimRewardForRef(uint256 _poolId, address _user) external;

    /// @notice setter function for pool state
    /// @param _poolId a parameter, pass pool Id to update pool state
    /// @param _newState a parameter, pass new pool state
    function togglePoolState(uint256 _poolId, bool _newState) external;
}
