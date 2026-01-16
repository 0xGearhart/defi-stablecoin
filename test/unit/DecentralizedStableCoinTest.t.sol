// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {CodeConstants} from "../../script/HelperConfig.s.sol";
import {DecentralizedStableCoin, Ownable} from "../../src/DecentralizedStableCoin.sol";
import {Test} from "forge-std/Test.sol";

contract DecentralizedStableCoinTest is Test, CodeConstants {
    DecentralizedStableCoin public dsc;
    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");
    address public owner;
    uint256 public startingUserBalance = 10 ether;

    function setUp() external {
        dsc = new DecentralizedStableCoin(DSC_NAME, DSC_SYMBOL);
        owner = address(this);
        vm.deal(user1, startingUserBalance);
        vm.deal(user2, startingUserBalance);
    }

    /*//////////////////////////////////////////////////////////////
                                  MINT
    //////////////////////////////////////////////////////////////*/

    function testMintFailsWhenCalledByAnyoneOtherThanOwner() external {
        uint256 amount = 1000;
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(user1)));
        dsc.mint(user1, amount);
    }

    function testMintFailsWhenToAddressIsZeroAddress() external {
        uint256 amount = 1000;
        vm.prank(owner);
        vm.expectRevert(DecentralizedStableCoin.DecentralizedStableCoin__NotZeroAddress.selector);
        dsc.mint(address(0), amount);
    }

    function testMintFailsWhenAmountIsZero() external {
        uint256 amount = 0;
        vm.prank(owner);
        vm.expectRevert(DecentralizedStableCoin.DecentralizedStableCoin__AmountMustBeMoreThanZero.selector);
        dsc.mint(owner, amount);
    }

    function testMintSucceedsWhenCalledByOwner() external {
        uint256 amount = 1000;
        vm.prank(owner);
        bool success = dsc.mint(user1, amount);
        assert(success);
        assertEq(dsc.balanceOf(user1), amount);
    }

    modifier minted() {
        uint256 amount = 1000;
        vm.prank(owner);
        bool success = dsc.mint(owner, amount);
        assert(success);
        _;
    }

    /*//////////////////////////////////////////////////////////////
                                  BURN
    //////////////////////////////////////////////////////////////*/

    function testBurnFailsWhenCalledByAnyoneOtherThanOwner() external {
        uint256 amount = 1000;
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(user1)));
        dsc.burn(amount);
    }

    function testBurnFailsWhenAmountIsZero() external {
        uint256 amount = 0;
        vm.prank(owner);
        vm.expectRevert(DecentralizedStableCoin.DecentralizedStableCoin__AmountMustBeMoreThanZero.selector);
        dsc.burn(amount);
    }

    function testBurnFailsWhenAmountIsGreaterThanBalance() external minted {
        uint256 amount = 1001;
        vm.prank(owner);
        vm.expectRevert(DecentralizedStableCoin.DecentralizedStableCoin__BurnAmountExceedsBalance.selector);
        dsc.burn(amount);
    }

    function testBurnSucceedsWhenCalledByOwner() external minted {
        uint256 amount = 1000;
        assertEq(dsc.balanceOf(owner), amount);
        vm.prank(owner);
        dsc.burn(amount);
        assertEq(dsc.balanceOf(owner), 0);
    }
}
