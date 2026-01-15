// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {MockV3Aggregator} from "../test/mocks/MockV3Aggregator.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {Script, console2} from "forge-std/Script.sol";

abstract contract CodeConstants {
    // DSC name and symbol
    string public constant DSC_NAME = "DecentralizedStableCoin";
    string public constant DSC_SYMBOL = "DSC";

    // eth mainnet chain id and info
    uint256 public constant ETH_MAINNET_CHAIN_ID = 1;
    address public constant WETH_ETH_MAINNET_ADDRESS = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant WETH_ETH_MAINNET_PRICE_FEED_ADDRESS = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
    address public constant WBTC_ETH_MAINNET_ADDRESS = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    address public constant WBTC_ETH_MAINNET_PRICE_FEED_ADDRESS = 0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c;
    // eth sepolia chain id and info
    uint256 public constant ETH_SEPOLIA_CHAIN_ID = 11_155_111;
    address public constant WETH_ETH_SEPOLIA_ADDRESS = 0xdd13E55209Fd76AfE204dBda4007C227904f0a81;
    address public constant WETH_ETH_SEPOLIA_PRICE_FEED_ADDRESS = 0x694AA1769357215DE4FAC081bf1f309aDC325306;
    address public constant WBTC_ETH_SEPOLIA_ADDRESS = 0x7079A35DAAa3fEc63F52496CAbBFac0f9D5beB28;
    address public constant WBTC_ETH_SEPOLIA_PRICE_FEED_ADDRESS = 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43;

    // arb mainnet chain id and info
    uint256 public constant ARB_MAINNET_CHAIN_ID = 42_161;
    address public constant WETH_ARB_MAINNET_ADDRESS = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address public constant WETH_ARB_MAINNET_PRICE_FEED_ADDRESS = 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612;
    address public constant WBTC_ARB_MAINNET_ADDRESS = 0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f;
    address public constant WBTC_ARB_MAINNET_PRICE_FEED_ADDRESS = 0xd0C7101eACbB49F3deCcCc166d238410D6D46d57;
    // arb sepolia chain id and info
    uint256 public constant ARB_SEPOLIA_CHAIN_ID = 421_614;
    address public constant WETH_ARB_SEPOLIA_ADDRESS = 0x980B62Da83eFf3D4576C647993b0c1D7faf17c73;
    address public constant WETH_ARB_SEPOLIA_PRICE_FEED_ADDRESS = 0xd30e2101a97dcbAeBCBC04F14C3f624E67A35165;
    address public constant WBTC_ARB_SEPOLIA_ADDRESS = 0x57A618Ab6e7abDdCD9A417F078d1958099DaC8b6;
    address public constant WBTC_ARB_SEPOLIA_PRICE_FEED_ADDRESS = 0x56a43EB56Da12C0dc1D972ACb089c06a5dEF8e69;

    // local chain id and info
    uint256 public constant LOCAL_CHAIN_ID = 31_337;
    // mock initialize info
    uint8 public constant DECIMALS = 8;
    int256 public constant MOCK_ETH_USD_PRICE = 2000e8;
    int256 public constant MOCK_BTC_USD_PRICE = 1000e8;
    uint256 public constant INITIAL_MOCK_BALANCE = 1000e8;
}

contract HelperConfig is Script, CodeConstants {
    error HelperConfig__InvalidChainId();

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
            activeNetworkConfig = getEthMainnetConfig();
        } else if (block.chainid == ARB_MAINNET_CHAIN_ID) {
            activeNetworkConfig = getArbMainnetConfig();
        } else if (block.chainid == ETH_SEPOLIA_CHAIN_ID) {
            activeNetworkConfig = getEthSepoliaConfig();
        } else if (block.chainid == ARB_SEPOLIA_CHAIN_ID) {
            activeNetworkConfig = getArbSepoliaConfig();
        } else if (block.chainid == LOCAL_CHAIN_ID) {
            activeNetworkConfig = getOrCreateAnvilEthConfig();
        } else {
            revert HelperConfig__InvalidChainId();
        }
    }

    function getEthMainnetConfig() public view returns (NetworkConfig memory) {
        return NetworkConfig({
            ethUsdPriceFeed: WETH_ETH_MAINNET_PRICE_FEED_ADDRESS,
            btcUsdPriceFeed: WBTC_ETH_MAINNET_PRICE_FEED_ADDRESS,
            weth: WETH_ETH_MAINNET_ADDRESS,
            wbtc: WBTC_ETH_MAINNET_ADDRESS,
            account: vm.envAddress("DEFAULT_KEY_ADDRESS")
        });
    }

    function getEthSepoliaConfig() public view returns (NetworkConfig memory) {
        return NetworkConfig({
            ethUsdPriceFeed: WETH_ETH_SEPOLIA_PRICE_FEED_ADDRESS,
            btcUsdPriceFeed: WBTC_ETH_SEPOLIA_PRICE_FEED_ADDRESS,
            weth: WETH_ETH_SEPOLIA_ADDRESS,
            wbtc: WBTC_ETH_SEPOLIA_ADDRESS,
            account: vm.envAddress("DEFAULT_KEY_ADDRESS")
        });
    }

    function getArbMainnetConfig() public view returns (NetworkConfig memory) {
        return NetworkConfig({
            ethUsdPriceFeed: WETH_ARB_MAINNET_PRICE_FEED_ADDRESS,
            btcUsdPriceFeed: WBTC_ARB_MAINNET_PRICE_FEED_ADDRESS,
            weth: WETH_ARB_MAINNET_ADDRESS,
            wbtc: WBTC_ARB_MAINNET_ADDRESS,
            account: vm.envAddress("DEFAULT_KEY_ADDRESS")
        });
    }

    function getArbSepoliaConfig() public view returns (NetworkConfig memory) {
        return NetworkConfig({
            ethUsdPriceFeed: WETH_ARB_SEPOLIA_PRICE_FEED_ADDRESS,
            btcUsdPriceFeed: WBTC_ARB_SEPOLIA_PRICE_FEED_ADDRESS,
            weth: WETH_ARB_SEPOLIA_ADDRESS,
            wbtc: WBTC_ARB_SEPOLIA_ADDRESS,
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
