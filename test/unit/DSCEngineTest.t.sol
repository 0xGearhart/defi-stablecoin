// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {CodeConstants, HelperConfig} from "../../script/HelperConfig.s.sol";
import {DSCEngine, OracleLib} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {Test} from "forge-std/Test.sol";

contract DSCEngineTest is Test, CodeConstants {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    // DSCEngine events
    event CollateralDeposited(address indexed user, address indexed token, uint256 indexed amount);
    event CollateralRedeemed(
        address indexed redeemedFrom, address indexed redeemedTo, address indexed token, uint256 amount
    );
    // DSC events
    event Transfer(address indexed from, address indexed to, uint256 value);

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");
    address user3 = makeAddr("user3");

    uint256 public constant STARTING_USER_BALANCE = 20 ether;
    uint256 public constant STARTING_ERC20_BALANCE = 10 ether;
    uint256 private constant LIQUIDATION_THRESHOLD = 50; // 200% overcollateralized
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant LIQUIDATION_BONUS = 10;
    uint256 private constant MIN_HEALTH_FACTOR = 1e18;
    uint256 private constant ADDITIONAL_PRICE_FEED_PRECISION = 1e10;
    uint256 private constant PRECISION = 1e18;

    uint256 public constant COLLATERAL_AMOUNT = 10 ether;
    uint256 public constant DSC_MINT_AMOUNT = 100 ether;
    uint256 public constant DSC_BURN_AMOUNT = 75 ether;
    uint256 public constant INVALID_DSC_MINT_AMOUNT = 50_000 ether;

    DecentralizedStableCoin public dsc;
    HelperConfig public helperConfig;
    DeployDSC public deployer;
    DSCEngine public dscEngine;
    ERC20Mock public weth;
    ERC20Mock public wbtc;
    address public ethUsdPriceFeed;
    address public btcUsdPriceFeed;
    address public wethAddress;
    address public wbtcAddress;
    address public account;

    address[] public invalidPriceFeedAddresses;
    address[] public invalidTokenAddresses;

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    // skip certain tests if not on local chain
    modifier skipFork() {
        if (block.chainid != LOCAL_CHAIN_ID) {
            return;
        }
        _;
    }

    // fund users with starting balances of WETH and WBTC
    modifier usersFunded() {
        // mainnet wbtc does not work with testing suite
        if (block.chainid != ETH_MAINNET_CHAIN_ID) {
            wbtc.mint(user1, STARTING_ERC20_BALANCE);
            wbtc.mint(user2, STARTING_ERC20_BALANCE);
            wbtc.mint(user3, STARTING_ERC20_BALANCE);
        }
        // can just use mint function on weth mock ERC20 if we are on local chain
        if (block.chainid == LOCAL_CHAIN_ID) {
            weth.mint(user1, STARTING_ERC20_BALANCE);
            weth.mint(user2, STARTING_ERC20_BALANCE);
            weth.mint(user3, STARTING_ERC20_BALANCE);
        } else {
            // testnet & mainnet weth contract has no mint function and a different ABI
            // so we have to use low level calls to encode the deposit selector
            // eth has to be deposited to receive weth
            vm.prank(user1);
            (bool user1Success,) = wethAddress.call{value: STARTING_ERC20_BALANCE}(abi.encodeWithSignature("deposit()"));
            vm.prank(user2);
            (bool user2Success,) = wethAddress.call{value: STARTING_ERC20_BALANCE}(abi.encodeWithSignature("deposit()"));
            vm.prank(user3);
            (bool user3Success,) = wethAddress.call{value: STARTING_ERC20_BALANCE}(abi.encodeWithSignature("deposit()"));
        }
        _;
    }

    modifier usersDeposited() {
        // approve and deposit weth
        vm.startPrank(user1);
        weth.approve(address(dscEngine), COLLATERAL_AMOUNT);
        dscEngine.depositCollateral(wethAddress, COLLATERAL_AMOUNT);
        vm.stopPrank();
        vm.startPrank(user2);
        weth.approve(address(dscEngine), COLLATERAL_AMOUNT);
        dscEngine.depositCollateral(wethAddress, COLLATERAL_AMOUNT);
        vm.stopPrank();

        // // wbtc on mainnet does not work with testing suite
        // if (block.chainid != ETH_MAINNET_CHAIN_ID) {
        //     // approve and deposit wbtc
        //     vm.startPrank(user1);
        //     wbtc.approve(address(dscEngine), COLLATERAL_AMOUNT);
        //     dscEngine.depositCollateral(wbtcAddress, COLLATERAL_AMOUNT);
        //     vm.stopPrank();
        //     vm.startPrank(user2);
        //     wbtc.approve(address(dscEngine), COLLATERAL_AMOUNT);
        //     dscEngine.depositCollateral(wbtcAddress, COLLATERAL_AMOUNT);
        //     vm.stopPrank();
        // }
        _;
    }

    modifier usersMinted() {
        vm.prank(user1);
        dscEngine.mintDsc(DSC_MINT_AMOUNT);
        vm.prank(user2);
        dscEngine.mintDsc(DSC_MINT_AMOUNT);
        _;
    }

    modifier user3CanBeLiquidated() {
        // new eth price $500 less (25% reduction in starting mock price)
        int256 newReducedEthPrice = MOCK_ETH_USD_PRICE - 500e8;
        // approve and deposit for user 3
        vm.startPrank(user3);
        weth.approve(address(dscEngine), COLLATERAL_AMOUNT);
        dscEngine.depositCollateral(wethAddress, COLLATERAL_AMOUNT);
        vm.stopPrank();
        // figure out how much DST to mint
        (, uint256 totalValue) = dscEngine.getAccountInformation(user3);
        uint256 amountDscToMint = (totalValue * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
        // mint the max amount of dsc to put health factor near 1
        vm.prank(user3);
        dscEngine.mintDsc(amountDscToMint);
        // make user3 liquidate-able by manipulating price
        MockV3Aggregator(ethUsdPriceFeed).updateAnswer(newReducedEthPrice);
        _;
    }

    /*//////////////////////////////////////////////////////////////
                                 TESTS
    //////////////////////////////////////////////////////////////*/

    function setUp() external {
        deployer = new DeployDSC();
        (dsc, dscEngine, helperConfig) = deployer.run();
        (ethUsdPriceFeed, btcUsdPriceFeed, wethAddress, wbtcAddress, account) = helperConfig.activeNetworkConfig();
        weth = ERC20Mock(wethAddress);
        wbtc = ERC20Mock(wbtcAddress);
        vm.deal(user1, STARTING_USER_BALANCE);
        vm.deal(user2, STARTING_USER_BALANCE);
        vm.deal(user3, STARTING_USER_BALANCE);
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    function testDscEngineConstructorRevertsWhenArraysAreNotSameLength() external {
        invalidTokenAddresses.push(wethAddress);
        invalidPriceFeedAddresses.push(ethUsdPriceFeed);
        invalidPriceFeedAddresses.push(btcUsdPriceFeed);
        vm.expectRevert(DSCEngine.DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLength.selector);
        new DSCEngine(invalidTokenAddresses, invalidPriceFeedAddresses, address(dsc));
    }

    function testDscEngineConstructorRevertsWhenATokenAddressIsZero() external {
        address[] memory tokenAddresses = new address[](2);
        tokenAddresses[0] = address(weth);
        tokenAddresses[1] = address(0);
        address[] memory priceFeedAddresses = new address[](2);
        priceFeedAddresses[0] = ethUsdPriceFeed;
        priceFeedAddresses[1] = btcUsdPriceFeed;
        vm.expectRevert(DSCEngine.DSCEngine__InvalidPriceFeedOrTokenAddress.selector);
        new DSCEngine(tokenAddresses, priceFeedAddresses, address(dsc));
    }

    function testDscEngineConstructorRevertsWhenAPriceFeedAddressIsZero() external {
        address[] memory tokenAddresses = new address[](2);
        tokenAddresses[0] = address(weth);
        tokenAddresses[1] = address(wbtc);
        address[] memory priceFeedAddresses = new address[](2);
        priceFeedAddresses[0] = ethUsdPriceFeed;
        priceFeedAddresses[1] = address(0);
        vm.expectRevert(DSCEngine.DSCEngine__InvalidPriceFeedOrTokenAddress.selector);
        new DSCEngine(tokenAddresses, priceFeedAddresses, address(dsc));
    }

    /*//////////////////////////////////////////////////////////////
                           DEPOSIT COLLATERAL
    //////////////////////////////////////////////////////////////*/

    function testDepositCollateralRevertsIfAmountIsZero() external usersFunded {
        vm.startPrank(user1);
        weth.approve(address(dscEngine), COLLATERAL_AMOUNT);
        vm.expectRevert(DSCEngine.DSCEngine__AmountMustBeMoreThanZero.selector);
        dscEngine.depositCollateral(wethAddress, 0);
        vm.stopPrank();
    }

    // function testDepositCollateralFailsIfReentered() external usersFunded {
    //     // somehow forcefully reenter and ensure reentrancy guard throws expected error
    //     vm.startPrank(user1);
    //     vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
    //     vm.stopPrank();
    // }

    function testDepositCollateralRevertsIfTokenIsNotApproved() external {
        ERC20Mock invalidErc20 = new ERC20Mock();
        invalidErc20.mint(user1, STARTING_ERC20_BALANCE);
        vm.startPrank(user1);
        invalidErc20.approve(address(dscEngine), COLLATERAL_AMOUNT);
        vm.expectRevert(DSCEngine.DSCEngine__NotApprovedToken.selector);
        dscEngine.depositCollateral(address(invalidErc20), COLLATERAL_AMOUNT);
        vm.stopPrank();
    }

    // not necessary since ERC20 will revert before DSCEngine
    // might be another way to trigger this specific error
    // function testDepositCollateralRevertsIfUserHasInsufficientCollateralBalance() external {
    //     vm.startPrank(user1);
    //     wbtc.approve(address(dscEngine), COLLATERAL_AMOUNT);
    //     vm.expectRevert(DSCEngine.DSCEngine__TransferFailed.selector);
    //     dscEngine.depositCollateral(wbtcAddress, COLLATERAL_AMOUNT);
    //     vm.stopPrank();
    // }

    function testDepositCollateralEmitsEvent() external usersFunded {
        vm.startPrank(user1);
        weth.approve(address(dscEngine), COLLATERAL_AMOUNT);
        vm.expectEmit(true, true, true, false, address(dscEngine));
        emit CollateralDeposited(user1, wethAddress, COLLATERAL_AMOUNT);
        dscEngine.depositCollateral(wethAddress, COLLATERAL_AMOUNT);
        vm.stopPrank();
    }

    function testDepositCollateralUpdatesState() external usersFunded {
        // ARRANGE: check initial state and approve token
        assertEq(dscEngine.getAccountCollateralValueInUsd(user1), 0);
        assertEq(dscEngine.getAccountCollateralBalance(user1, wethAddress), 0);
        vm.prank(user1);
        weth.approve(address(dscEngine), COLLATERAL_AMOUNT);
        // ACT: deposit collateral
        vm.prank(user1);
        dscEngine.depositCollateral(wethAddress, COLLATERAL_AMOUNT);
        // ASSERT: verify state changes
        uint256 expectedDepositValue = dscEngine.getUsdValue(wethAddress, COLLATERAL_AMOUNT);
        uint256 actualDepositValue = dscEngine.getAccountCollateralValueInUsd(user1);
        assertEq(expectedDepositValue, actualDepositValue);
        assertEq(dscEngine.getAccountCollateralBalance(user1, wethAddress), COLLATERAL_AMOUNT);
    }

    function testGetAccountInformationIsUpdatedAfterDepositingCollateral() external usersFunded {
        vm.startPrank(user1);
        weth.approve(address(dscEngine), COLLATERAL_AMOUNT);
        dscEngine.depositCollateral(wethAddress, COLLATERAL_AMOUNT);
        vm.stopPrank();
        (uint256 totalDscMinted, uint256 totalCollateralValueInUsd) = dscEngine.getAccountInformation(user1);
        uint256 expectedTotalDscMinted = 0;
        uint256 expectedDepositAmount = dscEngine.getTokenAmountFromUsd(wethAddress, totalCollateralValueInUsd);
        assertEq(expectedTotalDscMinted, totalDscMinted);
        assertEq(expectedDepositAmount, COLLATERAL_AMOUNT);
    }

    /*//////////////////////////////////////////////////////////////
                                MINT DSC
    //////////////////////////////////////////////////////////////*/

    function testMintDscFailsIfAmountIsZero() external usersFunded usersDeposited {
        vm.prank(user1);
        vm.expectRevert(DSCEngine.DSCEngine__AmountMustBeMoreThanZero.selector);
        dscEngine.mintDsc(0);
    }

    // function testMintDscFailsIfReentered() external usersFunded usersDeposited {
    //     // somehow forcefully reenter and ensure reentrancy guard throws expected error
    //     vm.startPrank(user1);
    //     vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
    //     vm.stopPrank();
    // }

    function testMintDscFailsIfUserHasNoCollateralDeposited() external usersFunded {
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(DSCEngine.DSCEngine__BreaksHealthFactor.selector, 0));
        dscEngine.mintDsc(DSC_MINT_AMOUNT);
    }

    function testMintDscFailsIfUserHasInsufficientCollateralDeposited() external usersFunded usersDeposited {
        (, uint256 currentCollateralValueUsd) = dscEngine.getAccountInformation(user1);
        uint256 collateralAdjustedForThreshold =
            (currentCollateralValueUsd * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
        uint256 expectedHealthFactor = (collateralAdjustedForThreshold * PRECISION) / INVALID_DSC_MINT_AMOUNT;
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(DSCEngine.DSCEngine__BreaksHealthFactor.selector, expectedHealthFactor));
        dscEngine.mintDsc(INVALID_DSC_MINT_AMOUNT);
    }

    function testMintDscUpdatesStateAndMintsTokens() external usersFunded usersDeposited {
        assertEq(dsc.balanceOf(user1), 0);
        vm.prank(user1);
        dscEngine.mintDsc(DSC_MINT_AMOUNT);
        assertEq(dsc.balanceOf(user1), DSC_MINT_AMOUNT);
    }

    function testGetAccountInformationIsUpdatedAfterDepositingAndMintingDsc() external usersFunded {
        vm.startPrank(user1);
        weth.approve(address(dscEngine), COLLATERAL_AMOUNT);
        dscEngine.depositCollateral(wethAddress, COLLATERAL_AMOUNT);
        dscEngine.mintDsc(DSC_MINT_AMOUNT);
        vm.stopPrank();
        (uint256 totalDscMinted, uint256 totalCollateralValueInUsd) = dscEngine.getAccountInformation(user1);
        uint256 expectedDepositAmount = dscEngine.getTokenAmountFromUsd(wethAddress, totalCollateralValueInUsd);
        assertEq(DSC_MINT_AMOUNT, totalDscMinted);
        assertEq(expectedDepositAmount, COLLATERAL_AMOUNT);
    }

    function testMintDscEmitsEvent() external usersFunded usersDeposited {
        vm.expectEmit(true, true, true, false, address(dsc));
        emit Transfer(address(0), user1, DSC_MINT_AMOUNT);
        vm.prank(user1);
        dscEngine.mintDsc(DSC_MINT_AMOUNT);
    }

    /*//////////////////////////////////////////////////////////////
                    DEPOSIT COLLATERAL AND MINT DSC
    //////////////////////////////////////////////////////////////*/

    function testDepositCollateralAndMintDscUpdatesState() external usersFunded {
        vm.startPrank(user1);
        weth.approve(address(dscEngine), COLLATERAL_AMOUNT);
        dscEngine.depositCollateralAndMintDsc(wethAddress, COLLATERAL_AMOUNT, DSC_MINT_AMOUNT);
        vm.stopPrank();
        assertEq(dsc.balanceOf(user1), DSC_MINT_AMOUNT);
        (uint256 dscMinted,) = dscEngine.getAccountInformation(user1);
        assertEq(dscMinted, DSC_MINT_AMOUNT);
        assertEq(dscEngine.getAccountCollateralBalance(user1, wethAddress), COLLATERAL_AMOUNT);
    }

    function testDepositCollateralAndMintDscEmitsEvents() external usersFunded {
        vm.startPrank(user1);
        weth.approve(address(dscEngine), COLLATERAL_AMOUNT);
        vm.expectEmit(true, true, true, false, address(dscEngine));
        emit CollateralDeposited(user1, wethAddress, COLLATERAL_AMOUNT);
        vm.expectEmit(true, true, true, false, address(dsc));
        emit Transfer(address(0), user1, DSC_MINT_AMOUNT);
        dscEngine.depositCollateralAndMintDsc(wethAddress, COLLATERAL_AMOUNT, DSC_MINT_AMOUNT);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                           REDEEM COLLATERAL
    //////////////////////////////////////////////////////////////*/

    function testRedeemCollateralFailsIfAmountIsZero() external usersFunded usersDeposited {
        vm.prank(user1);
        vm.expectRevert(DSCEngine.DSCEngine__AmountMustBeMoreThanZero.selector);
        dscEngine.redeemCollateral(wethAddress, 0);
    }

    // function testRedeemCollateralFailsIfReentered() external usersFunded usersDeposited {
    //     // somehow forcefully reenter and ensure reentrancy guard throws expected error
    //     vm.startPrank(user1);
    //     vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
    //     vm.stopPrank();
    // }

    function testRedeemCollateralFailsIfBreaksHealthFactor() external usersFunded usersDeposited usersMinted {
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(DSCEngine.DSCEngine__BreaksHealthFactor.selector, 0));
        dscEngine.redeemCollateral(wethAddress, COLLATERAL_AMOUNT);
    }

    function testRedeemCollateralUpdatesState() external usersFunded usersDeposited {
        uint256 startingCollateralBalance = dscEngine.getAccountCollateralBalance(user1, wethAddress);
        vm.prank(user1);
        dscEngine.redeemCollateral(wethAddress, COLLATERAL_AMOUNT);
        assertEq(
            dscEngine.getAccountCollateralBalance(user1, wethAddress), startingCollateralBalance - COLLATERAL_AMOUNT
        );
    }

    function testRedeemCollateralEmitsEvents() external usersFunded usersDeposited {
        vm.expectEmit(true, true, true, true, address(dscEngine));
        emit CollateralRedeemed(user1, user1, wethAddress, COLLATERAL_AMOUNT);
        vm.expectEmit(true, true, true, false, wethAddress);
        emit Transfer(address(dscEngine), user1, COLLATERAL_AMOUNT);
        vm.prank(user1);
        dscEngine.redeemCollateral(wethAddress, COLLATERAL_AMOUNT);
    }

    /*//////////////////////////////////////////////////////////////
                                BURN DSC
    //////////////////////////////////////////////////////////////*/

    function testBurnDscFailsIfAmountIsZero() external usersFunded usersDeposited usersMinted {
        vm.startPrank(user1);
        dsc.approve(address(dscEngine), DSC_MINT_AMOUNT);
        vm.expectRevert(DSCEngine.DSCEngine__AmountMustBeMoreThanZero.selector);
        dscEngine.burnDsc(0);
        vm.stopPrank();
    }

    // function testBurnDscFailsIfReentered() external usersFunded usersDeposited usersMinted {
    //     // somehow forcefully reenter and ensure reentrancy guard throws expected error
    //     vm.startPrank(user1);
    //     vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
    //     vm.stopPrank();
    // }

    function testBurnDscFailsWhenBurningMoreThanBalance() external usersFunded usersDeposited usersMinted {
        vm.startPrank(user1);
        dsc.approve(address(dscEngine), DSC_MINT_AMOUNT);
        vm.expectRevert("panic: arithmetic underflow or overflow (0x11)");
        dscEngine.burnDsc(DSC_MINT_AMOUNT + 1);
        vm.stopPrank();
    }

    function testBurnDscEmitsEvents() external usersFunded usersDeposited usersMinted {
        vm.prank(user1);
        dsc.approve(address(dscEngine), DSC_MINT_AMOUNT);
        vm.expectEmit(true, true, true, false, address(dsc));
        emit Transfer(user1, address(dscEngine), DSC_MINT_AMOUNT);
        vm.expectEmit(true, true, true, false, address(dsc));
        emit Transfer(address(dscEngine), address(0), DSC_MINT_AMOUNT);
        vm.prank(user1);
        dscEngine.burnDsc(DSC_MINT_AMOUNT);
    }

    function testBurnDscUpdatesStateAndImprovesHealthFactor() external usersFunded usersDeposited usersMinted {
        uint256 startingHealthFactor = dscEngine.getHealthFactor(user1);
        (uint256 totalDscMinted,) = dscEngine.getAccountInformation(user1);
        uint256 dscBalanceBeforeBurn = dsc.balanceOf(user1);
        vm.startPrank(user1);
        dsc.approve(address(dscEngine), DSC_BURN_AMOUNT);
        dscEngine.burnDsc(DSC_BURN_AMOUNT);
        vm.stopPrank();
        uint256 endingHealthFactor = dscEngine.getHealthFactor(user1);
        (uint256 amountDscMintedAfterBurn,) = dscEngine.getAccountInformation(user1);
        uint256 dscBalanceAfterBurn = dsc.balanceOf(user1);
        assert(startingHealthFactor < endingHealthFactor);
        assertEq((totalDscMinted - amountDscMintedAfterBurn), DSC_BURN_AMOUNT);
        assertEq((dscBalanceBeforeBurn - dscBalanceAfterBurn), DSC_BURN_AMOUNT);
    }

    /*//////////////////////////////////////////////////////////////
                       REDEEM COLLATERAL FOR DSC
    //////////////////////////////////////////////////////////////*/

    function testRedeemCollateralForDscUpdatesState() external usersFunded usersDeposited usersMinted {
        (uint256 dscMintedBefore,) = dscEngine.getAccountInformation(user1);
        vm.prank(user1);
        dsc.approve(address(dscEngine), DSC_MINT_AMOUNT);
        vm.prank(user1);
        dscEngine.redeemCollateralForDsc(wethAddress, COLLATERAL_AMOUNT, DSC_MINT_AMOUNT);
        (uint256 dscMintedAfter, uint256 collateralValueInUsdAfter) = dscEngine.getAccountInformation(user1);
        // should be 0 after burning minted DSC
        assertEq(dscMintedBefore - DSC_MINT_AMOUNT, dscMintedAfter);
        // should be 0 after withdrawing all collateral
        assertEq(dscEngine.getAccountCollateralBalance(user1, wethAddress), 0);
        assertEq(collateralValueInUsdAfter, 0);
    }

    function testRedeemCollateralForDscEmitsEvents() external usersFunded usersDeposited usersMinted {
        vm.prank(user1);
        dsc.approve(address(dscEngine), DSC_MINT_AMOUNT);
        vm.expectEmit(true, true, true, false, address(dsc));
        emit Transfer(user1, address(dscEngine), DSC_MINT_AMOUNT);
        vm.expectEmit(true, true, true, false, address(dsc));
        emit Transfer(address(dscEngine), address(0), DSC_MINT_AMOUNT);
        vm.expectEmit(true, true, true, true, address(dscEngine));
        emit CollateralRedeemed(user1, user1, wethAddress, COLLATERAL_AMOUNT);
        vm.expectEmit(true, true, true, false, wethAddress);
        emit Transfer(address(dscEngine), user1, COLLATERAL_AMOUNT);
        vm.prank(user1);
        dscEngine.redeemCollateralForDsc(wethAddress, COLLATERAL_AMOUNT, DSC_MINT_AMOUNT);
    }

    /*//////////////////////////////////////////////////////////////
                               LIQUIDATE
    //////////////////////////////////////////////////////////////*/

    function testLiquidateFailsIfAmountIsZero() external usersFunded usersDeposited usersMinted user3CanBeLiquidated {
        vm.prank(user1);
        vm.expectRevert(DSCEngine.DSCEngine__AmountMustBeMoreThanZero.selector);
        dscEngine.liquidate(user3, wethAddress, 0);
    }

    // function testLiquidateFailsIfReentered() external usersFunded usersDeposited {
    //     // somehow forcefully reenter and ensure reentrancy guard throws expected error
    //     vm.startPrank(user1);
    //     vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
    //     vm.stopPrank();
    // }

    function testLiquidateFailsIfUserIsNotEligibleForLiquidation() external usersFunded usersDeposited usersMinted {
        // liquidate non-eligible user with collateral deposited and dsc minted
        vm.prank(user1);
        vm.expectRevert(DSCEngine.DSCEngine__UserNotEligibleForLiquidation.selector);
        dscEngine.liquidate(user2, wethAddress, DSC_MINT_AMOUNT);
        // liquidate non-eligible user with 0 collateral deposited and 0 dsc minted
        vm.prank(user1);
        vm.expectRevert(DSCEngine.DSCEngine__UserNotEligibleForLiquidation.selector);
        dscEngine.liquidate(user3, wethAddress, DSC_MINT_AMOUNT);
        // liquidate non-eligible user with collateral deposited and 0 dsc minted
        vm.startPrank(user3);
        weth.approve(address(dscEngine), COLLATERAL_AMOUNT);
        dscEngine.depositCollateral(wethAddress, COLLATERAL_AMOUNT);
        vm.stopPrank();
        vm.prank(user1);
        vm.expectRevert(DSCEngine.DSCEngine__UserNotEligibleForLiquidation.selector);
        dscEngine.liquidate(user3, wethAddress, DSC_MINT_AMOUNT);
    }

    // // not sure how to induce this error. need to figure out how paying someone elses debt can break your health factor
    // function testLiquidateFailsIfLiquidationBreaksLiquidatorsHealthFactor()
    //     external
    //     usersFunded
    //     usersDeposited
    //     usersMinted
    // {
    //     vm.prank(user1);
    //     vm.expectRevert(DSCEngine.DSCEngine__BreaksHealthFactor.selector);
    //     dscEngine.liquidate(user2, wethAddress, DSC_MINT_AMOUNT);
    // }

    function testLiquidateUpdatesStateAndDistributesCorrectCollateralAmountPlusBonus()
        external
        skipFork
        usersFunded
        usersDeposited
        usersMinted
        user3CanBeLiquidated
    {
        uint256 initialWethBalance = weth.balanceOf(user1);

        // this method works since it mirrors the math order on contract
        uint256 tokenAmountFromLiquidation = dscEngine.getTokenAmountFromUsd(wethAddress, DSC_MINT_AMOUNT);
        uint256 expectedLiquidationProceeds =
            tokenAmountFromLiquidation + ((tokenAmountFromLiquidation * LIQUIDATION_BONUS) / LIQUIDATION_PRECISION);

        // this method does not work exactly since liquidation bonus on contract is calculated using eth amounts instead of usd amounts
        // uint256 expectedLiquidationProceedsUsd =
        //     DSC_MINT_AMOUNT + ((DSC_MINT_AMOUNT * LIQUIDATION_BONUS) / LIQUIDATION_PRECISION);
        // uint256 expectedLiquidationProceeds =
        //     dscEngine.getTokenAmountFromUsd(wethAddress, expectedLiquidationProceedsUsd);

        vm.prank(user1);
        dsc.approve(address(dscEngine), DSC_MINT_AMOUNT);
        vm.prank(user1);
        dscEngine.liquidate(user3, wethAddress, DSC_MINT_AMOUNT);
        uint256 finalWethBalance = weth.balanceOf(user1);
        assertEq(finalWethBalance, initialWethBalance + expectedLiquidationProceeds);

        // need to add approximate +-1 to account for a single wei of precision loss during price conversions if using the commented out method above
        // assertApproxEqAbs(finalWethBalance, initialWethBalance + expectedLiquidationProceeds, 1);
    }

    function testLiquidateEmitsEvents() external skipFork usersFunded usersDeposited usersMinted user3CanBeLiquidated {
        uint256 tokenAmountFromLiquidation = dscEngine.getTokenAmountFromUsd(wethAddress, DSC_MINT_AMOUNT);
        uint256 expectedLiquidationProceeds =
            tokenAmountFromLiquidation + ((tokenAmountFromLiquidation * LIQUIDATION_BONUS) / LIQUIDATION_PRECISION);
        vm.prank(user1);
        dsc.approve(address(dscEngine), DSC_MINT_AMOUNT);
        vm.expectEmit(true, true, true, true, address(dscEngine));
        emit CollateralRedeemed(user3, user1, wethAddress, expectedLiquidationProceeds);
        vm.expectEmit(true, true, true, false, wethAddress);
        emit Transfer(address(dscEngine), user1, expectedLiquidationProceeds);
        vm.expectEmit(true, true, true, false, address(dsc));
        emit Transfer(user1, address(dscEngine), DSC_MINT_AMOUNT);
        vm.expectEmit(true, true, true, false, address(dsc));
        emit Transfer(address(dscEngine), address(0), DSC_MINT_AMOUNT);
        vm.prank(user1);
        dscEngine.liquidate(user3, wethAddress, DSC_MINT_AMOUNT);
    }

    /*//////////////////////////////////////////////////////////////
                              VIEW & PURE
    //////////////////////////////////////////////////////////////*/

    function testGetUsdValueShouldFailIfPriceIsStale() external {
        uint256 ethAmount = 15 ether;
        AggregatorV3Interface priceFeed = AggregatorV3Interface(ethUsdPriceFeed);
        (,,, uint256 updatedAt,) = priceFeed.latestRoundData();
        uint256 staleAt = updatedAt + 3 hours + 1;
        vm.warp(staleAt);
        vm.expectRevert(OracleLib.OracleLib__StalePrice.selector);
        vm.prank(user1);
        dscEngine.getUsdValue(wethAddress, ethAmount);
    }

    function testGetUsdValue() external view {
        uint256 ethAmount = 15 ether;
        AggregatorV3Interface priceFeed = AggregatorV3Interface(ethUsdPriceFeed);
        (, int256 price,,,) = priceFeed.latestRoundData();
        uint256 expectedUsd = ((uint256(price) * ADDITIONAL_PRICE_FEED_PRECISION) * ethAmount) / PRECISION;
        uint256 actualUsd = dscEngine.getUsdValue(wethAddress, ethAmount);
        assertEq(expectedUsd, actualUsd);
    }

    function testGetUsdValueOnLocalChain() external view skipFork {
        uint256 ethAmount = 15 ether;
        // 15 ETH * $2000 = 30,000e18
        uint256 expectedUsd = 30_000e18;
        uint256 actualUsd = dscEngine.getUsdValue(wethAddress, ethAmount);
        assertEq(expectedUsd, actualUsd);
    }

    function testGetTokenAmountFromUsdShouldFailIfPriceIsStale() external {
        uint256 usdAmount = 100 ether;
        AggregatorV3Interface priceFeed = AggregatorV3Interface(ethUsdPriceFeed);
        (,,, uint256 updatedAt,) = priceFeed.latestRoundData();
        uint256 staleAt = updatedAt + 3 hours + 1;
        vm.warp(staleAt);
        vm.expectRevert(OracleLib.OracleLib__StalePrice.selector);
        vm.prank(user1);
        dscEngine.getTokenAmountFromUsd(wethAddress, usdAmount);
    }

    function testGetTokenAmountFromUsd() external view {
        uint256 usdAmount = 100 ether;
        AggregatorV3Interface priceFeed = AggregatorV3Interface(ethUsdPriceFeed);
        (, int256 price,,,) = priceFeed.latestRoundData();
        uint256 expectedWethAmount = (usdAmount * PRECISION) / (uint256(price) * ADDITIONAL_PRICE_FEED_PRECISION);
        uint256 actualWethAmount = dscEngine.getTokenAmountFromUsd(wethAddress, usdAmount);
        assertEq(expectedWethAmount, actualWethAmount);
    }

    function testGetTokenAmountFromUsdOnLocalChain() external view skipFork {
        uint256 usdAmount = 100 ether;
        uint256 expectedWethAmount = 0.05 ether;
        uint256 actualWethAmount = dscEngine.getTokenAmountFromUsd(wethAddress, usdAmount);
        assertEq(expectedWethAmount, actualWethAmount);
    }

    function testGetHealthFactorShouldFailIfPriceIsStale() external usersFunded usersDeposited usersMinted {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(ethUsdPriceFeed);
        (,,, uint256 updatedAt,) = priceFeed.latestRoundData();
        uint256 staleAt = updatedAt + 3 hours + 1;
        vm.warp(staleAt);
        vm.expectRevert(OracleLib.OracleLib__StalePrice.selector);
        vm.prank(user1);
        dscEngine.getHealthFactor(user1);
    }

    function testGetHealthFactorReturnsCorrectValuesForFringeStates() external usersFunded {
        // when collateral deposited and dsc minted both == 0
        assertEq(dscEngine.getHealthFactor(user1), type(uint256).max);
        // when collateral deposited == 0, and dsc minted > 0
        // only way to force this state is to try and mint DSC with no collateral deposited
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(DSCEngine.DSCEngine__BreaksHealthFactor.selector, 0));
        dscEngine.mintDsc(DSC_MINT_AMOUNT);
        assertEq(dscEngine.getHealthFactor(user1), type(uint256).max);
    }

    function testGetHealthFactorReturnsCorrectValuesAfterDeposit() external usersFunded usersDeposited {
        // when collateral deposited > 0 and dsc minted == 0
        // should avoid divide by zero by returning max health factor before calculation
        assertEq(dscEngine.getHealthFactor(user1), type(uint256).max);
    }

    function testGetHealthFactorReturnsCorrectValuesAfterMint() external usersFunded usersDeposited usersMinted {
        // when collateral deposited > 0 and dsc minted > 0
        // straightforward calculation
        (uint256 dscMinted, uint256 collateralValueInUsd) = dscEngine.getAccountInformation(user1);
        uint256 collateralAdjustedForThreshold = (collateralValueInUsd * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
        assertEq(dscEngine.getHealthFactor(user1), (collateralAdjustedForThreshold * PRECISION) / dscMinted);
    }

    function testGetHealthFactorEstimate() external usersFunded usersDeposited usersMinted {
        (uint256 dscMinted, uint256 collateralValueInUsd) = dscEngine.getAccountInformation(user1);
        assertEq(dscEngine.getHealthFactor(user1), dscEngine.getHealthFactorEstimate(dscMinted, collateralValueInUsd));
    }

    function testGetMinHealthFactor() external view {
        assertEq(dscEngine.getMinHealthFactor(), MIN_HEALTH_FACTOR);
    }

    function testGetPrecision() external view {
        assertEq(dscEngine.getPrecision(), PRECISION);
    }

    function testGetAdditionalPriceFeedPrecision() external view {
        assertEq(dscEngine.getAdditionalPriceFeedPrecision(), ADDITIONAL_PRICE_FEED_PRECISION);
    }

    function testGetLiquidationBonus() external view {
        assertEq(dscEngine.getLiquidationBonus(), LIQUIDATION_BONUS);
    }

    function testGetLiquidationThreshold() external view {
        assertEq(dscEngine.getLiquidationThreshold(), LIQUIDATION_THRESHOLD);
    }

    function testGetLiquidationPrecision() external view {
        assertEq(dscEngine.getLiquidationPrecision(), LIQUIDATION_PRECISION);
    }
}
