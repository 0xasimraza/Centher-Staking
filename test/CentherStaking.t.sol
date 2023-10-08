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

    event PoolStateChanged(uint256, bool);

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

        ICentherStaking.PoolCreationInputs memory _info = ICentherStaking.PoolCreationInputs(
            "project",
            block.timestamp,
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
            0,
            "www.staking.com/1",
            true,
            true,
            true
        );

        staking.createPool{value: 0.00001 ether}(_info);

        ICentherStaking.AffiliateSettingInput memory _setting = ICentherStaking.AffiliateSettingInput({
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

    function testTogglePoolState() external {
        vm.startPrank(user1);

        deal(user1, 100 ether);

        IERC20(address(busd)).approve(address(staking), type(uint256).max);

        ICentherStaking.PoolCreationInputs memory _info = ICentherStaking.PoolCreationInputs(
            "project",
            block.timestamp,
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
            0,
            "www.staking.com/1",
            true,
            true,
            true
        );

        staking.createPool{value: 0.00001 ether}(_info);

        ICentherStaking.AffiliateSettingInput memory _setting = ICentherStaking.AffiliateSettingInput({
            levelOne: 600,
            levelTwo: 400,
            levelThree: 200,
            levelFour: 200,
            levelFive: 200,
            levelSix: 200
        });

        staking.setAffiliateSetting(1, _setting);

        assert(staking.poolIds() == 1);
        vm.expectEmit(true, true, false, true, address(staking));
        emit PoolStateChanged(1, false);
        staking.togglePoolState(1, false);
    }

    function testTogglePoolStateRevertAlreadySetted() external {
        vm.startPrank(user1);

        deal(user1, 100 ether);

        IERC20(address(busd)).approve(address(staking), type(uint256).max);

        ICentherStaking.PoolCreationInputs memory _info = ICentherStaking.PoolCreationInputs(
            "project",
            block.timestamp,
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
            0,
            "www.staking.com/1",
            true,
            true,
            true
        );

        staking.createPool{value: 0.00001 ether}(_info);

        ICentherStaking.AffiliateSettingInput memory _setting = ICentherStaking.AffiliateSettingInput({
            levelOne: 600,
            levelTwo: 400,
            levelThree: 200,
            levelFour: 200,
            levelFive: 200,
            levelSix: 200
        });

        staking.setAffiliateSetting(1, _setting);

        assert(staking.poolIds() == 1);

        bytes4 selector = bytes4(keccak256("AlreadySetted()"));
        vm.expectRevert(abi.encodeWithSelector(selector));
        staking.togglePoolState(1, true);
    }

    function testCreatePoolWithInvalidStakeTokenAddress() external {
        vm.startPrank(user1);

        deal(user1, 100 ether);

        IERC20(address(busd)).approve(address(staking), type(uint256).max);

        ICentherStaking.PoolCreationInputs memory _info = ICentherStaking.PoolCreationInputs(
            "project",
            block.timestamp,
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
            0,
            "www.staking.com/1",
            true,
            true,
            true
        );

        bytes4 selector = bytes4(keccak256("InvalidTokenAddress()"));
        vm.expectRevert(abi.encodeWithSelector(selector));
        staking.createPool{value: 0.00001 ether}(_info);
    }

    function testCreatePoolWithInvalidAnnualRate1() external {
        vm.startPrank(user1);

        deal(user1, 100 ether);

        IERC20(address(busd)).approve(address(staking), type(uint256).max);

        ICentherStaking.PoolCreationInputs memory _info = ICentherStaking.PoolCreationInputs(
            "project",
            block.timestamp,
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
            0,
            "www.staking.com/1",
            true,
            true,
            true
        );

        bytes4 selector = bytes4(keccak256("InvalidRewardRate()"));
        vm.expectRevert(abi.encodeWithSelector(selector));
        staking.createPool{value: 0.00001 ether}(_info);
    }

    function testCreatePoolWithInvalidAnnualRate2() external {
        vm.startPrank(user1);

        deal(user1, 100 ether);

        IERC20(address(busd)).approve(address(staking), type(uint256).max);

        ICentherStaking.PoolCreationInputs memory _info = ICentherStaking.PoolCreationInputs(
            "project",
            block.timestamp,
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
            0,
            "www.staking.com/1",
            true,
            true,
            true
        );

        bytes4 selector = bytes4(keccak256("InvalidRewardRate()"));
        vm.expectRevert(abi.encodeWithSelector(selector));
        staking.createPool{value: 0.00001 ether}(_info);
    }

    function testShouldFailCreatePoolWithInvalidRefMode() external {
        vm.startPrank(user1);

        deal(user1, 100 ether);

        IERC20(address(busd)).approve(address(staking), type(uint256).max);

        ICentherStaking.PoolCreationInputs memory _info = ICentherStaking.PoolCreationInputs(
            "project",
            block.timestamp,
            address(deXa),
            address(busd),
            200,
            5e18,
            10000e18,
            365 days,
            1,
            3,
            1 weeks,
            10000e18,
            100,
            0,
            "www.staking.com/1",
            true,
            true,
            true
        );

        bytes4 selector = bytes4(keccak256("InvalidRewardMode()"));
        vm.expectRevert(abi.encodeWithSelector(selector));

        staking.createPool{value: 0.00001 ether}(_info);
    }

    function testCreatePoolDueToNotAllowance() external {
        vm.startPrank(user1);

        deal(user1, 100 ether);

        IERC20(address(busd)).approve(address(staking), 100e18);

        ICentherStaking.PoolCreationInputs memory _info = ICentherStaking.PoolCreationInputs(
            "project",
            block.timestamp,
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
            0,
            "www.staking.com/1",
            true,
            true,
            true
        );

        bytes4 selector = bytes4(keccak256("GiveMaxAllowanceOfRewardToken()"));
        vm.expectRevert(abi.encodeWithSelector(selector));
        staking.createPool{value: 0.00001 ether}(_info);
    }

    function testCreatePoolWithoutPlatformFees() external {
        vm.startPrank(user1);

        deal(user1, 100 ether);

        IERC20(address(busd)).approve(address(staking), type(uint256).max);

        ICentherStaking.PoolCreationInputs memory _info = ICentherStaking.PoolCreationInputs(
            "project",
            block.timestamp,
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
            0,
            "www.staking.com/1",
            true,
            true,
            true
        );

        bytes4 selector = bytes4(keccak256("ValueNotEqualToPlatformFees()"));
        vm.expectRevert(abi.encodeWithSelector(selector));
        staking.createPool(_info);
    }

    function testPoolAlreadyActive() external {
        vm.startPrank(user1);

        deal(user1, 100 ether);

        IERC20(address(busd)).approve(address(staking), type(uint256).max);

        ICentherStaking.PoolCreationInputs memory _info = ICentherStaking.PoolCreationInputs(
            "project",
            block.timestamp,
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
            0,
            "www.staking.com/1",
            true,
            true,
            true
        );

        staking.createPool{value: 0.00001 ether}(_info);

        assert(staking.poolIds() == 1);

        ICentherStaking.AffiliateSettingInput memory _setting = ICentherStaking.AffiliateSettingInput({
            levelOne: 600,
            levelTwo: 400,
            levelThree: 200,
            levelFour: 200,
            levelFive: 200,
            levelSix: 200
        });
        bytes4 selector = bytes4(keccak256("CannotSetAffiliateSettingForActivePool()"));
        vm.expectRevert(abi.encodeWithSelector(selector));
        staking.setAffiliateSetting(1, _setting);
    }

    //stake() testing

    function testStakeByUser2WhenLpTrue() external {
        vm.startPrank(user1);

        deal(user1, 100 ether);

        deal(address(deXa), user2, 1000e18);

        IERC20(address(busd)).approve(address(staking), type(uint256).max);

        ICentherStaking.PoolCreationInputs memory _info = ICentherStaking.PoolCreationInputs(
            "project",
            block.timestamp,
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
            0,
            "www.staking.com/1",
            true,
            true,
            true
        );

        staking.createPool{value: 0.00001 ether}(_info);

        ICentherStaking.AffiliateSettingInput memory _setting = ICentherStaking.AffiliateSettingInput({
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

        (, uint256 stakedAmount,,,) = staking.userStakes(1, user2, 0);

        assert(stakedAmount == 1000e18);

        assert(deXa.balanceOf(address(staking)) == 1000e18);
        assert(deXa.balanceOf(user1) == 0);
    }

    function testStakeAndFixedRefRewardLpTrue() external {
        vm.startPrank(user1);

        deal(user1, 100 ether);

        deal(address(deXa), user2, 1000e18);
        deal(address(deXa), other, 1000e18);

        IERC20(address(busd)).approve(address(staking), type(uint256).max);

        ICentherStaking.PoolCreationInputs memory _info = ICentherStaking.PoolCreationInputs(
            "project",
            block.timestamp,
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
            0,
            "www.staking.com/1",
            true,
            true,
            true
        );

        staking.createPool{value: 0.00001 ether}(_info);

        ICentherStaking.AffiliateSettingInput memory _setting = ICentherStaking.AffiliateSettingInput({
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

        changePrank(other);

        IERC20(address(deXa)).approve(address(staking), type(uint256).max);

        staking.stake(1, 1000e18, user2);
        assert(busd.balanceOf(user2) == 60000000000000000000);
    }

    function testStakeAndFixedRefRewardLpFalse() external {
        vm.startPrank(user1);

        deal(user1, 100 ether);

        deal(address(deXa), user2, 1000e18);
        deal(address(deXa), other, 1000e18);

        IERC20(address(busd)).approve(address(staking), type(uint256).max);

        IERC20(address(deXa)).approve(address(staking), type(uint256).max);

        ICentherStaking.PoolCreationInputs memory _info = ICentherStaking.PoolCreationInputs(
            "project",
            block.timestamp,
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
            0,
            "www.staking.com/1",
            true,
            false,
            true
        );

        staking.createPool{value: 0.00001 ether}(_info);

        ICentherStaking.AffiliateSettingInput memory _setting = ICentherStaking.AffiliateSettingInput({
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

        changePrank(other);

        IERC20(address(deXa)).approve(address(staking), type(uint256).max);

        staking.stake(1, 1000e18, user2);
        assert(busd.balanceOf(user2) == 60000000000000000000);
    }

    function testStakeByUser2WhenLpFalse() external {
        vm.startPrank(user1);

        deal(user1, 100 ether);

        deal(address(deXa), user2, 1000e18);

        IERC20(address(busd)).approve(address(staking), type(uint256).max);

        IERC20(address(deXa)).approve(address(staking), type(uint256).max);

        ICentherStaking.PoolCreationInputs memory _info = ICentherStaking.PoolCreationInputs(
            "project",
            block.timestamp,
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
            0,
            "www.staking.com/1",
            true,
            false,
            true
        );

        staking.createPool{value: 0.00001 ether}(_info);

        ICentherStaking.AffiliateSettingInput memory _setting = ICentherStaking.AffiliateSettingInput({
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

        (, uint256 stakedAmount,,,) = staking.userStakes(1, user2, 0);

        assert(stakedAmount == 1000e18);

        assert(deXa.balanceOf(address(staking)) == 0);
        assert(deXa.balanceOf(user1) == 1000e18);
    }

    function testShouldFailOnStakeDueToInvalidPoolId() external {
        vm.startPrank(user1);

        deal(user1, 100 ether);

        deal(address(deXa), user2, 1000e18);

        IERC20(address(busd)).approve(address(staking), type(uint256).max);

        ICentherStaking.PoolCreationInputs memory _info = ICentherStaking.PoolCreationInputs(
            "project",
            block.timestamp,
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
            0,
            "www.staking.com/1",
            true,
            true,
            true
        );

        staking.createPool{value: 0.00001 ether}(_info);

        ICentherStaking.AffiliateSettingInput memory _setting = ICentherStaking.AffiliateSettingInput({
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

        ICentherStaking.PoolCreationInputs memory _info = ICentherStaking.PoolCreationInputs(
            "project",
            block.timestamp,
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
            0,
            "www.staking.com/1",
            true,
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

        ICentherStaking.PoolCreationInputs memory _info = ICentherStaking.PoolCreationInputs(
            "project",
            block.timestamp,
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
            0,
            "www.staking.com/1",
            true,
            true,
            true
        );

        staking.createPool{value: 0.00001 ether}(_info);

        ICentherStaking.AffiliateSettingInput memory _setting = ICentherStaking.AffiliateSettingInput({
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

        ICentherStaking.PoolCreationInputs memory _info = ICentherStaking.PoolCreationInputs(
            "project",
            block.timestamp,
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
            0,
            "www.staking.com/1",
            true,
            true,
            true
        );

        staking.createPool{value: 0.00001 ether}(_info);

        ICentherStaking.AffiliateSettingInput memory _setting = ICentherStaking.AffiliateSettingInput({
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

        ICentherStaking.PoolCreationInputs memory _info = ICentherStaking.PoolCreationInputs(
            "project",
            block.timestamp,
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
            0,
            "www.staking.com/1",
            true,
            true,
            true
        );

        staking.createPool{value: 0.00001 ether}(_info);

        ICentherStaking.AffiliateSettingInput memory _setting = ICentherStaking.AffiliateSettingInput({
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

        ICentherStaking.PoolCreationInputs memory _info = ICentherStaking.PoolCreationInputs(
            "project",
            block.timestamp,
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
            0,
            "www.staking.com/1",
            true,
            true,
            true
        );

        staking.createPool{value: 0.00001 ether}(_info);

        ICentherStaking.AffiliateSettingInput memory _setting = ICentherStaking.AffiliateSettingInput({
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

    function testMultipleStakeAndUnstakeByUser2AfterStakingDuration() external {
        vm.startPrank(user1);

        deal(user1, 100 ether);

        deal(address(deXa), user2, 10000e18);

        IERC20(address(busd)).approve(address(staking), type(uint256).max);

        ICentherStaking.PoolCreationInputs memory _info = ICentherStaking.PoolCreationInputs(
            "project",
            block.timestamp,
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
            0,
            "www.staking.com/1",
            true,
            true,
            true
        );

        staking.createPool{value: 0.00001 ether}(_info);

        ICentherStaking.AffiliateSettingInput memory _setting = ICentherStaking.AffiliateSettingInput({
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

        for (uint256 i = 0; i < 10; i++) {
            staking.stake(1, 1000e18, address(0));
        }

        vm.warp(53 weeks);

        for (uint256 i = 0; i < 10; i++) {
            staking.unstake(1, 1000e18);
        }

        for (uint256 i = 0; i < 10; i++) {
            (, uint256 stakedAmount,,,) = staking.userStakes(1, user2, i);
            assert(stakedAmount == 0);
        }
        assert(deXa.balanceOf(user2) == 10000e18);
    }

    function testMultipleStakeAndUnstakeByUser2BeforeStakingDuration() external {
        vm.startPrank(user1);

        deal(user1, 100 ether);

        deal(address(deXa), user2, 100000e18);

        IERC20(address(busd)).approve(address(staking), type(uint256).max);

        ICentherStaking.PoolCreationInputs memory _info = ICentherStaking.PoolCreationInputs(
            "project",
            block.timestamp,
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
            0,
            "www.staking.com/1",
            true,
            true,
            true
        );

        staking.createPool{value: 0.00001 ether}(_info);

        ICentherStaking.AffiliateSettingInput memory _setting = ICentherStaking.AffiliateSettingInput({
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

        for (uint256 i = 0; i < 10; i++) {
            staking.stake(1, 1000e18, address(0));
        }

        vm.warp(15 weeks);

        for (uint256 i = 0; i < 10; i++) {
            staking.unstake(1, 1000e18);
        }

        for (uint256 i = 0; i < 10; i++) {
            (, uint256 stakedAmount,,,) = staking.userStakes(1, user2, i);
            assert(stakedAmount == 0);
        }

        assert(deXa.balanceOf(user2) == 99900000000000000000000);
    }

    function testMultipleStakeAndClaimRefReward() external {
        vm.startPrank(user1);

        deal(user1, 100 ether);

        deal(address(deXa), user2, 10000e18);
        deal(address(deXa), other, 10000e18);

        IERC20(address(busd)).approve(address(staking), type(uint256).max);

        ICentherStaking.PoolCreationInputs memory _info = ICentherStaking.PoolCreationInputs(
            "project",
            block.timestamp,
            address(deXa),
            address(busd),
            200,
            5e18,
            10000e18,
            365 days,
            2 weeks,
            2,
            3 weeks,
            10000e18,
            100,
            0,
            "www.staking.com/1",
            true,
            true,
            true
        );

        staking.createPool{value: 0.00001 ether}(_info);

        ICentherStaking.AffiliateSettingInput memory _setting = ICentherStaking.AffiliateSettingInput({
            levelOne: 600,
            levelTwo: 400,
            levelThree: 200,
            levelFour: 200,
            levelFive: 200,
            levelSix: 200
        });

        staking.setAffiliateSetting(1, _setting);

        assert(staking.poolIds() == 1);

        changePrank(other);

        IERC20(address(deXa)).approve(address(staking), type(uint256).max);

        staking.stake(1, 1000e18, address(0));

        changePrank(user2);

        IERC20(address(deXa)).approve(address(staking), type(uint256).max);

        for (uint256 i = 0; i < 10; i++) {
            staking.stake(1, 1000e18, other);
        }

        vm.warp(block.timestamp + 150 weeks);
        changePrank(other);
        staking.claimRewardForRef(1, user2);

        // assert(busd.balanceOf(other) == 240659340659340659340);
    }

    function testRevertPoolRefModeIsNotTimeBasedOnClaimRefReward() external {
        vm.startPrank(user1);

        deal(user1, 100 ether);

        deal(address(deXa), user2, 10000e18);
        deal(address(deXa), other, 10000e18);

        IERC20(address(busd)).approve(address(staking), type(uint256).max);

        ICentherStaking.PoolCreationInputs memory _info = ICentherStaking.PoolCreationInputs(
            "project",
            block.timestamp,
            address(deXa),
            address(busd),
            200,
            5e18,
            10000e18,
            365 days,
            2,
            1,
            0,
            10000e18,
            100,
            0,
            "www.staking.com/1",
            true,
            true,
            true
        );

        staking.createPool{value: 0.00001 ether}(_info);

        ICentherStaking.AffiliateSettingInput memory _setting = ICentherStaking.AffiliateSettingInput({
            levelOne: 600,
            levelTwo: 400,
            levelThree: 200,
            levelFour: 200,
            levelFive: 200,
            levelSix: 200
        });

        staking.setAffiliateSetting(1, _setting);

        assert(staking.poolIds() == 1);

        changePrank(other);

        IERC20(address(deXa)).approve(address(staking), type(uint256).max);

        staking.stake(1, 1000e18, address(0));

        changePrank(user2);

        IERC20(address(deXa)).approve(address(staking), type(uint256).max);

        for (uint256 i = 0; i < 10; i++) {
            staking.stake(1, 1000e18, other);
        }

        vm.warp(53 weeks);
        changePrank(other);
        bytes4 selector = bytes4(keccak256("PoolRefModeIsNotTimeBased()"));
        vm.expectRevert(abi.encodeWithSelector(selector));
        staking.claimRewardForRef(1, user2);
    }

    // LP is true, testing:
    function testStakeAndClaimByUser2AfterStakingDurationLpTrue() external {
        vm.startPrank(user1);

        deal(user1, 100 ether);

        deal(address(deXa), user2, 1000e18);

        IERC20(address(busd)).approve(address(staking), type(uint256).max);

        ICentherStaking.PoolCreationInputs memory _info = ICentherStaking.PoolCreationInputs(
            "project",
            block.timestamp,
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
            0,
            "www.staking.com/1",
            true,
            true,
            true
        );

        staking.createPool{value: 0.00001 ether}(_info);

        ICentherStaking.AffiliateSettingInput memory _setting = ICentherStaking.AffiliateSettingInput({
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

        (, uint256 stakedAmount,,,) = staking.userStakes(1, user2, 0);

        assert(stakedAmount == 100e18);

        vm.warp(108 weeks); // After 2 years, but amount get according to 1 yaer

        staking.claimReward(1);

        assert(busd.balanceOf(user2) == 20277777777777777777);
    }

    function testStakeAndClaimByUser2AfterFirstRewardLpTrue() external {
        vm.startPrank(user1);

        deal(user1, 100 ether);

        deal(address(deXa), user2, 1000e18);

        IERC20(address(busd)).approve(address(staking), type(uint256).max);

        ICentherStaking.PoolCreationInputs memory _info = ICentherStaking.PoolCreationInputs(
            "project",
            block.timestamp,
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
            0,
            "www.staking.com/1",
            true,
            true,
            true
        );

        staking.createPool{value: 0.00001 ether}(_info);

        ICentherStaking.AffiliateSettingInput memory _setting = ICentherStaking.AffiliateSettingInput({
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

        (, uint256 stakedAmount,,,) = staking.userStakes(1, user2, 0);

        assert(stakedAmount == 100e18);

        vm.warp(1.1 weeks); // After 2 years, but amount get according to 1 yaer

        staking.claimReward(1);

        assert(busd.balanceOf(user2) == 388888888888888888);
    }

    function testStakeAndClaimByUser2BeforeFirstRewardLpTrue() external {
        vm.startPrank(user1);

        deal(user1, 100 ether);

        deal(address(deXa), user2, 1000e18);

        IERC20(address(busd)).approve(address(staking), type(uint256).max);

        ICentherStaking.PoolCreationInputs memory _info = ICentherStaking.PoolCreationInputs(
            "project",
            block.timestamp,
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
            0,
            "www.staking.com/1",
            true,
            true,
            true
        );

        staking.createPool{value: 0.00001 ether}(_info);

        ICentherStaking.AffiliateSettingInput memory _setting = ICentherStaking.AffiliateSettingInput({
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

        (, uint256 stakedAmount,,,) = staking.userStakes(1, user2, 0);

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

        ICentherStaking.PoolCreationInputs memory _info = ICentherStaking.PoolCreationInputs(
            "project",
            block.timestamp,
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
            0,
            "www.staking.com/1",
            true,
            true,
            true
        );

        staking.createPool{value: 0.00001 ether}(_info);

        ICentherStaking.AffiliateSettingInput memory _setting = ICentherStaking.AffiliateSettingInput({
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

        (, uint256 stakedAmount,,,) = staking.userStakes(1, user2, 0);

        assert(stakedAmount == 100e18);

        vm.warp(13 days);

        staking.claimReward(1);

        vm.warp(20 days);

        staking.claimReward(1);

        // assert(busd.balanceOf(user2) == 604394968457468457 + 384615384615384615);
    }

    // LP is false, testing:
    function testStakeAndClaimByUser2AfterStakingDurationLpFalse() external {
        vm.startPrank(user1);

        deal(user1, 100 ether);

        deal(address(deXa), user2, 1000e18);

        IERC20(address(busd)).approve(address(staking), type(uint256).max);

        IERC20(address(deXa)).approve(address(staking), type(uint256).max);

        ICentherStaking.PoolCreationInputs memory _info = ICentherStaking.PoolCreationInputs(
            "project",
            block.timestamp,
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
            0,
            "www.staking.com/1",
            true,
            false,
            true
        );

        staking.createPool{value: 0.00001 ether}(_info);

        ICentherStaking.AffiliateSettingInput memory _setting = ICentherStaking.AffiliateSettingInput({
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

        (, uint256 stakedAmount,,,) = staking.userStakes(1, user2, 0);

        assert(stakedAmount == 100e18);

        vm.warp(108 weeks); // After 2 years, but amount get according to 1 yaer

        console2.log("user2 bal: ", busd.balanceOf(user2));
        staking.claimReward(1);

        assert(busd.balanceOf(user2) == 20277777777777777777);
    }

    function testStakeAndClaimByUser2AfterFirstRewardLpFalse() external {
        vm.startPrank(user1);

        deal(user1, 100 ether);

        deal(address(deXa), user2, 1000e18);

        IERC20(address(busd)).approve(address(staking), type(uint256).max);

        IERC20(address(deXa)).approve(address(staking), type(uint256).max);

        ICentherStaking.PoolCreationInputs memory _info = ICentherStaking.PoolCreationInputs(
            "project",
            block.timestamp,
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
            0,
            "www.staking.com/1",
            true,
            false,
            true
        );

        staking.createPool{value: 0.00001 ether}(_info);

        ICentherStaking.AffiliateSettingInput memory _setting = ICentherStaking.AffiliateSettingInput({
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

        (, uint256 stakedAmount,,,) = staking.userStakes(1, user2, 0);

        assert(stakedAmount == 100e18);

        vm.warp(1.1 weeks); // After 2 years, but amount get according to 1 yaer

        staking.claimReward(1);

        assert(busd.balanceOf(user2) == 388888888888888888);
    }

    function testStakeAndClaimByUser2BeforeFirstRewardLpFalse() external {
        vm.startPrank(user1);

        deal(user1, 100 ether);

        deal(address(deXa), user2, 1000e18);

        IERC20(address(busd)).approve(address(staking), type(uint256).max);

        IERC20(address(deXa)).approve(address(staking), type(uint256).max);

        ICentherStaking.PoolCreationInputs memory _info = ICentherStaking.PoolCreationInputs(
            "project",
            block.timestamp,
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
            0,
            "www.staking.com/1",
            true,
            false,
            true
        );

        staking.createPool{value: 0.00001 ether}(_info);

        ICentherStaking.AffiliateSettingInput memory _setting = ICentherStaking.AffiliateSettingInput({
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

        (, uint256 stakedAmount,,,) = staking.userStakes(1, user2, 0);

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

        IERC20(address(deXa)).approve(address(staking), type(uint256).max);

        ICentherStaking.PoolCreationInputs memory _info = ICentherStaking.PoolCreationInputs(
            "project",
            block.timestamp,
            address(deXa),
            address(busd),
            2000,
            5e18,
            10000e18,
            365 days,
            15 days,
            1,
            30 days,
            10000e18,
            100,
            0,
            "www.staking.com/1",
            true,
            false,
            true
        );

        staking.createPool{value: 0.00001 ether}(_info);

        ICentherStaking.AffiliateSettingInput memory _setting = ICentherStaking.AffiliateSettingInput({
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

        (, uint256 stakedAmount,,,) = staking.userStakes(1, user2, 0);

        assert(stakedAmount == 100e18);

        vm.warp(31 days);

        staking.claimReward(1);

        vm.warp(block.timestamp + 20 days);

        staking.claimReward(1);

        assert(busd.balanceOf(user2) == 1666666666666666666 + 833333333333333333);
    }

    // unstake
    function testAfterStakingDurationUnstakeByUser2UnstakableFalse() external {
        vm.startPrank(user1);

        deal(user1, 100 ether);

        deal(address(deXa), user2, 1000e18);

        IERC20(address(busd)).approve(address(staking), type(uint256).max);

        ICentherStaking.PoolCreationInputs memory _info = ICentherStaking.PoolCreationInputs(
            "project",
            block.timestamp,
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
            0,
            "www.staking.com/1",
            false,
            true,
            true
        );

        staking.createPool{value: 0.00001 ether}(_info);

        ICentherStaking.AffiliateSettingInput memory _setting = ICentherStaking.AffiliateSettingInput({
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

        (, uint256 stakedAmount,,,) = staking.userStakes(1, user2, 0);

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

        ICentherStaking.PoolCreationInputs memory _info = ICentherStaking.PoolCreationInputs(
            "project",
            block.timestamp,
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
            0,
            "www.staking.com/1",
            false,
            true,
            true
        );

        staking.createPool{value: 0.00001 ether}(_info);

        ICentherStaking.AffiliateSettingInput memory _setting = ICentherStaking.AffiliateSettingInput({
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

        (, uint256 stakedAmount,,,) = staking.userStakes(1, user2, 0);

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

        ICentherStaking.PoolCreationInputs memory _info = ICentherStaking.PoolCreationInputs(
            "project",
            block.timestamp,
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
            0,
            "www.staking.com/1",
            true,
            true,
            true
        );

        staking.createPool{value: 0.00001 ether}(_info);

        ICentherStaking.AffiliateSettingInput memory _setting = ICentherStaking.AffiliateSettingInput({
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

        (, uint256 stakedAmount,,,) = staking.userStakes(1, user2, 0);

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

        ICentherStaking.PoolCreationInputs memory _info = ICentherStaking.PoolCreationInputs(
            "project",
            block.timestamp,
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
            0,
            "www.staking.com/1",
            true,
            true,
            true
        );

        staking.createPool{value: 0.00001 ether}(_info);

        ICentherStaking.AffiliateSettingInput memory _setting = ICentherStaking.AffiliateSettingInput({
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

        (, uint256 stakedAmount,,,) = staking.userStakes(1, user2, 0);

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

        ICentherStaking.PoolCreationInputs memory _info = ICentherStaking.PoolCreationInputs(
            "project",
            block.timestamp,
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
            0,
            "www.staking.com/1",
            true,
            false,
            true
        );

        staking.createPool{value: 0.00001 ether}(_info);

        ICentherStaking.AffiliateSettingInput memory _setting = ICentherStaking.AffiliateSettingInput({
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

        (, uint256 stakedAmount,,,) = staking.userStakes(1, user2, 0);

        assert(stakedAmount == 1000e18);

        vm.warp(51 weeks);

        staking.unstake(1, 1000e18);

        assert(deXa.balanceOf(user2) == 990000000000000000000);
    }

    function testSameTokensUnstakeByUser2BeforeStakingDurationLpFalse() external {
        vm.startPrank(user1);

        deal(user1, 100 ether);

        deal(address(deXa), user2, 1000e18);

        IERC20(address(deXa)).approve(address(staking), type(uint256).max);

        ICentherStaking.PoolCreationInputs memory _info = ICentherStaking.PoolCreationInputs(
            "project",
            block.timestamp,
            address(deXa),
            address(0),
            200,
            5e18,
            10000e18,
            365 days,
            2,
            1,
            1 weeks,
            10000e18,
            100,
            0,
            "www.staking.com/1",
            true,
            false,
            true
        );

        staking.createPool{value: 0.00001 ether}(_info);

        ICentherStaking.AffiliateSettingInput memory _setting = ICentherStaking.AffiliateSettingInput({
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

        (, uint256 stakedAmount,,,) = staking.userStakes(1, user2, 0);

        assert(stakedAmount == 1000e18);

        vm.warp(51 weeks);

        staking.unstake(1, 1000e18);

        assert(deXa.balanceOf(user2) == 990000000000000000000);
    }

    function testSameTokensUnstakeByUser2BeforeStakingDurationLpTrue() external {
        vm.startPrank(user1);

        deal(user1, 100 ether);

        deal(address(deXa), user1, 1000e18);
        deal(address(deXa), user2, 1000e18);

        IERC20(address(deXa)).approve(address(staking), type(uint256).max);

        ICentherStaking.PoolCreationInputs memory _info = ICentherStaking.PoolCreationInputs(
            "project",
            block.timestamp,
            address(deXa),
            address(0),
            200,
            5e18,
            10000e18,
            365 days,
            2,
            1,
            1 weeks,
            10000e18,
            100,
            0,
            "www.staking.com/1",
            true,
            true,
            true
        );

        staking.createPool{value: 0.00001 ether}(_info);

        ICentherStaking.AffiliateSettingInput memory _setting = ICentherStaking.AffiliateSettingInput({
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

        (, uint256 stakedAmount,,,) = staking.userStakes(1, user2, 0);

        assert(stakedAmount == 1000e18);

        vm.warp(51 weeks);

        staking.unstake(1, 1000e18);

        assert(deXa.balanceOf(user2) == 990000000000000000000);
    }

    function testUserUnstakeBeforeStakingDuration() external {
        vm.startPrank(user1);

        deal(user1, 100 ether);

        deal(address(deXa), user2, 5000e18);

        IERC20(address(busd)).approve(address(staking), type(uint256).max);

        ICentherStaking.PoolCreationInputs memory _info = ICentherStaking.PoolCreationInputs(
            "project",
            block.timestamp,
            address(deXa),
            address(busd),
            200,
            5e18,
            10000e18,
            365 days,
            2,
            2, //time base
            1 weeks,
            10000e18,
            100,
            0,
            "www.staking.com/1",
            true,
            true,
            true
        );

        staking.createPool{value: 0.00001 ether}(_info);

        ICentherStaking.AffiliateSettingInput memory _setting = ICentherStaking.AffiliateSettingInput({
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

        vm.warp(10 days);

        staking.stake(1, 1000e18, address(0));

        changePrank(user1);
        busd.transfer(address(1), busd.balanceOf(user1));

        vm.warp(140 days);

        changePrank(user2);

        staking.unstake(1, 1500e18);

        assert(busd.balanceOf(user1) == 40555555555555555554);
    }

    function testUserUnstakeAfterStakingDuration() external {
        vm.startPrank(user1);

        deal(user1, 100 ether);

        deal(address(deXa), user2, 2000e18);

        IERC20(address(busd)).approve(address(staking), type(uint256).max);

        ICentherStaking.PoolCreationInputs memory _info = ICentherStaking.PoolCreationInputs(
            "project",
            block.timestamp,
            address(deXa),
            address(busd),
            200,
            5e18,
            10000e18,
            365 days,
            2,
            2, //time base
            1 weeks,
            10000e18,
            100,
            0,
            "www.staking.com/1",
            true,
            true,
            true
        );

        staking.createPool{value: 0.00001 ether}(_info);

        ICentherStaking.AffiliateSettingInput memory _setting = ICentherStaking.AffiliateSettingInput({
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

        vm.warp(10 days);

        staking.stake(1, 1000e18, address(0));

        changePrank(user1);
        busd.transfer(address(1), busd.balanceOf(user1));

        vm.warp(380 days);

        changePrank(user2);

        staking.claimReward(1);

        staking.unstake(1, 1500e18);

        assert(deXa.balanceOf(user2) == 1500e18);
    }

    function testClaimRefRewardCaseWithShortDuration() external {
        vm.startPrank(user1);

        deal(user1, 100 ether);

        deal(address(deXa), user1, 10000e18);
        deal(address(deXa), user2, 50000e18);
        deal(address(deXa), other, 10000e18);

        IERC20(address(busd)).approve(address(staking), type(uint256).max);
        IERC20(address(deXa)).approve(address(staking), type(uint256).max);

        ICentherStaking.PoolCreationInputs memory _info = ICentherStaking.PoolCreationInputs(
            "project",
            block.timestamp,
            address(deXa),
            address(0),
            9000,
            5e18,
            50000000e18,
            86400,
            600,
            2,
            600,
            50000000e18,
            500,
            0,
            "www.staking.com/1",
            true,
            true,
            true
        );

        staking.createPool{value: 0.00001 ether}(_info);

        ICentherStaking.AffiliateSettingInput memory _setting = ICentherStaking.AffiliateSettingInput({
            levelOne: 600,
            levelTwo: 500,
            levelThree: 400,
            levelFour: 300,
            levelFive: 200,
            levelSix: 100
        });

        staking.setAffiliateSetting(1, _setting);

        assert(staking.poolIds() == 1);

        changePrank(user2);

        IERC20(address(deXa)).approve(address(staking), type(uint256).max);

        staking.stake(1, 50000e18, address(0));

        // vm.warp(10 minutes);

        changePrank(other);

        IERC20(address(deXa)).approve(address(staking), type(uint256).max);

        staking.stake(1, 10000e18, user2);

        vm.warp(5 weeks);

        changePrank(user2);

        console2.log("Staking:: calculateClaimableRewardForRef: ", staking.calculateClaimableRewardForRef(1, other));

        staking.claimRewardForRef(1, other);

        changePrank(other);

        console2.log("Staking:: calculateClaimableRewardForRef :", staking.calculateClaimableRewardForRef(1, user2));

        staking.claimRewardForRef(1, user2);
    }

    function testBeforeStakingDurationUnstakeRefundRewardToOwnerC1() external {
        vm.startPrank(user1);

        deal(user1, 100 ether);

        deal(address(deXa), user2, 1000e18);

        IERC20(address(busd)).approve(address(staking), type(uint256).max);

        ICentherStaking.PoolCreationInputs memory _info = ICentherStaking.PoolCreationInputs(
            "project",
            block.timestamp,
            address(deXa),
            address(busd),
            200,
            5e18,
            10000e18,
            365 days,
            1 weeks,
            1,
            1 weeks,
            10000e18,
            100,
            0,
            "www.staking.com/1",
            true,
            true,
            true
        );

        staking.createPool{value: 0.00001 ether}(_info);

        ICentherStaking.AffiliateSettingInput memory _setting = ICentherStaking.AffiliateSettingInput({
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

        (, uint256 stakedAmount,,,) = staking.userStakes(1, user2, 0);

        assert(stakedAmount == 1000e18);

        assert(deXa.balanceOf(address(staking)) == 1000e18);
        assert(deXa.balanceOf(user1) == 0);

        vm.warp(5 days);

        staking.claimReward(1);

        staking.unstake(1, 500e18);

        vm.warp(55 weeks);

        staking.claimReward(1);

        staking.unstake(1, 500e18);

        assert(deXa.balanceOf(user2) == 995000000000000000000);
    }

    function testBeforeStakingDurationUnstakeRefundRewardToOwnerC2() external {
        vm.startPrank(user1);

        deal(user1, 100 ether);

        deal(address(deXa), user2, 1000e18);

        IERC20(address(busd)).approve(address(staking), type(uint256).max);

        ICentherStaking.PoolCreationInputs memory _info = ICentherStaking.PoolCreationInputs(
            "project",
            block.timestamp,
            address(deXa),
            address(busd),
            5000,
            5e18,
            10000e18,
            365 days,
            1 weeks,
            1,
            1 weeks,
            10000e18,
            100,
            0,
            "www.staking.com/1",
            true,
            true,
            true
        );

        staking.createPool{value: 0.00001 ether}(_info);

        ICentherStaking.AffiliateSettingInput memory _setting = ICentherStaking.AffiliateSettingInput({
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

        (, uint256 stakedAmount,,,) = staking.userStakes(1, user2, 0);

        assert(stakedAmount == 1000e18);

        assert(deXa.balanceOf(address(staking)) == 1000e18);
        assert(deXa.balanceOf(user1) == 0);

        (uint256 totalReward,,,) = staking.calculateTotalReward(1, user2);
        console2.log("totalReward : ", totalReward);

        vm.warp(3 * 2620800);

        staking.claimReward(1);

        vm.warp(3 * 2620800);

        staking.unstake(1, 500e18);

        vm.warp(55 weeks);
        staking.claimReward(1);
        staking.unstake(1, 500e18);
    }

    function testProsperaCase() external {
        vm.startPrank(user1);

        deal(user1, 100 ether);

        deal(address(deXa), user2, 1000e18);

        IERC20(address(deXa)).approve(address(staking), type(uint256).max);

        ICentherStaking.PoolCreationInputs memory _info = ICentherStaking.PoolCreationInputs(
            "Prospera",
            block.timestamp,
            address(deXa),
            address(0),
            4500,
            500000000000000000000,
            0,
            47088000,
            2592000,
            2,
            2592000,
            0,
            0,
            0,
            "ipfs:QmQh3rBJRAhehb2w56hQQHXwWvcCFrdBiuSKSxjXYYkwkh/centher/6c1bbf30-45bc-11ee-b3f1-b769a1ba9d46.json",
            false,
            false,
            true
        );

        staking.createPool{value: 0.00001 ether}(_info);

        ICentherStaking.AffiliateSettingInput memory _setting = ICentherStaking.AffiliateSettingInput({
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

        (, uint256 stakedAmount,,,) = staking.userStakes(1, user2, 0);

        assert(stakedAmount == 1000e18);
    }

    // test:: restake
    function testRestakeFeature() external {
        vm.startPrank(user1);

        deal(user1, 100 ether);

        deal(address(deXa), user1, 10000e18);
        deal(address(deXa), user2, 10000e18);

        IERC20(address(busd)).approve(address(staking), type(uint256).max);
        IERC20(address(deXa)).approve(address(staking), type(uint256).max);

        ICentherStaking.PoolCreationInputs memory _info = ICentherStaking.PoolCreationInputs(
            "project",
            block.timestamp,
            address(deXa),
            address(0),
            200,
            5e18,
            10000e18,
            365 days,
            2,
            1,
            1 weeks,
            10000e18,
            100,
            0,
            "www.staking.com/1",
            true,
            true,
            true
        );

        staking.createPool{value: 0.00001 ether}(_info);

        ICentherStaking.AffiliateSettingInput memory _setting = ICentherStaking.AffiliateSettingInput({
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

        staking.stake(1, 1000e18, other);

        vm.warp(156 days);

        staking.restake(1);

        (,,, uint256 totalStakeAmount) = staking.calculateTotalReward(1, user2);

        staking.unstake(1, totalStakeAmount);
    }

    function testGetClaimableWindow() external {
        vm.startPrank(user1);

        deal(user1, 100 ether);

        deal(address(deXa), user1, 10000e18);
        deal(address(deXa), user2, 10000e18);

        IERC20(address(busd)).approve(address(staking), type(uint256).max);
        IERC20(address(deXa)).approve(address(staking), type(uint256).max);

        ICentherStaking.PoolCreationInputs memory _info = ICentherStaking.PoolCreationInputs(
            "project",
            block.timestamp,
            address(deXa),
            address(busd),
            200,
            5e18,
            10000e18,
            365 days,
            30 days,
            2,
            7 days,
            10000e18,
            100,
            0,
            "www.staking.com/1",
            true,
            true,
            true
        );

        staking.createPool{value: 0.00001 ether}(_info);

        ICentherStaking.AffiliateSettingInput memory _setting = ICentherStaking.AffiliateSettingInput({
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

        staking.stake(1, 1000e18, other);

        vm.warp(100 days);

        changePrank(other);
        staking.claimRewardForRef(1, user2);
    }

    function testFuzzUnstakeByUsersAfterStakingDuration(uint256 _stakeAmount) external {
        vm.assume(_stakeAmount > 5e18);
        vm.assume(_stakeAmount < 4994500e18);

        vm.startPrank(user1);

        deal(user1, 100 ether);

        deal(address(deXa), user2, _stakeAmount);
        deal(address(deXa), other, _stakeAmount);

        IERC20(address(busd)).approve(address(staking), type(uint256).max);
        console2.log("time before pool creation", block.timestamp);

        ICentherStaking.PoolCreationInputs memory _info = ICentherStaking.PoolCreationInputs(
            "project",
            block.timestamp,
            address(deXa),
            address(busd),
            200,
            5e18,
            _stakeAmount + 1,
            365 days,
            2,
            1,
            4 weeks,
            _stakeAmount + 1,
            100,
            0,
            "www.staking.com/1",
            false,
            true,
            true
        );

        staking.createPool{value: 0.00001 ether}(_info);

        ICentherStaking.AffiliateSettingInput memory _setting = ICentherStaking.AffiliateSettingInput({
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

        vm.warp(block.timestamp + 100);
        staking.stake(1, _stakeAmount, address(0));

        vm.warp(block.timestamp + 4 weeks);

        changePrank(other);

        IERC20(address(deXa)).approve(address(staking), type(uint256).max);

        staking.stake(1, _stakeAmount, user2);

        changePrank(user2);

        vm.warp(block.timestamp + 53 weeks);
        staking.unstake(1, _stakeAmount);

        changePrank(other);

        vm.warp(block.timestamp + 4 weeks);
        staking.unstake(1, _stakeAmount);

        assert(deXa.balanceOf(user2) == _stakeAmount);
        assert(deXa.balanceOf(other) == _stakeAmount);

        changePrank(user2);
        staking.claimReward(1);

        changePrank(other);
        staking.claimReward(1);
    }

    // function testCreateAllowanceFeature() external {
    //     vm.startPrank(user1);

    //     deal(user1, 100 ether);

    //     deal(address(deXa), user2, 1000e18);

    //     IERC20(address(deXa)).approve(address(staking), type(uint256).max);

    //     ICentherStaking.PoolCreationInputs memory _info = ICentherStaking.PoolCreationInputs(
    //         "project",
    //         block.timestamp,
    //         address(deXa),
    //         address(0),
    //         5000,
    //         5e18,
    //         10000e18,
    //         365 days,
    //         1 weeks,
    //         1,
    //         1 weeks,
    //         10000e18,
    //         100,
    //         0,
    //         "www.staking.com/1",
    //         true,
    //         false,
    //         true
    //     );

    //     staking.createPool{value: 0.00001 ether}(_info);

    //     ICentherStaking.AffiliateSettingInput memory _setting = ICentherStaking.AffiliateSettingInput({
    //         levelOne: 600,
    //         levelTwo: 400,
    //         levelThree: 200,
    //         levelFour: 200,
    //         levelFive: 200,
    //         levelSix: 200
    //     });

    //     staking.setAffiliateSetting(1, _setting);

    //     assert(staking.poolIds() == 1);

    //     changePrank(user2);

    //     IERC20(address(deXa)).approve(address(staking), type(uint256).max);

    //     staking.stake(1, 1000e18, address(0));

    //     (, uint256 stakedAmount,,,) = staking.userStakes(1, user2, 0);

    //     assert(stakedAmount == 1000e18);

    //     changePrank(owner);

    //     IERC20(address(ntr)).approve(address(staking), type(uint256).max);

    //     ICentherStaking.PoolCreationInputs memory _info2 = ICentherStaking.PoolCreationInputs(
    //         "project",
    //         block.timestamp,
    //         address(ntr),
    //         address(0),
    //         5000,
    //         5e18,
    //         10000e18,
    //         365 days,
    //         1 weeks,
    //         1,
    //         1 weeks,
    //         10000e18,
    //         100,
    //         0,
    //         "www.staking.com/1",
    //         true,
    //         false,
    //         true
    //     );

    //     staking.createPool{value: 0.00001 ether}(_info2);

    //     staking.setAffiliateSetting(2, _setting);

    //     staking.createAllowence(1, 2, 1000e18, user2, address(0));

    //     changePrank(user2);

    //     staking.unstake(2, 1000e18);

    //     assertEq(ntr.balanceOf(user2), 990000000000000000000);
    // }

    // function testShouldFailOwnerNotRegistered() external {
    //     vm.startPrank(owner);

    //     deal(owner, 100 ether);

    //     IERC20(address(busd)).approve(address(staking), type(uint256).max);

    //     ICentherStaking.PoolCreationInputs memory _info = ICentherStaking.PoolCreationInputs(
    //         "project",
    //         block.timestamp,
    //         address(deXa),
    //         address(busd),
    //         200,
    //         5e18,
    //         10000e18,
    //         365 days,
    //         2,
    //         1,
    //         1 weeks,
    //         10000e18,
    //         100,
    //         0,
    //         "www.staking.com/1",
    //         true,
    //         true,
    //         true
    //     );

    //     bytes4 selector = bytes4(keccak256("NotRegistered()"));
    //     vm.expectRevert(abi.encodeWithSelector(selector));

    //     staking.createPool{value: 0.00001 ether}(_info);
    // }
}
