// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";

// import { ERC20Mock } from "../test/mocks/ERC20Mock.sol";
// import { MockV3Aggregator } from "../test/mocks/MockV3Aggregator.sol";

contract HelperConfig is Script {
    error HelperConfig__InvalidChainId(uint256 chainId);

    NetworkConfig public localNetworkConfig;

    // chain ids
    uint256 public constant LOCAL_CHAIN_ID = 31337;
    uint256 public constant ETH_MAINNET_CHAIN_ID = 1;
    uint256 public constant ETH_SEPOLIA_CHAIN_ID = 11155111;
    // mock initialize info
    uint8 public constant DECIMALS = 8;
    int256 public constant ETH_USD_PRICE = 2000e8;
    int256 public constant BTC_USD_PRICE = 1000e8;

    mapping(uint256 => NetworkConfig) private networkConfigs;

    struct NetworkConfig {
        address wethUsdPriceFeed;
        address wbtcUsdPriceFeed;
        address weth;
        address wbtc;
        address account;
    }

    constructor() {
        networkConfigs[ETH_MAINNET_CHAIN_ID] = getMainnetEthConfig();
        networkConfigs[ETH_SEPOLIA_CHAIN_ID] = getSepoliaEthConfig();
    }

    function getConfig() public returns (NetworkConfig memory) {
        if (networkConfigs[block.chainid].wethUsdPriceFeed != address(0)) {
            return networkConfigs[block.chainid];
        } else if (block.chainid == LOCAL_CHAIN_ID) {
            return getOrCreateAnvilEthConfig();
        } else {
            revert HelperConfig__InvalidChainId(block.chainid);
        }
    }

    function getMainnetEthConfig()
        public
        view
        returns (NetworkConfig memory mainnetNetworkConfig)
    {
        // mainnetNetworkConfig = NetworkConfig({
        //     wethUsdPriceFeed: ,
        //     wbtcUsdPriceFeed: ,
        //     weth: ,
        //     wbtc: ,
        //     account: vm.envAddress("DEFAULT_KEY_ADDRESS")
        // });
    }

    function getSepoliaEthConfig()
        public
        view
        returns (NetworkConfig memory sepoliaNetworkConfig)
    {
        // sepoliaNetworkConfig = NetworkConfig({
        //     wethUsdPriceFeed: ,
        //     wbtcUsdPriceFeed: ,
        //     weth: ,
        //     wbtc: ,
        //     account: vm.envAddress("DEFAULT_KEY_ADDRESS")
        // });
    }

    function getOrCreateAnvilEthConfig()
        public
        returns (NetworkConfig memory anvilNetworkConfig)
    {
        // // Check to see if we set an active network config
        // if (localNetworkConfig.wethUsdPriceFeed != address(0)) {
        //     return localNetworkConfig;
        // }
        // vm.startBroadcast();
        // // deploy and initialize mocks
        // vm.stopBroadcast();
        // localNetworkConfig = NetworkConfig({
        //     wethUsdPriceFeed: ,
        //     wbtcUsdPriceFeed: ,
        //     weth: ,
        //     wbtc: ,
        //     account: DEFAULT_SENDER
        // });
    }
}
