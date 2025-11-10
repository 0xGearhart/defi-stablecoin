// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {AggregatorV3Interface, DSCEngine} from "../../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../../src/DecentralizedStableCoin.sol";
import {MockV3Aggregator} from "../../mocks/MockV3Aggregator.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {Test, console} from "forge-std/Test.sol";

contract Handler is Test {
    using EnumerableSet for EnumerableSet.AddressSet;

    DSCEngine public dscEngine;
    DecentralizedStableCoin public dsc;
    ERC20Mock public weth;
    ERC20Mock public wbtc;
    MockV3Aggregator public ethUsdPriceFeed;
    MockV3Aggregator public btcUsdPriceFeed;

    int256 public constant MOCK_ETH_USD_PRICE = 2000e8;
    int256 public constant MOCK_BTC_USD_PRICE = 1000e8;
    uint256 private constant MIN_HEALTH_FACTOR = 1e18;

    // ghost variables to track info during fuzz runs and help reduce failed calls
    uint256 public timesMintCalled;
    uint256 public timesDepositCalled;
    uint256 public timesRedeemCalled;
    uint256 public timesLiquidateCalled;
    uint256 public timesBurnCalled;
    uint256 public timesDepositAndMintCalled;
    EnumerableSet.AddressSet internal usersWithCollateralDeposited;
    EnumerableSet.AddressSet internal usersWithDscMinted;

    // use uint96 max to avoid overflow and math issues related to using uint256 max.
    uint256 constant MAX_DEPOSIT_SIZE = type(uint96).max;

    constructor(DSCEngine _dscEngine, DecentralizedStableCoin _dsc) {
        dscEngine = _dscEngine;
        dsc = _dsc;
        address[] memory collateralAddresses = dscEngine.getCollateralTokenAddresses();
        weth = ERC20Mock(collateralAddresses[0]);
        wbtc = ERC20Mock(collateralAddresses[1]);
        ethUsdPriceFeed = MockV3Aggregator(dscEngine.getPriceFeedAddress(address(weth)));
        btcUsdPriceFeed = MockV3Aggregator(dscEngine.getPriceFeedAddress(address(wbtc)));
    }

    /*//////////////////////////////////////////////////////////////
                                HANDLERS
    //////////////////////////////////////////////////////////////*/

    function depositCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
        // bound between 1 and max size to cut down on fails due to depositing 0 or depositing near uint256 max
        amountCollateral = bound(amountCollateral, 1, MAX_DEPOSIT_SIZE);

        vm.startPrank(msg.sender);
        collateral.mint(msg.sender, amountCollateral);
        collateral.approve(address(dscEngine), amountCollateral);
        dscEngine.depositCollateral(address(collateral), amountCollateral);
        vm.stopPrank();
        // if new deposit, add to array of addresses that can call mintDsc
        if (!usersWithCollateralDeposited.contains(msg.sender)) {
            usersWithCollateralDeposited.add(msg.sender);
        }
        timesDepositCalled++;
    }

    function redeemCollateral(uint256 collateralSeed, uint256 amountCollateral, uint256 addressSeed) public {
        // pick random address that has deposited
        address sender = _getDepositedAddressFromSeed(addressSeed);
        if (sender == address(0)) {
            return;
        }
        // pick random collateral
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
        // get info to determine max withdraw in USD without breaking health factor
        (uint256 totalDscMinted, uint256 totalCollateralValueInUsd) = dscEngine.getAccountInformation(sender);
        uint256 maxUsdValueBeforeBreakingHealthFactor = (totalCollateralValueInUsd / 2) - totalDscMinted;
        // bound max usd value to withdraw between 0 and the value of a users deposits for this specific collateral type
        uint256 currentCollateralBalance = dscEngine.getAccountCollateralBalance(sender, address(collateral));
        maxUsdValueBeforeBreakingHealthFactor = bound(
            maxUsdValueBeforeBreakingHealthFactor,
            0,
            dscEngine.getUsdValue(address(collateral), currentCollateralBalance)
        );
        // convert USD values to actual amount of tokens to withdraw
        uint256 maxCollateralToRedeem =
            dscEngine.getTokenAmountFromUsd(address(collateral), maxUsdValueBeforeBreakingHealthFactor);
        // finally bound random amount to redeem between 0 and a valid amount that wont revert
        amountCollateral = bound(amountCollateral, 0, maxCollateralToRedeem);
        // could be 0 if user minted max amount of DSC
        if (amountCollateral == 0) {
            return;
        }
        // redeem collateral amount
        vm.prank(sender);
        dscEngine.redeemCollateral(address(collateral), amountCollateral);
        // if user has 0 USD value deposited after redeem; remove them from array so they do not try to mint DSC without depositing first
        (, uint256 totalCollateralValueAfterRedemption) = dscEngine.getAccountInformation(sender);
        if (totalCollateralValueAfterRedemption == 0 && usersWithCollateralDeposited.contains(sender)) {
            usersWithCollateralDeposited.remove(sender);
        }
        timesRedeemCalled++;
    }

    // function redeemCollateral(uint256 collateralSeed, uint256 amountCollateral, uint256 addressSeed) public {
    //     // pick random address that has deposited
    //     address sender = _getDepositedAddressFromSeed(addressSeed);
    //     if (sender == address(0)) {
    //         return;
    //     }
    //     // pick random collateral
    //     ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
    //     uint256 userCollateralBalance = dscEngine.getAccountCollateralBalance(sender, address(collateral));
    //     uint256 userCollateralValue = dscEngine.getUsdValue(address(collateral), userCollateralBalance);
    //     (uint256 totalDscMinted, uint256 totalCollateralValueInUsd) = dscEngine.getAccountInformation(sender);
    //     uint256 estimatedCollateralValue = totalCollateralValueInUsd - userCollateralValue;
    //     uint256 maxCollateralToRedeem = userCollateralBalance;
    //     if (dscEngine.getHealthFactorEstimate(totalDscMinted, estimatedCollateralValue) < 1) {
    //         uint256 maxUsdValueBeforeBreakingHealthFactor = (userCollateralValue / 2) - totalDscMinted;
    //         uint256 maxRedeemWithoutBrakingHealthFactor =
    //             dscEngine.getTokenAmountFromUsd(address(collateral), maxUsdValueBeforeBreakingHealthFactor);
    //         maxCollateralToRedeem = bound(maxCollateralToRedeem, 0, maxRedeemWithoutBrakingHealthFactor);
    //     }
    //     amountCollateral = bound(amountCollateral, 0, maxCollateralToRedeem);
    //     if (amountCollateral == 0) {
    //         return;
    //     }
    //     // redeem collateral amount
    //     vm.prank(sender);
    //     dscEngine.redeemCollateral(address(collateral), amountCollateral);
    //     // if user has 0 USD value deposited after redeem; remove them from array so they do not try to mint DSC without depositing first
    //     (, uint256 totalCollateralValueAfterRedemption) = dscEngine.getAccountInformation(sender);
    //     if (totalCollateralValueAfterRedemption == 0 && usersWithCollateralDeposited.contains(sender)) {
    //         usersWithCollateralDeposited.remove(sender);
    //     }
    //     timesRedeemCalled++;
    // }

    function mintDsc(uint256 amountToMint, uint256 addressSeed) public {
        address sender = _getDepositedAddressFromSeed(addressSeed);
        if (sender == address(0)) {
            return;
        }
        (uint256 totalDscMinted, uint256 totalCollateralValueInUsd) = dscEngine.getAccountInformation(sender);
        // need to use int instead of uint just in case random amountToMint results in negative health factor
        int256 maxDscToMint = (int256(totalCollateralValueInUsd) / 2) - int256(totalDscMinted);
        if (maxDscToMint < 0) {
            return;
        }
        // bound to be sure health factors are not broken
        amountToMint = bound(amountToMint, 0, uint256(maxDscToMint));
        if (amountToMint == 0) {
            return;
        }
        vm.prank(sender);
        dscEngine.mintDsc(amountToMint);
        // if new minter, add to array of addresses that can call burnDsc or redeemCollateralForDsc
        if (!usersWithDscMinted.contains(sender)) {
            usersWithDscMinted.add(sender);
        }
        timesMintCalled++;
    }

    function burnDsc(uint256 addressSeed, uint256 amountToBurn) public {
        address sender = _getMintedAddressFromSeed(addressSeed);
        if (sender == address(0)) {
            return;
        }
        (uint256 totalDscMinted,) = dscEngine.getAccountInformation(sender);
        amountToBurn = bound(amountToBurn, 0, totalDscMinted);
        if (amountToBurn == 0) {
            return;
        }
        vm.startPrank(sender);
        dsc.approve(address(dscEngine), amountToBurn);
        dscEngine.burnDsc(amountToBurn);
        vm.stopPrank();
        // if user has 0 DSC after burn; remove them from array so they do not try to burn DSC without minting first
        (uint256 dscMinted,) = dscEngine.getAccountInformation(sender);
        if (dscMinted == 0 && usersWithDscMinted.contains(sender)) {
            usersWithDscMinted.remove(sender);
        }
        timesBurnCalled++;
    }

    function liquidate(uint256 collateralSeed, address userToBeLiquidated, uint256 debtToCover) public {
        uint256 minHealthFactor = dscEngine.getMinHealthFactor();
        uint256 userHealthFactor = dscEngine.getHealthFactor(userToBeLiquidated);
        if (userHealthFactor >= minHealthFactor) {
            return;
        }
        debtToCover = bound(debtToCover, 1, uint256(type(uint96).max));
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
        dscEngine.liquidate(address(collateral), userToBeLiquidated, debtToCover);
        timesLiquidateCalled++;
    }

    // function liquidate(
    //     uint256 addressSeed,
    //     uint256 userToBeLiquidatedSeed,
    //     uint256 collateralSeed,
    //     uint256 debtToCover
    // )
    //     public
    // {
    //     ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
    //     address sender = _getMintedAddressFromSeed(addressSeed);
    //     address userToBeLiquidated = _getMintedAddressFromSeed(userToBeLiquidatedSeed);
    //     if (sender == address(0) || userToBeLiquidated == address(0)) {
    //         return;
    //     }
    //     if (dsc.balanceOf(sender) == 0) {
    //         return;
    //     }
    //     (uint256 totalDscMinted,) = dscEngine.getAccountInformation(sender);
    //     debtToCover = bound(debtToCover, 0, totalDscMinted);
    //     if (debtToCover == 0) {
    //         return;
    //     }
    //     int256 newPrice;
    //     int256 oldPrice;
    //     if (collateral == weth) {
    //         newPrice = (MOCK_ETH_USD_PRICE * 70) / 100; // 30% price drop (75/100)
    //         oldPrice = MOCK_ETH_USD_PRICE;
    //     } else {
    //         newPrice = (MOCK_BTC_USD_PRICE * 70) / 100; // 30% price drop (75/100)
    //         oldPrice = MOCK_BTC_USD_PRICE;
    //     }
    //     // lower price temporarily to make a user eligible for liquidation
    //     _updateCollateralPrice(address(collateral), newPrice);
    //     // if user is still not eligible for liquidation then put price back and return
    //     if (dscEngine.getHealthFactor(userToBeLiquidated) > MIN_HEALTH_FACTOR) {
    //         _updateCollateralPrice(address(collateral), oldPrice);
    //         return;
    //     }
    //     vm.startPrank(sender);
    //     dsc.approve(address(dscEngine), debtToCover);
    //     dscEngine.liquidate(userToBeLiquidated, address(collateral), debtToCover);
    //     vm.stopPrank();
    //     // return price to normal to avoid breaking invariants
    //     _updateCollateralPrice(address(collateral), oldPrice);

    //     (uint256 dscMintedAfterLiquidation, uint256 totalCollateralValueAfterLiquidation) =
    //         dscEngine.getAccountInformation(userToBeLiquidated);
    //     if (dscMintedAfterLiquidation == 0 && usersWithDscMinted.contains(userToBeLiquidated)) {
    //         usersWithDscMinted.remove(userToBeLiquidated);
    //     }
    //     // if user has 0 USD value deposited after redeem; remove them from array so they do not try to mint DSC without depositing first
    //     if (totalCollateralValueAfterLiquidation == 0 && usersWithCollateralDeposited.contains(userToBeLiquidated)) {
    //         usersWithCollateralDeposited.remove(userToBeLiquidated);
    //     }

    //     timesLiquidateCalled++;
    // }

    function depositCollateralAndMintDsc(
        uint256 collateralSeed,
        uint256 amountCollateral,
        uint256 amountDscToMint
    )
        public
    {
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
        // bound between 1 and max size to cut down on fails due to depositing 0 or depositing near uint256 max
        amountCollateral = bound(amountCollateral, 1, MAX_DEPOSIT_SIZE);
        uint256 depositValue = dscEngine.getUsdValue(address(collateral), amountCollateral);
        uint256 maxAmountDscToMint = depositValue / 2;
        amountDscToMint = bound(amountDscToMint, 0, maxAmountDscToMint);
        if (amountDscToMint == 0) {
            return;
        }
        vm.startPrank(msg.sender);
        collateral.mint(msg.sender, amountCollateral);
        collateral.approve(address(dscEngine), amountCollateral);
        dscEngine.depositCollateralAndMintDsc(address(collateral), amountCollateral, amountDscToMint);
        vm.stopPrank();
        // if new deposit, add to array of addresses that can call mintDsc
        if (!usersWithCollateralDeposited.contains(msg.sender)) {
            usersWithCollateralDeposited.add(msg.sender);
        }
        // if new minter, add to array of addresses that can call burnDsc or redeemCollateralForDsc
        if (!usersWithDscMinted.contains(msg.sender)) {
            usersWithDscMinted.add(msg.sender);
        }
        timesDepositAndMintCalled++;
    }

    // this breaks our invariant since price plummeting more than 50% without successful liquidations results in an under-collateralized protocol
    // function updateCollateralPrice(uint256 collateralSeed, uint96 newPrice) public {
    //     int256 newPriceInt = int256(uint256(newPrice));
    //     ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
    //     if (collateral == weth) {
    //         ethUsdPriceFeed.updateAnswer(newPriceInt);
    //     } else {
    //         btcUsdPriceFeed.updateAnswer(newPriceInt);
    //     }
    // }

    /*//////////////////////////////////////////////////////////////
                            HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _getCollateralFromSeed(uint256 collateralSeed) private view returns (ERC20Mock) {
        if (collateralSeed % 2 == 0) {
            return weth;
        } else {
            return wbtc;
        }
    }

    function _getDepositedAddressFromSeed(uint256 addressSeed) private view returns (address) {
        uint256 arrayLength = usersWithCollateralDeposited.length();
        // if length is zero, return invalid address so handler knows to exit before fail
        if (arrayLength == 0) {
            return address(0);
        }
        // modulo length to select random index within usersWithCollateralDeposited address array
        uint256 index = addressSeed % arrayLength;
        return usersWithCollateralDeposited.at(index);
    }

    function _getMintedAddressFromSeed(uint256 addressSeed) private view returns (address) {
        uint256 arrayLength = usersWithDscMinted.length();
        // if length is zero, return invalid address so handler knows to exit before fail
        if (arrayLength == 0) {
            return address(0);
        }
        // modulo length to select random index within usersWithDscMinted address array
        uint256 index = addressSeed % arrayLength;
        return usersWithCollateralDeposited.at(index);
        // address sender = usersWithCollateralDeposited.at(index);
        // if (dsc.balanceOf(sender) == 0) {
        //     return address(0);
        // } else {
        //     return sender;
        // }
    }

    function _updateCollateralPrice(address collateral, int256 newPrice) private {
        if (collateral == address(weth)) {
            ethUsdPriceFeed.updateAnswer(newPrice);
        } else {
            btcUsdPriceFeed.updateAnswer(newPrice);
        }
    }
}
