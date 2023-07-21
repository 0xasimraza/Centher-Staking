// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/console2.sol";
import "forge-std/Test.sol";

import "../src/CentherStaking.sol";
import "../src/interfaces/ICentherStaking.sol";

import "../src/utils/Token.sol";
import "../src/utils/CentherRegistration.sol";

contract CentherStakingTest is Test {
    address payable public owner;
    address payable public user1;
    address payable public user2;
    address payable public other;

    Token public deXa;
    Token public busd;
    Token public wbnb;
    Token public ntr;

    CentherRegistration public register;

    CentherStaking public staking;

    function setUp() external {
        owner = payable(vm.addr(1));
        user1 = payable(vm.addr(2));
        user2 = payable(vm.addr(3));
        other = payable(vm.addr(4));

        console2.log(" ---- owner ----", owner);
        console2.log(" ---- user1 ----", user1);
        console2.log(" ---- user2 ----", user2);
        console2.log(" ---- other ----", other);

        vm.startPrank(owner);
        deXa = new Token("deXa", "DXC");
        busd = new Token("Binance USD", "BUSD");
        wbnb = new Token("Wrapped BNB", "WBNB");
        ntr = new Token("NTR Token", "NTR");

        busd.transfer(user1, 500000e18);

        wbnb.transfer(user1, 500000e18);

        ntr.transfer(user1, 500000e18);

        register = new CentherRegistration();
        register.setOperator(address(owner));

        address[] memory _users = new address[](3);
        _users[0] = address(user1);
        _users[1] = address(user2);
        _users[2] = address(other);

        address[] memory _refs = new address[](3);
        _refs[0] = address(owner);
        _refs[1] = address(user1);
        _refs[2] = address(user2);

        register.registerForOwnerBatch(_users, _refs);

        staking = new CentherStaking(address(register), owner);
    }

    function testDeployments() external view {
        console2.log("centher registration: ", address(register));
        console2.log("centher staking: ", address(staking));
    }

    function testCreatePool() external {
        vm.startPrank(user1);

        deal(user1, 100 ether);

        IERC20(address(busd)).approve(address(staking), type(uint256).max);

        ICentherStaking.PoolCreationInputs memory _info = ICentherStaking
            .PoolCreationInputs(
                address(deXa),
                address(busd),
                200,
                5e18,
                10000e18,
                365 days,
                2,
                1,
                1 weeks,
                10000e18,
                100,
                "www.staking.com/1",
                true,
                true
            );

        staking.createPool{value: 0.00001 ether}(_info);

        ICentherStaking.AffiliateSettingInput memory _setting = ICentherStaking
            .AffiliateSettingInput({
                levelOne: 600,
                levelTwo: 400,
                levelThree: 200,
                levelFour: 200,
                levelFive: 200,
                levelSix: 200
            });

        staking.setAffiliateSetting(1, _setting);

        assert(staking.poolIds() == 1);
    }

    function testShouldFailOwnerNotRegistered() external {
        vm.startPrank(owner);

        deal(owner, 100 ether);

        IERC20(address(busd)).approve(address(staking), type(uint256).max);

        ICentherStaking.PoolCreationInputs memory _info = ICentherStaking
            .PoolCreationInputs(
                address(deXa),
                address(busd),
                200,
                5e18,
                10000e18,
                365 days,
                2,
                1,
                1 weeks,
                10000e18,
                100,
                "www.staking.com/1",
                true,
                true
            );

        bytes4 selector = bytes4(keccak256("NotRegistered()"));
        vm.expectRevert(abi.encodeWithSelector(selector));

        staking.createPool{value: 0.00001 ether}(_info);
    }

    function testFailCreatePoolWithInvalidStakeTokenAddress() external {
        vm.startPrank(user1);

        deal(user1, 100 ether);

        IERC20(address(busd)).approve(address(staking), type(uint256).max);

        ICentherStaking.PoolCreationInputs memory _info = ICentherStaking
            .PoolCreationInputs(
                address(0),
                address(busd),
                200,
                5e18,
                10000e18,
                365 days,
                2,
                1,
                1 weeks,
                10000e18,
                100,
                "www.staking.com/1",
                true,
                true
            );

        vm.expectRevert("InvalidTokenAddress");
        staking.createPool{value: 0.00001 ether}(_info);
    }

    function testFailCreatePoolWithInvalidAnnualRate1() external {
        vm.startPrank(user1);

        deal(user1, 100 ether);

        IERC20(address(busd)).approve(address(staking), type(uint256).max);

        ICentherStaking.PoolCreationInputs memory _info = ICentherStaking
            .PoolCreationInputs(
                address(deXa),
                address(busd),
                0,
                5e18,
                10000e18,
                365 days,
                2,
                1,
                1 weeks,
                10000e18,
                100,
                "www.staking.com/1",
                true,
                true
            );

        bytes4 selector = bytes4(keccak256("InvalidRewardRate"));
        vm.expectRevert(selector);
        staking.createPool{value: 0.00001 ether}(_info);
    }

    function testFailCreatePoolWithInvalidAnnualRate2() external {
        vm.startPrank(user1);

        deal(user1, 100 ether);

        IERC20(address(busd)).approve(address(staking), type(uint256).max);

        ICentherStaking.PoolCreationInputs memory _info = ICentherStaking
            .PoolCreationInputs(
                address(deXa),
                address(busd),
                10001,
                5e18,
                10000e18,
                365 days,
                2,
                1,
                1 weeks,
                10000e18,
                100,
                "www.staking.com/1",
                true,
                true
            );

        bytes4 selector = bytes4(keccak256("InvalidRewardRate"));
        vm.expectRevert(selector);
        staking.createPool{value: 0.00001 ether}(_info);
    }

    function testFailCreatePoolDueToNotAllowance() external {
        vm.startPrank(user1);

        deal(user1, 100 ether);

        IERC20(address(busd)).approve(address(staking), 100e18);

        ICentherStaking.PoolCreationInputs memory _info = ICentherStaking
            .PoolCreationInputs(
                address(deXa),
                address(busd),
                500,
                5e18,
                10000e18,
                365 days,
                2,
                1,
                1 weeks,
                10000e18,
                100,
                "www.staking.com/1",
                true,
                true
            );

        bytes4 selector = bytes4(keccak256("GiveMaxAllowanceOfRewardToken"));
        vm.expectRevert(selector);
        staking.createPool{value: 0.00001 ether}(_info);
    }

    function testFailCreatePoolWithoutPlatformFees() external {
        vm.startPrank(user1);

        deal(user1, 100 ether);

        IERC20(address(busd)).approve(address(staking), type(uint256).max);

        ICentherStaking.PoolCreationInputs memory _info = ICentherStaking
            .PoolCreationInputs(
                address(deXa),
                address(busd),
                200,
                5e18,
                10000e18,
                365 days,
                2,
                0,
                1 weeks,
                10000e18,
                100,
                "www.staking.com/1",
                true,
                true
            );
        vm.expectRevert("ValueNotEqualToPlatformFees()");
        staking.createPool(_info);
    }

    function testFailPoolAlreadyActive() external {
        vm.startPrank(user1);

        deal(user1, 100 ether);

        IERC20(address(busd)).approve(address(staking), type(uint256).max);

        ICentherStaking.PoolCreationInputs memory _info = ICentherStaking
            .PoolCreationInputs(
                address(deXa),
                address(busd),
                200,
                5e18,
                10000e18,
                365 days,
                2,
                0,
                1 weeks,
                10000e18,
                100,
                "www.staking.com/1",
                true,
                true
            );

        staking.createPool{value: 0.00001 ether}(_info);

        assert(staking.poolIds() == 1);

        ICentherStaking.AffiliateSettingInput memory _setting = ICentherStaking
            .AffiliateSettingInput({
                levelOne: 600,
                levelTwo: 400,
                levelThree: 200,
                levelFour: 200,
                levelFive: 200,
                levelSix: 200
            });

        vm.expectRevert("CannotSetAffiliateSettingForActivePool()");
        staking.setAffiliateSetting(1, _setting);
    }

    function testStakeByUser2WhenLpTrue() external {
        vm.startPrank(user1);

        deal(user1, 100 ether);

        deal(address(deXa), user2, 1000e18);

        IERC20(address(busd)).approve(address(staking), type(uint256).max);

        ICentherStaking.PoolCreationInputs memory _info = ICentherStaking
            .PoolCreationInputs(
                address(deXa),
                address(busd),
                200,
                5e18,
                10000e18,
                365 days,
                2,
                1,
                1 weeks,
                10000e18,
                100,
                "www.staking.com/1",
                true,
                true
            );

        staking.createPool{value: 0.00001 ether}(_info);

        ICentherStaking.AffiliateSettingInput memory _setting = ICentherStaking
            .AffiliateSettingInput({
                levelOne: 600,
                levelTwo: 400,
                levelThree: 200,
                levelFour: 200,
                levelFive: 200,
                levelSix: 200
            });

        staking.setAffiliateSetting(1, _setting);

        assert(staking.poolIds() == 1);

        changePrank(user2);

        IERC20(address(deXa)).approve(address(staking), type(uint256).max);

        staking.stake(1, 1000e18, address(0));

        (, uint256 stakedAmount, , , ) = staking.userStakes(1, user2, 0);

        assert(stakedAmount == 1000e18);

        assert(deXa.balanceOf(address(staking)) == 1000e18);
        assert(deXa.balanceOf(user1) == 0);
    }

    function testStakeByUser2WhenLpFalse() external {
        vm.startPrank(user1);

        deal(user1, 100 ether);

        deal(address(deXa), user2, 1000e18);

        IERC20(address(busd)).approve(address(staking), type(uint256).max);

        ICentherStaking.PoolCreationInputs memory _info = ICentherStaking
            .PoolCreationInputs(
                address(deXa),
                address(busd),
                200,
                5e18,
                10000e18,
                365 days,
                2,
                1,
                1 weeks,
                10000e18,
                100,
                "www.staking.com/1",
                true,
                false
            );

        staking.createPool{value: 0.00001 ether}(_info);

        ICentherStaking.AffiliateSettingInput memory _setting = ICentherStaking
            .AffiliateSettingInput({
                levelOne: 600,
                levelTwo: 400,
                levelThree: 200,
                levelFour: 200,
                levelFive: 200,
                levelSix: 200
            });

        staking.setAffiliateSetting(1, _setting);

        assert(staking.poolIds() == 1);

        changePrank(user2);

        IERC20(address(deXa)).approve(address(staking), type(uint256).max);

        staking.stake(1, 1000e18, address(0));

        (, uint256 stakedAmount, , , ) = staking.userStakes(1, user2, 0);

        assert(stakedAmount == 1000e18);

        assert(deXa.balanceOf(address(staking)) == 0);
        assert(deXa.balanceOf(user1) == 1000e18);
    }

    function testShouldFailOnStakeDueToInvalidPoolId() external {
        vm.startPrank(user1);

        deal(user1, 100 ether);

        deal(address(deXa), user2, 1000e18);

        IERC20(address(busd)).approve(address(staking), type(uint256).max);

        ICentherStaking.PoolCreationInputs memory _info = ICentherStaking
            .PoolCreationInputs(
                address(deXa),
                address(busd),
                200,
                5e18,
                10000e18,
                365 days,
                2,
                1,
                1 weeks,
                10000e18,
                100,
                "www.staking.com/1",
                true,
                true
            );

        staking.createPool{value: 0.00001 ether}(_info);

        ICentherStaking.AffiliateSettingInput memory _setting = ICentherStaking
            .AffiliateSettingInput({
                levelOne: 600,
                levelTwo: 400,
                levelThree: 200,
                levelFour: 200,
                levelFive: 200,
                levelSix: 200
            });

        staking.setAffiliateSetting(1, _setting);

        changePrank(user2);

        IERC20(address(deXa)).approve(address(staking), type(uint256).max);

        bytes4 selector = bytes4(keccak256("PoolNotExist()"));
        vm.expectRevert(abi.encodeWithSelector(selector));
        staking.stake(2, 1000e18, address(0));
    }

    function testShouldFailOnStakeDueToInactive() external {
        vm.startPrank(user1);

        deal(user1, 100 ether);

        deal(address(deXa), user2, 1000e18);

        IERC20(address(busd)).approve(address(staking), type(uint256).max);

        ICentherStaking.PoolCreationInputs memory _info = ICentherStaking
            .PoolCreationInputs(
                address(deXa),
                address(busd),
                200,
                5e18,
                10000e18,
                365 days,
                2,
                1,
                1 weeks,
                10000e18,
                100,
                "www.staking.com/1",
                true,
                true
            );

        staking.createPool{value: 0.00001 ether}(_info);

        assert(staking.poolIds() == 1);

        changePrank(user2);

        IERC20(address(deXa)).approve(address(staking), type(uint256).max);
        bytes4 selector = bytes4(keccak256("PoolNotActive()"));
        vm.expectRevert(abi.encodeWithSelector(selector));
        staking.stake(1, 1000e18, address(0));
    }

    function testShouldFailDueToOwnerStake() external {
        vm.startPrank(user1);

        deal(user1, 100 ether);

        deal(address(deXa), user2, 1000e18);

        IERC20(address(busd)).approve(address(staking), type(uint256).max);

        ICentherStaking.PoolCreationInputs memory _info = ICentherStaking
            .PoolCreationInputs(
                address(deXa),
                address(busd),
                200,
                5e18,
                10000e18,
                365 days,
                2,
                1,
                1 weeks,
                10000e18,
                100,
                "www.staking.com/1",
                true,
                true
            );

        staking.createPool{value: 0.00001 ether}(_info);

        ICentherStaking.AffiliateSettingInput memory _setting = ICentherStaking
            .AffiliateSettingInput({
                levelOne: 600,
                levelTwo: 400,
                levelThree: 200,
                levelFour: 200,
                levelFive: 200,
                levelSix: 200
            });

        staking.setAffiliateSetting(1, _setting);

        assert(staking.poolIds() == 1);

        IERC20(address(deXa)).approve(address(staking), type(uint256).max);

        bytes4 selector = bytes4(keccak256("PoolOwnerNotEligibleToStake()"));
        vm.expectRevert(abi.encodeWithSelector(selector));

        staking.stake(1, 1000e18, address(0));
    }

    function testShouldFailInvalidStakeAmountMin() external {
        vm.startPrank(user1);

        deal(user1, 100 ether);

        deal(address(deXa), user2, 1000e18);

        IERC20(address(busd)).approve(address(staking), type(uint256).max);

        ICentherStaking.PoolCreationInputs memory _info = ICentherStaking
            .PoolCreationInputs(
                address(deXa),
                address(busd),
                200,
                5000e18,
                10000e18,
                365 days,
                2,
                1,
                1 weeks,
                10000e18,
                100,
                "www.staking.com/1",
                true,
                true
            );

        staking.createPool{value: 0.00001 ether}(_info);

        ICentherStaking.AffiliateSettingInput memory _setting = ICentherStaking
            .AffiliateSettingInput({
                levelOne: 600,
                levelTwo: 400,
                levelThree: 200,
                levelFour: 200,
                levelFive: 200,
                levelSix: 200
            });

        staking.setAffiliateSetting(1, _setting);

        assert(staking.poolIds() == 1);

        changePrank(user2);

        IERC20(address(deXa)).approve(address(staking), type(uint256).max);

        bytes4 selector = bytes4(keccak256("InvalidStakeAmount()"));
        vm.expectRevert(abi.encodeWithSelector(selector));

        staking.stake(1, 1000e18, address(0));
    }

    function testShouldFailInvalidStakeAmountMax() external {
        vm.startPrank(user1);

        deal(user1, 100 ether);

        deal(address(deXa), user2, 1000000e18);

        IERC20(address(busd)).approve(address(staking), type(uint256).max);

        ICentherStaking.PoolCreationInputs memory _info = ICentherStaking
            .PoolCreationInputs(
                address(deXa),
                address(busd),
                200,
                5000e18,
                10000e18,
                365 days,
                2,
                1,
                1 weeks,
                10000e18,
                100,
                "www.staking.com/1",
                true,
                true
            );

        staking.createPool{value: 0.00001 ether}(_info);

        ICentherStaking.AffiliateSettingInput memory _setting = ICentherStaking
            .AffiliateSettingInput({
                levelOne: 600,
                levelTwo: 400,
                levelThree: 200,
                levelFour: 200,
                levelFive: 200,
                levelSix: 200
            });

        staking.setAffiliateSetting(1, _setting);

        assert(staking.poolIds() == 1);

        changePrank(user2);

        IERC20(address(deXa)).approve(address(staking), type(uint256).max);

        bytes4 selector = bytes4(keccak256("InvalidStakeAmount()"));
        vm.expectRevert(abi.encodeWithSelector(selector));

        staking.stake(1, 100000e18, address(0));
    }

    function testShouldFailStakeMaxStakableAmountReached() external {
        vm.startPrank(user1);

        deal(user1, 100 ether);

        deal(address(deXa), user2, 1000000e18);

        IERC20(address(busd)).approve(address(staking), type(uint256).max);

        ICentherStaking.PoolCreationInputs memory _info = ICentherStaking
            .PoolCreationInputs(
                address(deXa),
                address(busd),
                200,
                100e18,
                10000e18,
                365 days,
                2,
                1,
                1 weeks,
                100e18,
                100,
                "www.staking.com/1",
                true,
                true
            );

        staking.createPool{value: 0.00001 ether}(_info);

        ICentherStaking.AffiliateSettingInput memory _setting = ICentherStaking
            .AffiliateSettingInput({
                levelOne: 600,
                levelTwo: 400,
                levelThree: 200,
                levelFour: 200,
                levelFive: 200,
                levelSix: 200
            });

        staking.setAffiliateSetting(1, _setting);

        assert(staking.poolIds() == 1);

        changePrank(user2);

        IERC20(address(deXa)).approve(address(staking), type(uint256).max);

        bytes4 selector = bytes4(keccak256("MaxStakableAmountReached()"));
        vm.expectRevert(abi.encodeWithSelector(selector));

        staking.stake(1, 1000e18, address(0));
    }

    // LP is true, testing:

    function testStakeAndClaimByUser2AfterStakingDurationLpTrue() external {
        vm.startPrank(user1);

        deal(user1, 100 ether);

        deal(address(deXa), user2, 1000e18);

        IERC20(address(busd)).approve(address(staking), type(uint256).max);

        ICentherStaking.PoolCreationInputs memory _info = ICentherStaking
            .PoolCreationInputs(
                address(deXa),
                address(busd),
                2000,
                5e18,
                10000e18,
                365 days,
                1 weeks,
                1,
                1 weeks,
                10000e18,
                100,
                "www.staking.com/1",
                true,
                true
            );

        staking.createPool{value: 0.00001 ether}(_info);

        ICentherStaking.AffiliateSettingInput memory _setting = ICentherStaking
            .AffiliateSettingInput({
                levelOne: 600,
                levelTwo: 400,
                levelThree: 200,
                levelFour: 200,
                levelFive: 200,
                levelSix: 200
            });

        staking.setAffiliateSetting(1, _setting);

        assert(staking.poolIds() == 1);

        changePrank(user2);

        IERC20(address(deXa)).approve(address(staking), type(uint256).max);

        staking.stake(1, 100e18, address(0));

        (, uint256 stakedAmount, , , ) = staking.userStakes(1, user2, 0);

        assert(stakedAmount == 100e18);

        vm.warp(108 weeks); // After 2 years, but amount get according to 1 yaer

        staking.claimReward(1);

        assert(busd.balanceOf(user2) == 20054945054945054945);
    }

    function testStakeAndClaimByUser2AfterFirstRewardLpTrue() external {
        vm.startPrank(user1);

        deal(user1, 100 ether);

        deal(address(deXa), user2, 1000e18);

        IERC20(address(busd)).approve(address(staking), type(uint256).max);

        ICentherStaking.PoolCreationInputs memory _info = ICentherStaking
            .PoolCreationInputs(
                address(deXa),
                address(busd),
                2000,
                5e18,
                10000e18,
                365 days,
                1 weeks,
                1,
                1 weeks,
                10000e18,
                100,
                "www.staking.com/1",
                true,
                true
            );

        staking.createPool{value: 0.00001 ether}(_info);

        ICentherStaking.AffiliateSettingInput memory _setting = ICentherStaking
            .AffiliateSettingInput({
                levelOne: 600,
                levelTwo: 400,
                levelThree: 200,
                levelFour: 200,
                levelFive: 200,
                levelSix: 200
            });

        staking.setAffiliateSetting(1, _setting);

        assert(staking.poolIds() == 1);

        changePrank(user2);

        IERC20(address(deXa)).approve(address(staking), type(uint256).max);

        staking.stake(1, 100e18, address(0));

        (, uint256 stakedAmount, , , ) = staking.userStakes(1, user2, 0);

        assert(stakedAmount == 100e18);

        vm.warp(1.1 weeks); // After 2 years, but amount get according to 1 yaer

        staking.claimReward(1);

        assert(busd.balanceOf(user2) == 423076287138787138);
    }

    function testStakeAndClaimByUser2BeforeFirstRewardLpTrue() external {
        vm.startPrank(user1);

        deal(user1, 100 ether);

        deal(address(deXa), user2, 1000e18);

        IERC20(address(busd)).approve(address(staking), type(uint256).max);

        ICentherStaking.PoolCreationInputs memory _info = ICentherStaking
            .PoolCreationInputs(
                address(deXa),
                address(busd),
                2000,
                5e18,
                10000e18,
                365 days,
                1 weeks,
                1,
                10 days,
                10000e18,
                100,
                "www.staking.com/1",
                true,
                true
            );

        staking.createPool{value: 0.00001 ether}(_info);

        ICentherStaking.AffiliateSettingInput memory _setting = ICentherStaking
            .AffiliateSettingInput({
                levelOne: 600,
                levelTwo: 400,
                levelThree: 200,
                levelFour: 200,
                levelFive: 200,
                levelSix: 200
            });

        staking.setAffiliateSetting(1, _setting);

        assert(staking.poolIds() == 1);

        changePrank(user2);

        IERC20(address(deXa)).approve(address(staking), type(uint256).max);

        staking.stake(1, 100e18, address(0));

        (, uint256 stakedAmount, , , ) = staking.userStakes(1, user2, 0);

        assert(stakedAmount == 100e18);

        vm.warp(9 days); // After 2 years, but amount get according to 1 yaer

        staking.claimReward(1);

        assert(busd.balanceOf(user2) == 0);
    }

    function testStakeAndClaimByUser2AfterClaimDurationLpTrue() external {
        vm.startPrank(user1);

        deal(user1, 100 ether);

        deal(address(deXa), user2, 1000e18);

        IERC20(address(busd)).approve(address(staking), type(uint256).max);

        ICentherStaking.PoolCreationInputs memory _info = ICentherStaking
            .PoolCreationInputs(
                address(deXa),
                address(busd),
                2000,
                5e18,
                10000e18,
                365 days,
                1 weeks,
                1,
                10 days,
                10000e18,
                100,
                "www.staking.com/1",
                true,
                true
            );

        staking.createPool{value: 0.00001 ether}(_info);

        ICentherStaking.AffiliateSettingInput memory _setting = ICentherStaking
            .AffiliateSettingInput({
                levelOne: 600,
                levelTwo: 400,
                levelThree: 200,
                levelFour: 200,
                levelFive: 200,
                levelSix: 200
            });

        staking.setAffiliateSetting(1, _setting);

        assert(staking.poolIds() == 1);

        changePrank(user2);

        IERC20(address(deXa)).approve(address(staking), type(uint256).max);

        staking.stake(1, 100e18, address(0));

        (, uint256 stakedAmount, , , ) = staking.userStakes(1, user2, 0);

        assert(stakedAmount == 100e18);

        vm.warp(11 days);

        staking.claimReward(1);

        vm.warp(block.timestamp + 7 days);

        staking.claimReward(1);

        assert(
            busd.balanceOf(user2) == 604394968457468457 + 384615384615384615
        );
    }

    // LP is false, testing:
    function testStakeAndClaimByUser2AfterStakingDurationLpFalse() external {
        vm.startPrank(user1);

        deal(user1, 100 ether);

        deal(address(deXa), user2, 1000e18);

        IERC20(address(busd)).approve(address(staking), type(uint256).max);

        ICentherStaking.PoolCreationInputs memory _info = ICentherStaking
            .PoolCreationInputs(
                address(deXa),
                address(busd),
                2000,
                5e18,
                10000e18,
                365 days,
                1 weeks,
                1,
                1 weeks,
                10000e18,
                100,
                "www.staking.com/1",
                true,
                false
            );

        staking.createPool{value: 0.00001 ether}(_info);

        ICentherStaking.AffiliateSettingInput memory _setting = ICentherStaking
            .AffiliateSettingInput({
                levelOne: 600,
                levelTwo: 400,
                levelThree: 200,
                levelFour: 200,
                levelFive: 200,
                levelSix: 200
            });

        staking.setAffiliateSetting(1, _setting);

        assert(staking.poolIds() == 1);

        changePrank(user2);

        IERC20(address(deXa)).approve(address(staking), type(uint256).max);

        staking.stake(1, 100e18, address(0));

        (, uint256 stakedAmount, , , ) = staking.userStakes(1, user2, 0);

        assert(stakedAmount == 100e18);

        vm.warp(108 weeks); // After 2 years, but amount get according to 1 yaer

        console2.log("user2 bal: ", busd.balanceOf(user2));
        staking.claimReward(1);

        assert(busd.balanceOf(user2) == 20054945054945054945);
    }

    function testStakeAndClaimByUser2AfterFirstRewardLpFalse() external {
        vm.startPrank(user1);

        deal(user1, 100 ether);

        deal(address(deXa), user2, 1000e18);

        IERC20(address(busd)).approve(address(staking), type(uint256).max);

        ICentherStaking.PoolCreationInputs memory _info = ICentherStaking
            .PoolCreationInputs(
                address(deXa),
                address(busd),
                2000,
                5e18,
                10000e18,
                365 days,
                1 weeks,
                1,
                1 weeks,
                10000e18,
                100,
                "www.staking.com/1",
                true,
                false
            );

        staking.createPool{value: 0.00001 ether}(_info);

        ICentherStaking.AffiliateSettingInput memory _setting = ICentherStaking
            .AffiliateSettingInput({
                levelOne: 600,
                levelTwo: 400,
                levelThree: 200,
                levelFour: 200,
                levelFive: 200,
                levelSix: 200
            });

        staking.setAffiliateSetting(1, _setting);

        assert(staking.poolIds() == 1);

        changePrank(user2);

        IERC20(address(deXa)).approve(address(staking), type(uint256).max);

        staking.stake(1, 100e18, address(0));

        (, uint256 stakedAmount, , , ) = staking.userStakes(1, user2, 0);

        assert(stakedAmount == 100e18);

        vm.warp(1.1 weeks); // After 2 years, but amount get according to 1 yaer

        staking.claimReward(1);

        assert(busd.balanceOf(user2) == 423076287138787138);
    }

    function testStakeAndClaimByUser2BeforeFirstRewardLpFalse() external {
        vm.startPrank(user1);

        deal(user1, 100 ether);

        deal(address(deXa), user2, 1000e18);

        IERC20(address(busd)).approve(address(staking), type(uint256).max);

        ICentherStaking.PoolCreationInputs memory _info = ICentherStaking
            .PoolCreationInputs(
                address(deXa),
                address(busd),
                2000,
                5e18,
                10000e18,
                365 days,
                1 weeks,
                1,
                10 days,
                10000e18,
                100,
                "www.staking.com/1",
                true,
                false
            );

        staking.createPool{value: 0.00001 ether}(_info);

        ICentherStaking.AffiliateSettingInput memory _setting = ICentherStaking
            .AffiliateSettingInput({
                levelOne: 600,
                levelTwo: 400,
                levelThree: 200,
                levelFour: 200,
                levelFive: 200,
                levelSix: 200
            });

        staking.setAffiliateSetting(1, _setting);

        assert(staking.poolIds() == 1);

        changePrank(user2);

        IERC20(address(deXa)).approve(address(staking), type(uint256).max);

        staking.stake(1, 100e18, address(0));

        (, uint256 stakedAmount, , , ) = staking.userStakes(1, user2, 0);

        assert(stakedAmount == 100e18);

        vm.warp(9 days); // After 2 years, but amount get according to 1 yaer

        staking.claimReward(1);

        assert(busd.balanceOf(user2) == 0);
    }

    function testStakeAndClaimByUser2AfterClaimDurationLpFalse() external {
        vm.startPrank(user1);

        deal(user1, 100 ether);

        deal(address(deXa), user2, 1000e18);

        IERC20(address(busd)).approve(address(staking), type(uint256).max);

        ICentherStaking.PoolCreationInputs memory _info = ICentherStaking
            .PoolCreationInputs(
                address(deXa),
                address(busd),
                2000,
                5e18,
                10000e18,
                365 days,
                1 weeks,
                1,
                10 days,
                10000e18,
                100,
                "www.staking.com/1",
                true,
                false
            );

        staking.createPool{value: 0.00001 ether}(_info);

        ICentherStaking.AffiliateSettingInput memory _setting = ICentherStaking
            .AffiliateSettingInput({
                levelOne: 600,
                levelTwo: 400,
                levelThree: 200,
                levelFour: 200,
                levelFive: 200,
                levelSix: 200
            });

        staking.setAffiliateSetting(1, _setting);

        assert(staking.poolIds() == 1);

        changePrank(user2);

        IERC20(address(deXa)).approve(address(staking), type(uint256).max);

        staking.stake(1, 100e18, address(0));

        (, uint256 stakedAmount, , , ) = staking.userStakes(1, user2, 0);

        assert(stakedAmount == 100e18);

        vm.warp(11 days);

        staking.claimReward(1);

        vm.warp(block.timestamp + 7 days);

        staking.claimReward(1);

        assert(
            busd.balanceOf(user2) == 604394968457468457 + 384615384615384615
        );
    }

    // unstake
    function testAfterStakingDurationUnstakeByUser2UnstakableFalse() external {
        vm.startPrank(user1);

        deal(user1, 100 ether);

        deal(address(deXa), user2, 1000e18);

        IERC20(address(busd)).approve(address(staking), type(uint256).max);

        ICentherStaking.PoolCreationInputs memory _info = ICentherStaking
            .PoolCreationInputs(
                address(deXa),
                address(busd),
                200,
                5e18,
                10000e18,
                365 days,
                2,
                1,
                1 weeks,
                10000e18,
                100,
                "www.staking.com/1",
                false,
                true
            );

        staking.createPool{value: 0.00001 ether}(_info);

        ICentherStaking.AffiliateSettingInput memory _setting = ICentherStaking
            .AffiliateSettingInput({
                levelOne: 600,
                levelTwo: 400,
                levelThree: 200,
                levelFour: 200,
                levelFive: 200,
                levelSix: 200
            });

        staking.setAffiliateSetting(1, _setting);

        assert(staking.poolIds() == 1);

        changePrank(user2);

        IERC20(address(deXa)).approve(address(staking), type(uint256).max);

        staking.stake(1, 1000e18, address(0));

        (, uint256 stakedAmount, , , ) = staking.userStakes(1, user2, 0);

        assert(stakedAmount == 1000e18);

        assert(deXa.balanceOf(address(staking)) == 1000e18);
        assert(deXa.balanceOf(user1) == 0);

        vm.warp(53 weeks);
        staking.unstake(1, 1000e18);

        assert(deXa.balanceOf(user2) == 1000e18);
    }

    function testBeforeStakingDurationUnstakeByUser2UnstakableFalse() external {
        vm.startPrank(user1);

        deal(user1, 100 ether);

        deal(address(deXa), user2, 1000e18);

        IERC20(address(busd)).approve(address(staking), type(uint256).max);

        ICentherStaking.PoolCreationInputs memory _info = ICentherStaking
            .PoolCreationInputs(
                address(deXa),
                address(busd),
                200,
                5e18,
                10000e18,
                365 days,
                2,
                1,
                1 weeks,
                10000e18,
                100,
                "www.staking.com/1",
                false,
                true
            );

        staking.createPool{value: 0.00001 ether}(_info);

        ICentherStaking.AffiliateSettingInput memory _setting = ICentherStaking
            .AffiliateSettingInput({
                levelOne: 600,
                levelTwo: 400,
                levelThree: 200,
                levelFour: 200,
                levelFive: 200,
                levelSix: 200
            });

        staking.setAffiliateSetting(1, _setting);

        assert(staking.poolIds() == 1);

        changePrank(user2);

        IERC20(address(deXa)).approve(address(staking), type(uint256).max);

        staking.stake(1, 1000e18, address(0));

        (, uint256 stakedAmount, , , ) = staking.userStakes(1, user2, 0);

        assert(stakedAmount == 1000e18);

        assert(deXa.balanceOf(address(staking)) == 1000e18);
        assert(deXa.balanceOf(user1) == 0);

        vm.warp(50 weeks);

        bytes4 selector = bytes4(keccak256("Locked()"));
        vm.expectRevert(abi.encodeWithSelector(selector));

        staking.unstake(1, 1000e18);
    }

    function testAfterStakingDurationUnstakeByUser2UnstakableTrue() external {
        vm.startPrank(user1);

        deal(user1, 100 ether);

        deal(address(deXa), user2, 1000e18);

        IERC20(address(busd)).approve(address(staking), type(uint256).max);

        ICentherStaking.PoolCreationInputs memory _info = ICentherStaking
            .PoolCreationInputs(
                address(deXa),
                address(busd),
                200,
                5e18,
                10000e18,
                365 days,
                2,
                1,
                1 weeks,
                10000e18,
                100,
                "www.staking.com/1",
                true,
                true
            );

        staking.createPool{value: 0.00001 ether}(_info);

        ICentherStaking.AffiliateSettingInput memory _setting = ICentherStaking
            .AffiliateSettingInput({
                levelOne: 600,
                levelTwo: 400,
                levelThree: 200,
                levelFour: 200,
                levelFive: 200,
                levelSix: 200
            });

        staking.setAffiliateSetting(1, _setting);

        assert(staking.poolIds() == 1);

        changePrank(user2);

        IERC20(address(deXa)).approve(address(staking), type(uint256).max);

        staking.stake(1, 1000e18, address(0));

        (, uint256 stakedAmount, , , ) = staking.userStakes(1, user2, 0);

        assert(stakedAmount == 1000e18);

        assert(deXa.balanceOf(address(staking)) == 1000e18);
        assert(deXa.balanceOf(user1) == 0);

        vm.warp(53 weeks);

        staking.unstake(1, 1000e18);

        assert(deXa.balanceOf(user2) == 1000e18);
    }

    function testBeforeStakingDurationUnstakeByUser2UnstakableTrue() external {
        vm.startPrank(user1);

        deal(user1, 100 ether);

        deal(address(deXa), user2, 1000e18);

        IERC20(address(busd)).approve(address(staking), type(uint256).max);

        ICentherStaking.PoolCreationInputs memory _info = ICentherStaking
            .PoolCreationInputs(
                address(deXa),
                address(busd),
                200,
                5e18,
                10000e18,
                365 days,
                2,
                1,
                1 weeks,
                10000e18,
                100,
                "www.staking.com/1",
                true,
                true
            );

        staking.createPool{value: 0.00001 ether}(_info);

        ICentherStaking.AffiliateSettingInput memory _setting = ICentherStaking
            .AffiliateSettingInput({
                levelOne: 600,
                levelTwo: 400,
                levelThree: 200,
                levelFour: 200,
                levelFive: 200,
                levelSix: 200
            });

        staking.setAffiliateSetting(1, _setting);

        assert(staking.poolIds() == 1);

        changePrank(user2);

        IERC20(address(deXa)).approve(address(staking), type(uint256).max);

        staking.stake(1, 1000e18, address(0));

        (, uint256 stakedAmount, , , ) = staking.userStakes(1, user2, 0);

        assert(stakedAmount == 1000e18);

        assert(deXa.balanceOf(address(staking)) == 1000e18);
        assert(deXa.balanceOf(user1) == 0);

        vm.warp(51 weeks);

        staking.unstake(1, 1000e18);

        assert(deXa.balanceOf(user2) == 990000000000000000000);
    }

    function testBeforeStakingDurationUnstakeByUser2LpFalse() external {
        vm.startPrank(user1);

        deal(user1, 100 ether);

        deal(address(deXa), user2, 1000e18);

        IERC20(address(busd)).approve(address(staking), type(uint256).max);
        IERC20(address(deXa)).approve(address(staking), type(uint256).max);

        ICentherStaking.PoolCreationInputs memory _info = ICentherStaking
            .PoolCreationInputs(
                address(deXa),
                address(busd),
                200,
                5e18,
                10000e18,
                365 days,
                2,
                1,
                1 weeks,
                10000e18,
                100,
                "www.staking.com/1",
                true,
                false
            );

        staking.createPool{value: 0.00001 ether}(_info);

        ICentherStaking.AffiliateSettingInput memory _setting = ICentherStaking
            .AffiliateSettingInput({
                levelOne: 600,
                levelTwo: 400,
                levelThree: 200,
                levelFour: 200,
                levelFive: 200,
                levelSix: 200
            });

        staking.setAffiliateSetting(1, _setting);

        assert(staking.poolIds() == 1);

        changePrank(user2);

        IERC20(address(deXa)).approve(address(staking), type(uint256).max);

        staking.stake(1, 1000e18, address(0));

        (, uint256 stakedAmount, , , ) = staking.userStakes(1, user2, 0);

        assert(stakedAmount == 1000e18);

        vm.warp(51 weeks);

        staking.unstake(1, 1000e18);

        assert(deXa.balanceOf(user2) == 990000000000000000000);
    }
}
