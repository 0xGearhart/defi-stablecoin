// SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

import {DSCEngine} from "../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../src/DecentralizedStableCoin.sol";
import {CodeConstants, HelperConfig} from "./HelperConfig.s.sol";
import {Script} from "forge-std/Script.sol";

contract DeployDSC is Script, CodeConstants {
    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    function run() external returns (DecentralizedStableCoin, DSCEngine, HelperConfig) {
        return deployContract();
    }

    function deployContract()
        public
        returns (DecentralizedStableCoin dsc, DSCEngine dscEngine, HelperConfig currentConfig)
    {
        // get deploy info for current chainid
        currentConfig = new HelperConfig();
        (address ethUsdPriceFeed, address btcUsdPriceFeed, address weth, address wbtc, address account) =
            currentConfig.activeNetworkConfig();
        // load arrays for constructor
        tokenAddresses = [weth, wbtc];
        priceFeedAddresses = [ethUsdPriceFeed, btcUsdPriceFeed];
        // deploy using appropriate deployer key for given chainid
        vm.startBroadcast(account);
        dsc = new DecentralizedStableCoin(DSC_NAME, DSC_SYMBOL);
        dscEngine = new DSCEngine(tokenAddresses, priceFeedAddresses, address(dsc));
        // transfer ownership to DSCEngine for minting and burning
        dsc.transferOwnership(address(dscEngine));
        vm.stopBroadcast();
    }
}
