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
    address payable public other2;

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
        other2 = payable(vm.addr(5));

        console2.log(" ---- owner ----", owner);
        console2.log(" ---- user1 ----", user1);
        console2.log(" ---- user2 ----", user2);
        console2.log(" ---- other ----", other);
        console2.log(" ---- other2 ----", other2);

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

        address[] memory _users = new address[](4);
        _users[0] = address(user1);
        _users[1] = address(user2);
        _users[2] = address(other);
        _users[3] = address(other2);

        address[] memory _refs = new address[](4);
        _refs[0] = address(owner);
        _refs[1] = address(user1);
        _refs[2] = address(user2);
        _refs[3] = address(other);

        register.registerForOwnerBatch(_users, _refs);

        staking = new CentherStaking(address(register), owner);
    }

    function testDeployments() external view {
        console2.log("centher registration: ", address(register));
        console2.log("centher staking: ", address(staking));
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
            true,
            0
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

        uint256[] memory stakeIds = new uint256[](10);
        stakeIds[0] = 0;
        stakeIds[1] = 1;
        stakeIds[2] = 2;
        stakeIds[3] = 3;
        stakeIds[4] = 4;
        stakeIds[5] = 5;
        stakeIds[6] = 6;
        stakeIds[7] = 7;
        stakeIds[8] = 8;
        stakeIds[9] = 9;

        staking.claimReward(1, stakeIds);

        uint256[] memory _data = new uint256[](5);
        _data[0] = 0;
        _data[1] = 1;
        _data[2] = 2;
        _data[3] = 3;
        _data[4] = 4;
        // _data[5] = 5;
        // _data[6] = 6;
        // _data[7] = 7;
        // _data[8] = 8;
        // _data[9] = 9;

        // for (uint256 i = 0; i < 10; i++) {
        staking.unstake(1, _data);
        // }

        // for (uint256 i = 0; i < 10; i++) {
        //     (, uint256 stakedAmount,,,) = staking.userStakes(1, user2, i);
        //     assert(stakedAmount == 0);
        // }
        // assert(deXa.balanceOf(user2) == 5000e18);
    }

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
            true,
            0
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

        vm.warp(59 weeks);

        uint256[] memory stakeIds = new uint256[](1);
        stakeIds[0] = 0;
        staking.claimReward(1, stakeIds);

        uint256[] memory _data = new uint256[](1);
        _data[0] = 0;
        staking.unstake(1, _data);

        assert(deXa.balanceOf(user2) == 1000e18);
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
            true,
            0
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

        uint256[] memory stakeIds = new uint256[](1);
        stakeIds[0] = 0;
        staking.claimReward(1, stakeIds);

        uint256[] memory _data = new uint256[](1);
        _data[0] = 0;
        staking.unstake(1, _data);

        assert(deXa.balanceOf(user2) == 1000e18);
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
            true,
            0
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

        uint256[] memory stakeIds = new uint256[](2);
        stakeIds[0] = 0;
        stakeIds[1] = 1;
        staking.claimReward(1, stakeIds);

        uint256[] memory _data = new uint256[](2);
        _data[0] = 0;
        _data[1] = 1;

        staking.unstake(1, _data);

        assert(deXa.balanceOf(user2) == 2000e18);
    }

    function testShouldFailNonRefundableAndUnstakeByUser2WithTax() external {
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
            true,
            1000
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

        changePrank(owner);

        staking.togglePoolNonRefundable(1, true);

        assert(staking.poolIds() == 1);

        changePrank(user2);

        IERC20(address(deXa)).approve(address(staking), type(uint256).max);

        staking.stake(1, 100e18, address(0));

        (, uint256 stakedAmount,,,) = staking.userStakes(1, user2, 0);

        assert(stakedAmount == 100e18);

        vm.warp(108 weeks); // After 2 years, but amount get according to 1 yaer

        uint256[] memory stakeIds = new uint256[](1);
        stakeIds[0] = 0;
        staking.claimReward(1, stakeIds);

        uint256[] memory _data = new uint256[](1);
        _data[0] = 0;

        bytes4 selector = bytes4(keccak256("NonRefundable()"));
        vm.expectRevert(abi.encodeWithSelector(selector));

        staking.unstake(1, _data);
    }

    //test:: claim reward
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
            true,
            0
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

        uint256[] memory stakeIds = new uint256[](1);
        stakeIds[0] = 0;
        staking.claimReward(1, stakeIds);

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
            2 weeks,
            1,
            1 weeks,
            10000e18,
            100,
            0,
            "www.staking.com/1",
            true,
            true,
            true,
            0
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
        bytes4 selector = bytes4(keccak256("AmountIsZero()"));
        vm.expectRevert(abi.encodeWithSelector(selector));
        uint256[] memory stakeIds = new uint256[](1);
        stakeIds[0] = 0;
        staking.claimReward(1, stakeIds);
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
            true,
            0
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
        bytes4 selector = bytes4(keccak256("AmountIsZero()"));
        vm.expectRevert(abi.encodeWithSelector(selector));
        uint256[] memory stakeIds = new uint256[](1);
        stakeIds[0] = 0;
        staking.claimReward(1, stakeIds);

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
            true,
            0
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

        uint256[] memory stakeIds = new uint256[](1);
        stakeIds[0] = 0;
        staking.claimReward(1, stakeIds);

        vm.warp(20 days);

        staking.claimReward(1, stakeIds);

        assert(busd.balanceOf(user2) == 388888888888888888 * 2);
    }

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
            true,
            0
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

        uint256[] memory stakeIds = new uint256[](1);
        stakeIds[0] = 0;
        staking.claimReward(1, stakeIds);

        assert(busd.balanceOf(user2) == 20277777777777777777);
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
            true,
            0
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

        uint256[] memory stakeIds = new uint256[](1);
        stakeIds[0] = 0;
        staking.claimReward(1, stakeIds);

        vm.warp(block.timestamp + 20 days);

        staking.claimReward(1, stakeIds);

        assert(busd.balanceOf(user2) == 1666666666666666666 + 833333333333333333);
    }

    function testClaimsWithMultipleStakes() external {
        vm.startPrank(user1);

        deal(user1, 100 ether);

        deal(address(deXa), user2, 5000e18);

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
            true,
            0
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
        staking.stake(1, 750e18, address(0));

        vm.warp(block.timestamp + 1 weeks);
        staking.stake(1, 750e18, address(0));

        vm.warp(block.timestamp + 1 weeks);
        staking.stake(1, 750e18, address(0));

        vm.warp(block.timestamp + 2 weeks);

        uint256[] memory stakeIds = new uint256[](1);
        stakeIds[0] = 2;
        staking.claimReward(1, stakeIds);

        stakeIds[0] = 0;
        staking.claimReward(1, stakeIds);

        vm.warp(block.timestamp + 2 weeks);

        staking.calculateTotalRewardPerStake(1, user2, 0);

        // all stakes claim reward
        uint256[] memory stakeIds2 = new uint256[](3);
        stakeIds2[0] = 2;
        stakeIds2[1] = 0;
        stakeIds2[2] = 1;

        staking.claimReward(1, stakeIds2);

        bytes4 selector = bytes4(keccak256("AmountIsZero()"));
        vm.expectRevert(abi.encodeWithSelector(selector));
        staking.claimReward(1, stakeIds2);
    }

    function testRestakeFeatureRefRewardsWithTax() external {
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
            30 days,
            1,
            30 days,
            10000e18,
            100,
            0,
            "www.staking.com/1",
            true,
            true,
            true,
            1000
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
        //flush old funds
        deXa.transfer(address(500), deXa.balanceOf(other));

        changePrank(user2);

        IERC20(address(deXa)).approve(address(staking), type(uint256).max);

        staking.stake(1, 1000e18, other);

        vm.warp(156 days);

        uint256[] memory _stakeIds = new uint256[](1);
        _stakeIds[0] = 0;

        staking.restakeByIds(1, _stakeIds);

        assert(deXa.balanceOf(other) == 54450000000000000000);
        assert(deXa.balanceOf(address(1)) == 6049999999999999999);
    }

    function testShouldFailRestakeByRefDuePoolNotSupported() external {
        vm.startPrank(user1);

        deal(user1, 100 ether);

        // deal(address(deXa), user1, 10000e18);

        deal(address(deXa), user2, 10000e18);
        deal(address(deXa), other, 10000e18);
        deal(address(deXa), other2, 10000e18);

        IERC20(address(busd)).approve(address(staking), type(uint256).max);

        ICentherStaking.PoolCreationInputs memory _info = ICentherStaking.PoolCreationInputs(
            "project",
            block.timestamp,
            address(deXa),
            address(busd),
            1000,
            5e18,
            10000e18,
            365 days,
            30 days,
            1,
            30 days,
            10000e18,
            100,
            0,
            "www.staking.com/1",
            true,
            true,
            true,
            1000
        );

        staking.createPool{value: 0.00001 ether}(_info);

        ICentherStaking.AffiliateSettingInput memory _setting = ICentherStaking.AffiliateSettingInput({
            levelOne: 1000,
            levelTwo: 500,
            levelThree: 250,
            levelFour: 0,
            levelFive: 0,
            levelSix: 0
        });

        staking.setAffiliateSetting(1, _setting);

        assert(staking.poolIds() == 1);

        changePrank(other);

        IERC20(address(deXa)).approve(address(staking), type(uint256).max);

        staking.stake(1, 1000e18, address(0));

        changePrank(user2);

        IERC20(address(deXa)).approve(address(staking), type(uint256).max);

        staking.stake(1, 1000e18, other);

        vm.warp(block.timestamp + 45 days);
        changePrank(other);

        changePrank(user2);

        uint256[] memory _stakedIds = new uint256[](1);
        _stakedIds[0] = 0;
        // _stakedIds[1] = 1;

        staking.claimReward(1, _stakedIds);

        vm.warp(block.timestamp + 10 days);

        changePrank(user2);
        bytes4 selector = bytes4(keccak256("AmountIsZero()"));
        vm.expectRevert(abi.encodeWithSelector(selector));
        staking.claimReward(1, _stakedIds);

        vm.warp(block.timestamp + 52 weeks);
        changePrank(other);

        bytes4 selector1 = bytes4(keccak256("PoolNotEligibleForRestake()"));
        vm.expectRevert(abi.encodeWithSelector(selector1));
        staking.restakeByRef(1, user2, address(0));
    }

    function testShouldFailRestakeAndClaim() external {
        vm.startPrank(user1);

        deal(user1, 100 ether);

        deal(address(deXa), user1, 10000e18);
        deal(address(deXa), user2, 100000e18);
        deal(address(deXa), other, 10000e18);
        deal(address(deXa), other2, 10000e18);

        IERC20(address(busd)).approve(address(staking), type(uint256).max);
        IERC20(address(deXa)).approve(address(staking), type(uint256).max);

        ICentherStaking.PoolCreationInputs memory _info = ICentherStaking.PoolCreationInputs(
            "project",
            block.timestamp,
            address(deXa),
            address(0),
            4500,
            500e18,
            0,
            86400,
            600,
            2,
            600,
            0,
            0,
            0,
            "www.staking.com/1",
            false,
            false,
            true,
            100
        );

        staking.createPool{value: 0.00001 ether}(_info);

        ICentherStaking.AffiliateSettingInput memory _setting = ICentherStaking.AffiliateSettingInput({
            levelOne: 1000,
            levelTwo: 500,
            levelThree: 250,
            levelFour: 0,
            levelFive: 0,
            levelSix: 0
        });

        staking.setAffiliateSetting(1, _setting);

        assert(staking.poolIds() == 1);

        changePrank(user2);

        IERC20(address(deXa)).approve(address(staking), type(uint256).max);

        staking.stake(1, 10000e18, other);

        vm.warp(block.timestamp + 2 minutes);

        staking.stake(1, 12000e18, other);

        vm.warp(block.timestamp + 2 minutes);

        staking.stake(1, 14000e18, other);

        vm.warp(block.timestamp + 2 minutes);

        staking.stake(1, 16000e18, other);

        vm.warp(block.timestamp + 2 minutes);

        staking.stake(1, 18000e18, other);

        vm.warp(block.timestamp + 2 minutes);

        staking.stake(1, 20000e18, other);

        staking.userStakes(1, user2, 0);

        vm.warp(block.timestamp + 10 minutes);

        uint256[] memory _stakeIdsForRestake0 = new uint256[](6);
        _stakeIdsForRestake0[0] = 0;
        _stakeIdsForRestake0[1] = 1;
        _stakeIdsForRestake0[2] = 2;
        _stakeIdsForRestake0[3] = 3;
        _stakeIdsForRestake0[4] = 4;
        _stakeIdsForRestake0[5] = 5;

        staking.restakeByIds(1, _stakeIdsForRestake0);

        vm.warp(block.timestamp + 7 minutes);

        staking.restakeByIds(1, _stakeIdsForRestake0);

        vm.warp(block.timestamp + 15 minutes);

        uint256[] memory _stakeIds0 = new uint256[](1);
        _stakeIds0[0] = 0;

        staking.claimReward(1, _stakeIds0);

        uint256[] memory _stakeIds1 = new uint256[](3);
        _stakeIds1[0] = 2;
        _stakeIds1[1] = 3;
        _stakeIds1[2] = 4;

        staking.claimReward(1, _stakeIds1);

        vm.warp(block.timestamp + 86400);

        staking.restakeByIds(1, _stakeIds0);

        vm.warp(block.timestamp + 1 hours);

        uint256[] memory _stakeIds2 = new uint256[](2);
        _stakeIds2[0] = 0;
        _stakeIds2[1] = 1;

        staking.claimReward(1, _stakeIds2);

        staking.unstake(1, _stakeIds2);
    }

    function testBatchClaimRewardForRef() external {
        vm.startPrank(user1);

        deal(user1, 100 ether);

        deal(address(deXa), user2, 1000e18);
        deal(address(deXa), other2, 1000e18);

        IERC20(address(deXa)).approve(address(staking), type(uint256).max);

        ICentherStaking.PoolCreationInputs memory _info = ICentherStaking.PoolCreationInputs(
            "Random Project",
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
            true,
            0
        );

        staking.createPool{value: 0.00001 ether}(_info);

        ICentherStaking.AffiliateSettingInput memory _setting = ICentherStaking.AffiliateSettingInput({
            levelOne: 100,
            levelTwo: 50,
            levelThree: 25,
            levelFour: 0,
            levelFive: 0,
            levelSix: 0
        });

        staking.setAffiliateSetting(1, _setting);

        assert(staking.poolIds() == 1);

        changePrank(user2);

        IERC20(address(deXa)).approve(address(staking), type(uint256).max);

        staking.stake(1, 1000e18, other);

        (, uint256 stakedAmount,,,) = staking.userStakes(1, user2, 0);

        assert(stakedAmount == 1000e18);

        changePrank(other2);

        IERC20(address(deXa)).approve(address(staking), type(uint256).max);

        staking.stake(1, 750e18, other);

        vm.warp(block.timestamp + 31 days);
        changePrank(other);
        address[] memory referrals = new address[](2);
        referrals[0] = user2;
        referrals[1] = other2;
        staking.batchClaimRewardForRef(1, referrals);
    }

    function testBatchClaimRewardForRefAfterStakingDuration() external {
        vm.startPrank(user1);

        deal(user1, 100 ether);

        deal(address(deXa), user2, 1000e18);
        deal(address(deXa), other2, 1000e18);

        IERC20(address(deXa)).approve(address(staking), type(uint256).max);

        ICentherStaking.PoolCreationInputs memory _info = ICentherStaking.PoolCreationInputs(
            "Random Project",
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
            true,
            0
        );

        staking.createPool{value: 0.00001 ether}(_info);

        ICentherStaking.AffiliateSettingInput memory _setting = ICentherStaking.AffiliateSettingInput({
            levelOne: 100,
            levelTwo: 50,
            levelThree: 25,
            levelFour: 0,
            levelFive: 0,
            levelSix: 0
        });

        staking.setAffiliateSetting(1, _setting);

        assert(staking.poolIds() == 1);

        changePrank(user2);

        IERC20(address(deXa)).approve(address(staking), type(uint256).max);

        staking.stake(1, 1000e18, other);

        (, uint256 stakedAmount,,,) = staking.userStakes(1, user2, 0);

        assert(stakedAmount == 1000e18);

        changePrank(other2);

        IERC20(address(deXa)).approve(address(staking), type(uint256).max);

        staking.stake(1, 750e18, other);

        vm.warp(block.timestamp + 54 weeks);
        changePrank(other);
        address[] memory referrals = new address[](2);
        referrals[0] = user2;
        referrals[1] = other2;
        staking.batchClaimRewardForRef(1, referrals);
    }

    function testBatchRestakeForRef() external {
        vm.startPrank(user1);

        deal(user1, 100 ether);

        deal(address(deXa), user2, 1000e18);
        deal(address(deXa), other2, 1000e18);

        IERC20(address(deXa)).approve(address(staking), type(uint256).max);

        ICentherStaking.PoolCreationInputs memory _info = ICentherStaking.PoolCreationInputs(
            "Random Project",
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
            true,
            0
        );

        staking.createPool{value: 0.00001 ether}(_info);

        ICentherStaking.AffiliateSettingInput memory _setting = ICentherStaking.AffiliateSettingInput({
            levelOne: 100,
            levelTwo: 50,
            levelThree: 25,
            levelFour: 0,
            levelFive: 0,
            levelSix: 0
        });

        staking.setAffiliateSetting(1, _setting);

        assert(staking.poolIds() == 1);

        changePrank(user2);

        IERC20(address(deXa)).approve(address(staking), type(uint256).max);

        staking.stake(1, 1000e18, other);

        (, uint256 stakedAmount,,,) = staking.userStakes(1, user2, 0);

        assert(stakedAmount == 1000e18);

        changePrank(other2);

        IERC20(address(deXa)).approve(address(staking), type(uint256).max);

        staking.stake(1, 750e18, other);

        vm.warp(block.timestamp + 31 days);
        changePrank(other);
        address[] memory referrals = new address[](2);
        referrals[0] = user2;
        referrals[1] = other2;
        staking.batchRestakeByRef(1, referrals, other);
    }

    function testBatchRestakeForRefAfterStakingDuration() external {
        vm.startPrank(user1);

        deal(user1, 100 ether);

        deal(address(deXa), user2, 1000e18);
        deal(address(deXa), other2, 1000e18);

        IERC20(address(deXa)).approve(address(staking), type(uint256).max);

        ICentherStaking.PoolCreationInputs memory _info = ICentherStaking.PoolCreationInputs(
            "Random Project",
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
            true,
            0
        );

        staking.createPool{value: 0.00001 ether}(_info);

        ICentherStaking.AffiliateSettingInput memory _setting = ICentherStaking.AffiliateSettingInput({
            levelOne: 100,
            levelTwo: 50,
            levelThree: 25,
            levelFour: 0,
            levelFive: 0,
            levelSix: 0
        });

        staking.setAffiliateSetting(1, _setting);

        assert(staking.poolIds() == 1);

        changePrank(user2);

        IERC20(address(deXa)).approve(address(staking), type(uint256).max);

        staking.stake(1, 1000e18, other);

        (, uint256 stakedAmount,,,) = staking.userStakes(1, user2, 0);

        assert(stakedAmount == 1000e18);

        changePrank(other2);

        IERC20(address(deXa)).approve(address(staking), type(uint256).max);

        staking.stake(1, 750e18, other);

        vm.warp(block.timestamp + 54 weeks);
        changePrank(other);
        address[] memory referrals = new address[](2);
        referrals[0] = user2;
        referrals[1] = other2;
        staking.batchRestakeByRef(1, referrals, other);
    }

    function testPlayClaimRewardWithDifferentTime() external {
        vm.startPrank(user1);

        deal(user1, 100 ether);

        deal(address(deXa), user2, 5000e18);

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
            true,
            0
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
        staking.stake(1, 750e18, address(0));

        vm.warp(block.timestamp + 1 weeks);
        staking.stake(1, 750e18, address(0));

        vm.warp(block.timestamp + 1 weeks);
        staking.stake(1, 750e18, address(0));

        vm.warp(block.timestamp + 2 weeks);

        uint256[] memory stakeIds = new uint256[](1);
        stakeIds[0] = 2;
        staking.claimReward(1, stakeIds);

        stakeIds[0] = 0;
        staking.claimReward(1, stakeIds);

        vm.warp(block.timestamp + 2 weeks);

        staking.calculateTotalRewardPerStake(1, user2, 0);

        // all stakes claim reward
        uint256[] memory stakeIds2 = new uint256[](3);
        stakeIds2[0] = 2;
        stakeIds2[1] = 0;
        stakeIds2[2] = 1;

        staking.claimReward(1, stakeIds2);

        vm.warp(block.timestamp + 3 days);

        bytes4 selector = bytes4(keccak256("AmountIsZero()"));
        vm.expectRevert(abi.encodeWithSelector(selector));
        staking.claimReward(1, stakeIds2);

        vm.warp(block.timestamp + 4 days);
        staking.claimReward(1, stakeIds2);
    }

    function testAutoStakeBeforeStakingDurationEnd() external {
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
            30 days,
            1,
            30 days,
            10000e18,
            100,
            0,
            "www.staking.com/1",
            true,
            true,
            true,
            1000
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
        staking.stake(1, 750e18, other);

        vm.warp(block.timestamp + 4 weeks * 3);

        uint256[] memory _stakesId = new uint256[](1);
        _stakesId[0] = 0;

        changePrank(owner);
        staking.updateExecutor(other2);

        changePrank(other2);
        staking.autoUserRestakeByIds(1, user2, _stakesId);

        (, uint256 stakedAmount0,,,) = staking.userStakes(1, user2, 0);
        // (, uint256 stakedAmount1,,,) = staking.userStakes(1, user2, 1);

        assert(stakedAmount0 == 750e18 + 2.5e18);
    }

    function testAutoStakeAfterStakingDurationEnd() external {
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
            30 days,
            1,
            30 days,
            10000e18,
            100,
            0,
            "www.staking.com/1",
            true,
            true,
            true,
            1000
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
        staking.stake(1, 750e18, other);

        vm.warp(block.timestamp + 4 weeks * 3);

        uint256[] memory _stakesId = new uint256[](1);
        _stakesId[0] = 0;

        changePrank(owner);
        staking.updateExecutor(other2);

        vm.warp(block.timestamp + 4 weeks * 51);

        changePrank(other2);
        staking.autoUserRestakeByIds(1, user2, _stakesId);

        (, uint256 stakedAmount0,,,) = staking.userStakes(1, user2, 0);
        (, uint256 stakedAmount1,,,) = staking.userStakes(1, user2, 1);

        assert(stakedAmount0 + stakedAmount1 == 750e18 + 15.208333333333333333 ether);
    }

    function testShouldFailAutoStakeDueToStakerNotExist() external {
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
            30 days,
            1,
            30 days,
            10000e18,
            100,
            0,
            "www.staking.com/1",
            true,
            true,
            true,
            1000
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

        uint256[] memory _stakesId = new uint256[](1);
        _stakesId[0] = 0;

        changePrank(owner);
        staking.updateExecutor(other2);

        changePrank(other2);

        bytes4 selector = bytes4(keccak256("UserStakesNotFound()"));
        vm.expectRevert(abi.encodeWithSelector(selector));
        staking.autoUserRestakeByIds(1, user2, _stakesId);
    }

    function testShouldFailAutoStakeDuePoolNotEligible() external {
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
            1,
            30 days,
            10000e18,
            100,
            0,
            "www.staking.com/1",
            true,
            true,
            true,
            1000
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
        staking.stake(1, 750e18, other);

        vm.warp(block.timestamp + 4 weeks * 3);

        uint256[] memory _stakesId = new uint256[](1);
        _stakesId[0] = 0;

        changePrank(owner);
        staking.updateExecutor(other2);

        changePrank(other2);
        bytes4 selector = bytes4(keccak256("PoolNotEligibleForRestake()"));
        vm.expectRevert(abi.encodeWithSelector(selector));
        staking.autoUserRestakeByIds(1, user2, _stakesId);
    }

    function testShouldFailAutoStakeDuePoolNotActive() external {
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
            30 days,
            1,
            30 days,
            10000e18,
            100,
            0,
            "www.staking.com/1",
            true,
            true,
            true,
            1000
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
        staking.stake(1, 750e18, other);

        vm.warp(block.timestamp + 4 weeks * 3);

        uint256[] memory _stakesId = new uint256[](1);
        _stakesId[0] = 0;

        changePrank(owner);
        staking.updateExecutor(other2);

        changePrank(user1);
        staking.togglePoolState(1, false);

        changePrank(other2);
        bytes4 selector = bytes4(keccak256("PoolNotActive()"));
        vm.expectRevert(abi.encodeWithSelector(selector));
        staking.autoUserRestakeByIds(1, user2, _stakesId);
    }

    function testShouldFailAutoStakeDueToInvalidStake() external {
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
            30 days,
            1,
            30 days,
            10000e18,
            100,
            0,
            "www.staking.com/1",
            true,
            true,
            true,
            1000
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
        staking.stake(1, 750e18, other);

        vm.warp(block.timestamp + 4 weeks * 3);

        uint256[] memory _stakesId = new uint256[](1);
        _stakesId[0] = 0;

        staking.claimReward(1, _stakesId);

        changePrank(owner);
        staking.updateExecutor(other2);

        changePrank(other2);
        bytes4 selector = bytes4(keccak256("InvalidStakeAmount()"));
        vm.expectRevert(abi.encodeWithSelector(selector));
        staking.autoUserRestakeByIds(1, user2, _stakesId);
    }
}
