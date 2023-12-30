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

        uint256[] memory _data = new uint256[](10);
        _data[0] = 0;
        _data[1] = 1;
        _data[2] = 2;
        _data[3] = 3;
        _data[4] = 4;
        _data[5] = 5;
        _data[6] = 6;
        _data[7] = 7;
        _data[8] = 8;
        _data[9] = 9;

        for (uint256 i = 0; i < 10; i++) {
            staking.unstake(1, _data);
        }

        for (uint256 i = 0; i < 10; i++) {
            (, uint256 stakedAmount,,,) = staking.userStakes(1, user2, i);
            assert(stakedAmount == 0);
        }
        assert(deXa.balanceOf(user2) == 10000e18);
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

        vm.warp(53 weeks);
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

        staking.claimReward(1);

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

        staking.claimReward(1);

        uint256[] memory _data = new uint256[](1);
        _data[0] = 0;

        bytes4 selector = bytes4(keccak256("NonRefundable()"));
        vm.expectRevert(abi.encodeWithSelector(selector));

        staking.unstake(1, _data);

    }
}
