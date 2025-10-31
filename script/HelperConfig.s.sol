// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {MockV3Aggregator} from "../test/mocks/MockV3Aggregator.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

abstract contract CodeConstants {
    // DSC name and symbol
    string public constant DSC_NAME = "DecentralizedStableCoin";
    string public constant DSC_SYMBOL = "DSC";
    // mainnet chain id and info
    uint256 public constant ETH_MAINNET_CHAIN_ID = 1;
    address public constant WETH_MAINNET_ADDRESS = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant WETH_MAINNET_PRICE_FEED_ADDRESS = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
    address public constant WBTC_MAINNET_ADDRESS = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    address public constant WBTC_MAINNET_PRICE_FEED_ADDRESS = 0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c;
    // sepolia chain id and info
    uint256 public constant ETH_SEPOLIA_CHAIN_ID = 11155111;
    address public constant WETH_SEPOLIA_ADDRESS = 0xdd13E55209Fd76AfE204dBda4007C227904f0a81;
    address public constant WETH_SEPOLIA_PRICE_FEED_ADDRESS = 0x694AA1769357215DE4FAC081bf1f309aDC325306;
    address public constant WBTC_SEPOLIA_ADDRESS = 0x7079A35DAAa3fEc63F52496CAbBFac0f9D5beB28;
    address public constant WBTC_SEPOLIA_PRICE_FEED_ADDRESS = 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43;
    // local chain id and info
    uint256 public constant LOCAL_CHAIN_ID = 31337;
    // mock initialize info
    uint8 public constant DECIMALS = 8;
    int256 public constant MOCK_ETH_USD_PRICE = 2000e8;
    int256 public constant MOCK_BTC_USD_PRICE = 1000e8;
    uint256 public constant INITIAL_MOCK_BALANCE = 1000e8;
}

contract HelperConfig is Script, CodeConstants {
    NetworkConfig public activeNetworkConfig;

    struct NetworkConfig {
        address ethUsdPriceFeed;
        address btcUsdPriceFeed;
        address weth;
        address wbtc;
        address account;
    }

    constructor() {
        if (block.chainid == ETH_MAINNET_CHAIN_ID) {
            activeNetworkConfig = getMainnetEthConfig();
        } else if (block.chainid == ETH_SEPOLIA_CHAIN_ID) {
            activeNetworkConfig = getSepoliaEthConfig();
        } else {
            activeNetworkConfig = getOrCreateAnvilEthConfig();
        }
    }

    function getMainnetEthConfig() public view returns (NetworkConfig memory) {
        return NetworkConfig({
            ethUsdPriceFeed: WETH_MAINNET_PRICE_FEED_ADDRESS,
            btcUsdPriceFeed: WBTC_MAINNET_PRICE_FEED_ADDRESS,
            weth: WETH_MAINNET_ADDRESS,
            wbtc: WBTC_MAINNET_ADDRESS,
            account: vm.envAddress("DEFAULT_KEY_ADDRESS")
        });
    }

    function getSepoliaEthConfig() public view returns (NetworkConfig memory) {
        return NetworkConfig({
            ethUsdPriceFeed: WETH_SEPOLIA_PRICE_FEED_ADDRESS,
            btcUsdPriceFeed: WBTC_SEPOLIA_PRICE_FEED_ADDRESS,
            weth: WETH_SEPOLIA_ADDRESS,
            wbtc: WBTC_SEPOLIA_ADDRESS,
            account: vm.envAddress("DEFAULT_KEY_ADDRESS")
        });
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        // Check to see if we set an active network config
        if (activeNetworkConfig.ethUsdPriceFeed != address(0)) {
            return activeNetworkConfig;
        }
        // deploy and initialize mocks
        vm.startBroadcast();
        // create mock weth and weth price feed
        MockV3Aggregator ethUsdPriceFeed = new MockV3Aggregator(DECIMALS, MOCK_ETH_USD_PRICE);
        // ERC20Mock wethMock = new ERC20Mock("WETH", "WETH", msg.sender, INITIAL_MOCK_BALANCE);
        ERC20Mock wethMock = new ERC20Mock();
        // create mock wbtc and wbtc price feed
        MockV3Aggregator btcUsdPriceFeed = new MockV3Aggregator(DECIMALS, MOCK_BTC_USD_PRICE);
        // ERC20Mock wbtcMock = new ERC20Mock("WBTC", "WBTC", msg.sender, INITIAL_MOCK_BALANCE);
        ERC20Mock wbtcMock = new ERC20Mock();
        vm.stopBroadcast();

        return NetworkConfig({
            ethUsdPriceFeed: address(ethUsdPriceFeed),
            btcUsdPriceFeed: address(btcUsdPriceFeed),
            weth: address(wethMock),
            wbtc: address(wbtcMock),
            account: DEFAULT_SENDER
        });
    }
}
