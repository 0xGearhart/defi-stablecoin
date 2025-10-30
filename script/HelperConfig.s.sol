// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";

// import { ERC20Mock } from "../test/mocks/ERC20Mock.sol";
// import { MockV3Aggregator } from "../test/mocks/MockV3Aggregator.sol";

abstract contract CodeConstants {
    // local chain id and info
    uint256 public constant LOCAL_CHAIN_ID = 31337;
    // mainnet chain id and info
    uint256 public constant ETH_MAINNET_CHAIN_ID = 1;
    address public constant WETH_MAINNET_ADDRESS = address(1);
    address public constant WETH_MAINNET_PRICE_FEED_ADDRESS = address(1);
    address public constant WBTC_MAINNET_ADDRESS = address(1);
    address public constant WBTC_MAINNET_PRICE_FEED_ADDRESS = address(1);
    // sepolia chain id and info
    uint256 public constant ETH_SEPOLIA_CHAIN_ID = 11155111;
    address public constant WETH_SEPOLIA_ADDRESS = address(1);
    address public constant WETH_SEPOLIA_PRICE_FEED_ADDRESS = address(1);
    address public constant WBTC_SEPOLIA_ADDRESS = address(1);
    address public constant WBTC_SEPOLIA_PRICE_FEED_ADDRESS = address(1);
    // mock initialize info
    uint8 public constant DECIMALS = 8;
    int256 public constant ETH_USD_PRICE = 2000e8;
    int256 public constant BTC_USD_PRICE = 1000e8;
    // DSC name and symbol
    string public constant DSC_NAME = "DecentralizedStableCoin";
    string public constant DSC_SYMBOL = "DSC";
}

contract HelperConfig is Script, CodeConstants {
    error HelperConfig__InvalidChainId(uint256 chainId);

    NetworkConfig public localNetworkConfig;

    mapping(uint256 => NetworkConfig) private networkConfigs;

    // struct NetworkConfig {
    //     address wethUsdPriceFeed;
    //     address wbtcUsdPriceFeed;
    //     address weth;
    //     address wbtc;
    //     address account;
    // }

    struct NetworkConfig {
        address[] priceFeeds;
        address[] tokens;
        address account;
    }

    constructor() {
        networkConfigs[ETH_MAINNET_CHAIN_ID] = getMainnetEthConfig();
        networkConfigs[ETH_SEPOLIA_CHAIN_ID] = getSepoliaEthConfig();
    }

    function getConfig() public returns (NetworkConfig memory) {
        if (networkConfigs[block.chainid].priceFeeds[0] != address(0)) {
            return networkConfigs[block.chainid];
        } else if (block.chainid == LOCAL_CHAIN_ID) {
            return getOrCreateAnvilEthConfig();
        } else {
            revert HelperConfig__InvalidChainId(block.chainid);
        }
    }

    function getMainnetEthConfig() public view returns (NetworkConfig memory mainnetNetworkConfig) {
        address[] memory mainnetPriceFeeds = new address[](2);
        mainnetPriceFeeds[0] = WETH_MAINNET_PRICE_FEED_ADDRESS;
        mainnetPriceFeeds[1] = WBTC_MAINNET_PRICE_FEED_ADDRESS;
        address[] memory mainnetTokens = new address[](2);
        mainnetTokens[0] = WETH_MAINNET_ADDRESS;
        mainnetTokens[1] = WBTC_MAINNET_ADDRESS;
        mainnetNetworkConfig = NetworkConfig({
            priceFeeds: mainnetPriceFeeds, tokens: mainnetTokens, account: vm.envAddress("DEFAULT_KEY_ADDRESS")
        });

        // mainnetNetworkConfig.tokens.push(WETH_MAINNET_ADDRESS);
        // mainnetNetworkConfig.tokens.push(WBTC_MAINNET_ADDRESS);
        // mainnetNetworkConfig.priceFeeds.push(WETH_MAINNET_PRICE_FEED_ADDRESS);
        // mainnetNetworkConfig.priceFeeds.push(WBTC_MAINNET_PRICE_FEED_ADDRESS);
        // mainnetNetworkConfig.account = vm.envAddress("DEFAULT_KEY_ADDRESS");

        // mainnetNetworkConfig = NetworkConfig({
        //     wethUsdPriceFeed: ,
        //     wbtcUsdPriceFeed: ,
        //     weth: ,
        //     wbtc: ,
        //     account: vm.envAddress("DEFAULT_KEY_ADDRESS")
        // });
    }

    function getSepoliaEthConfig() public view returns (NetworkConfig memory sepoliaNetworkConfig) {
        address[] memory sepoliaPriceFeeds = new address[](2);
        sepoliaPriceFeeds[0] = WETH_SEPOLIA_PRICE_FEED_ADDRESS;
        sepoliaPriceFeeds[1] = WBTC_SEPOLIA_PRICE_FEED_ADDRESS;
        address[] memory sepoliaTokens = new address[](2);
        sepoliaTokens[0] = WETH_SEPOLIA_ADDRESS;
        sepoliaTokens[1] = WBTC_SEPOLIA_ADDRESS;
        sepoliaNetworkConfig = NetworkConfig({
            priceFeeds: sepoliaPriceFeeds, tokens: sepoliaTokens, account: vm.envAddress("DEFAULT_KEY_ADDRESS")
        });

        // sepoliaNetworkConfig = NetworkConfig({
        //     wethUsdPriceFeed: ,
        //     wbtcUsdPriceFeed: ,
        //     weth: ,
        //     wbtc: ,
        //     account: vm.envAddress("DEFAULT_KEY_ADDRESS")
        // });
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory localNetworkConfig) {
        // // Check to see if we set an active network config
        // if (localNetworkConfig.wethUsdPriceFeed != address(0)) {
        //     return localNetworkConfig;
        // }
        // vm.startBroadcast();
        // // deploy and initialize mocks
        // // create mock price feeds
        address WETH_ANVIL_PRICE_FEED_ADDRESS = address(1);
        address WBTC_ANVIL_PRICE_FEED_ADDRESS = address(1);
        address WETH_ANVIL_ADDRESS = address(1);
        address WBTC_ANVIL_ADDRESS = address(1);
        // vm.stopBroadcast();

        address[] memory anvilPriceFeeds = new address[](2);
        anvilPriceFeeds[0] = WETH_ANVIL_PRICE_FEED_ADDRESS;
        anvilPriceFeeds[1] = WBTC_ANVIL_PRICE_FEED_ADDRESS;
        address[] memory anvilTokens = new address[](2);
        anvilTokens[0] = WETH_ANVIL_ADDRESS;
        anvilTokens[1] = WBTC_ANVIL_ADDRESS;
        localNetworkConfig = NetworkConfig({
            priceFeeds: anvilPriceFeeds, tokens: anvilTokens, account: vm.envAddress("DEFAULT_KEY_ADDRESS")
        });

        // localNetworkConfig = NetworkConfig({
        //     wethUsdPriceFeed: ,
        //     wbtcUsdPriceFeed: ,
        //     weth: ,
        //     wbtc: ,
        //     account: DEFAULT_SENDER
        // });
    }
}
