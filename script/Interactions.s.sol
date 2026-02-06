// SPDX-License-Identifier: MIT

pragma solidity 0.8.33;

import {DSCEngine} from "../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../src/DecentralizedStableCoin.sol";
import {ERC20DecimalsMock} from "../test/mocks/ERC20DecimalsMock.sol";
import {CodeConstants, HelperConfig} from "./HelperConfig.s.sol";
import {DevOpsTools} from "@devops/DevOpsTools.sol";
import {Script} from "forge-std/Script.sol";

contract Interactions is Script, CodeConstants {
    DecentralizedStableCoin dsc;
    DSCEngine dscEngine;
    ERC20DecimalsMock weth;
    ERC20DecimalsMock wbtc;
    address sender;

    uint256 constant WETH_MINT_AMOUNT = 5e18;
    uint256 constant WBTC_MINT_AMOUNT = 2e8;
    uint256 constant DSC_MINT_AMOUNT = 1000e18;
    uint256 constant DSC_BURN_AMOUNT = 500e18;

    constructor() {
        HelperConfig helperConfig = new HelperConfig();
        (address ethUsdPriceFeed, address btcUsdPriceFeed, address wethAddress, address wbtcAddress, address account) =
            helperConfig.activeNetworkConfig();
        sender = account;
        weth = ERC20DecimalsMock(wethAddress);
        wbtc = ERC20DecimalsMock(wbtcAddress);
        dsc = DecentralizedStableCoin(DevOpsTools.get_most_recent_deployment("DecentralizedStableCoin", block.chainid));
        dscEngine = DSCEngine(DevOpsTools.get_most_recent_deployment("DSCEngine", block.chainid));
    }

    function run() external {
        vm.startBroadcast(sender);
        // mint both collateral types
        weth.mint(sender, WETH_MINT_AMOUNT);
        wbtc.mint(sender, WBTC_MINT_AMOUNT);
        // approve DSCEngine to transfer our collateral tokens
        weth.approve(address(dscEngine), WETH_MINT_AMOUNT);
        wbtc.approve(address(dscEngine), WBTC_MINT_AMOUNT);

        // deposit both collateral types and mint some DSC
        dscEngine.depositCollateral(address(weth), WETH_MINT_AMOUNT);
        dscEngine.depositCollateralAndMintDsc(address(wbtc), WBTC_MINT_AMOUNT, DSC_MINT_AMOUNT);

        // approve DSCEngine to transfer our DSC
        dsc.approve(address(dscEngine), DSC_BURN_AMOUNT);
        // burn some DSC
        dscEngine.burnDsc(DSC_BURN_AMOUNT);
        // redeem/withdraw all of our WETH
        dscEngine.redeemCollateral(address(weth), WETH_MINT_AMOUNT);
        vm.stopBroadcast();
    }
}
