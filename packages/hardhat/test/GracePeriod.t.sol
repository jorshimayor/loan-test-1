// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../contracts/Corn.sol";
import "../contracts/CornDEX.sol";
import "../contracts/Lending.sol";
import "../contracts/MovePrice.sol";
import "../contracts/FlashLoanLiquidator.sol";

contract GracePeriodTest is Test {
    Corn private corn;
    CornDEX private cornDEX;
    Lending private lending;
    MovePrice private movePrice;
    FlashLoanLiquidator private flashLoanLiquidator;

    address private owner;
    address private user;
    address private liquidator;

    uint256 private constant COLLATERAL_AMOUNT = 10 ether;
    uint256 private constant BORROW_AMOUNT = 5000 ether;

    function setUp() public {
        owner = address(this);
        user = makeAddr("user");
        liquidator = makeAddr("liquidator");

        corn = new Corn();
        cornDEX = new CornDEX(address(corn));

        corn.mintTo(owner, 1_000_000 ether);
        corn.approve(address(cornDEX), 1_000_000 ether);
        cornDEX.init{ value: 1000 ether }(1_000_000 ether);

        lending = new Lending(address(cornDEX), address(corn));
        corn.mintTo(address(lending), 10_000_000 ether);

        movePrice = new MovePrice(address(cornDEX), address(corn), address(lending));
        vm.deal(address(movePrice), 1000 ether);

        corn.transferOwnership(address(lending));

        flashLoanLiquidator = new FlashLoanLiquidator(address(lending), address(cornDEX), address(corn));

        vm.deal(user, 10_000 ether);
        vm.deal(liquidator, 10_000 ether);
    }

    function _openPosition() internal {
        vm.prank(user);
        lending.addCollateral{ value: COLLATERAL_AMOUNT }();

        vm.prank(user);
        lending.borrowCorn(BORROW_AMOUNT);

        vm.prank(user);
        corn.transfer(liquidator, BORROW_AMOUNT);

        vm.prank(liquidator);
        corn.approve(address(lending), BORROW_AMOUNT);
    }

    function testFlashLoanLiquidatorBlockedThenAllowed() public {
        _openPosition();

        movePrice.movePriceAndUpdateRisk(int256(300 ether), user);
        assertTrue(lending.isLiquidatable(user));

        uint256 protectionEndsAt = lending.s_atRiskSince(user) + 24 hours;

        vm.prank(liquidator);
        vm.expectRevert(abi.encodeWithSelector(Lending__GracePeriodActive.selector, protectionEndsAt));
        lending.flashLoan(IFlashLoanRecipient(address(flashLoanLiquidator)), BORROW_AMOUNT, user);

        vm.warp(block.timestamp + 25 hours);

        vm.prank(liquidator);
        lending.flashLoan(IFlashLoanRecipient(address(flashLoanLiquidator)), BORROW_AMOUNT, user);

        assertEq(lending.s_userBorrowed(user), 0);
    }

    function testGracePeriodResetsWhenRecovered() public {
        _openPosition();

        movePrice.movePriceAndUpdateRisk(int256(300 ether), user);
        assertTrue(lending.isLiquidatable(user));
        assertGt(lending.s_atRiskSince(user), 0);

        vm.prank(user);
        lending.addCollateral{ value: 1000 ether }();

        assertFalse(lending.isLiquidatable(user));
        assertEq(lending.s_atRiskSince(user), 0);
    }
}
