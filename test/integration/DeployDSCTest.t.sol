// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {CodeConstants, HelperConfig} from "../../script/HelperConfig.s.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {Test} from "forge-std/Test.sol";

contract DecentralizedStableCoinTest is Test, CodeConstants {
    DeployDSC public deployer;
    DSCEngine public dscEngine;
    HelperConfig public helperConfig;
    DecentralizedStableCoin public dsc;
    address public ethUsdPriceFeed;
    address public btcUsdPriceFeed;
    address public weth;
    address public wbtc;
    address public account;

    function setUp() external {
        deployer = new DeployDSC();
        (dsc, dscEngine, helperConfig) = deployer.run();
        (ethUsdPriceFeed, btcUsdPriceFeed, weth, wbtc, account) = helperConfig.activeNetworkConfig();
    }

    /*//////////////////////////////////////////////////////////////
                           INITIAL DSC STATE
    //////////////////////////////////////////////////////////////*/

    function testDscNameWasSetCorrectly() external view {
        assertEq(dsc.name(), DSC_NAME);
    }

    function testDscSymbolWasSetCorrectly() external view {
        assertEq(dsc.symbol(), DSC_SYMBOL);
    }

    function testDscOwnerWasSetCorrectly() external view {
        assertEq(dsc.owner(), address(dscEngine));
    }

    /*//////////////////////////////////////////////////////////////
                       INITIAL DSC ENGINE STATE
    //////////////////////////////////////////////////////////////*/

    function testDscEngineEthUsdPriceFeedWasSetCorrectly() external view {
        assert(dscEngine.getPriceFeedAddress(weth) != address(0));
        assertEq(dscEngine.getPriceFeedAddress(weth), ethUsdPriceFeed);
    }

    function testDscEngineBtcUsdPriceFeedWasSetCorrectly() external view {
        assert(dscEngine.getPriceFeedAddress(wbtc) != address(0));
        assertEq(dscEngine.getPriceFeedAddress(wbtc), btcUsdPriceFeed);
    }

    function testGetDecentralizedStableCoin() external view {
        assertEq(dscEngine.getDecentralizedStableCoin(), address(dsc));
    }
}

contract DecentralizedStableCoinTest_ethMainnet is Test, CodeConstants {
    DeployDSC public deployer;
    DSCEngine public dscEngine;
    HelperConfig public helperConfig;
    address public ethUsdPriceFeed;
    address public btcUsdPriceFeed;
    address public weth;
    address public wbtc;
    address public account;

    function setUp() external {
        vm.createSelectFork(vm.envString("ETH_MAINNET_RPC_URL"));
        deployer = new DeployDSC();
        (, dscEngine, helperConfig) = deployer.run();
        (ethUsdPriceFeed, btcUsdPriceFeed, weth, wbtc, account) = helperConfig.activeNetworkConfig();
    }

    /*//////////////////////////////////////////////////////////////
                       INITIAL DSC ENGINE STATE
    //////////////////////////////////////////////////////////////*/

    function testDscEngineEthUsdPriceFeedWasSetCorrectly() external view {
        assert(dscEngine.getPriceFeedAddress(weth) != address(0));
        assertEq(dscEngine.getPriceFeedAddress(weth), ethUsdPriceFeed);
    }

    function testDscEngineBtcUsdPriceFeedWasSetCorrectly() external view {
        assert(dscEngine.getPriceFeedAddress(wbtc) != address(0));
        assertEq(dscEngine.getPriceFeedAddress(wbtc), btcUsdPriceFeed);
    }
}

contract DecentralizedStableCoinTest_ethSepolia is Test, CodeConstants {
    DeployDSC public deployer;
    DSCEngine public dscEngine;
    HelperConfig public helperConfig;
    address public ethUsdPriceFeed;
    address public btcUsdPriceFeed;
    address public weth;
    address public wbtc;
    address public account;

    function setUp() external {
        vm.createSelectFork(vm.envString("ETH_SEPOLIA_RPC_URL"));
        deployer = new DeployDSC();
        (, dscEngine, helperConfig) = deployer.run();
        (ethUsdPriceFeed, btcUsdPriceFeed, weth, wbtc, account) = helperConfig.activeNetworkConfig();
    }

    /*//////////////////////////////////////////////////////////////
                       INITIAL DSC ENGINE STATE
    //////////////////////////////////////////////////////////////*/

    function testDscEngineEthUsdPriceFeedWasSetCorrectly() external view {
        assert(dscEngine.getPriceFeedAddress(weth) != address(0));
        assertEq(dscEngine.getPriceFeedAddress(weth), ethUsdPriceFeed);
    }

    function testDscEngineBtcUsdPriceFeedWasSetCorrectly() external view {
        assert(dscEngine.getPriceFeedAddress(wbtc) != address(0));
        assertEq(dscEngine.getPriceFeedAddress(wbtc), btcUsdPriceFeed);
    }
}

contract DecentralizedStableCoinTest_arbMainnet is Test, CodeConstants {
    DeployDSC public deployer;
    DSCEngine public dscEngine;
    HelperConfig public helperConfig;
    address public ethUsdPriceFeed;
    address public btcUsdPriceFeed;
    address public weth;
    address public wbtc;
    address public account;

    function setUp() external {
        vm.createSelectFork(vm.envString("ARB_MAINNET_RPC_URL"));
        deployer = new DeployDSC();
        (, dscEngine, helperConfig) = deployer.run();
        (ethUsdPriceFeed, btcUsdPriceFeed, weth, wbtc, account) = helperConfig.activeNetworkConfig();
    }

    /*//////////////////////////////////////////////////////////////
                       INITIAL DSC ENGINE STATE
    //////////////////////////////////////////////////////////////*/

    function testDscEngineEthUsdPriceFeedWasSetCorrectly() external view {
        assert(dscEngine.getPriceFeedAddress(weth) != address(0));
        assertEq(dscEngine.getPriceFeedAddress(weth), ethUsdPriceFeed);
    }

    function testDscEngineBtcUsdPriceFeedWasSetCorrectly() external view {
        assert(dscEngine.getPriceFeedAddress(wbtc) != address(0));
        assertEq(dscEngine.getPriceFeedAddress(wbtc), btcUsdPriceFeed);
    }
}

contract DecentralizedStableCoinTest_arbSepolia is Test, CodeConstants {
    DeployDSC public deployer;
    DSCEngine public dscEngine;
    HelperConfig public helperConfig;
    address public ethUsdPriceFeed;
    address public btcUsdPriceFeed;
    address public weth;
    address public wbtc;
    address public account;

    function setUp() external {
        vm.createSelectFork(vm.envString("ARB_SEPOLIA_RPC_URL"));
        deployer = new DeployDSC();
        (, dscEngine, helperConfig) = deployer.run();
        (ethUsdPriceFeed, btcUsdPriceFeed, weth, wbtc, account) = helperConfig.activeNetworkConfig();
    }

    /*//////////////////////////////////////////////////////////////
                       INITIAL DSC ENGINE STATE
    //////////////////////////////////////////////////////////////*/

    function testDscEngineEthUsdPriceFeedWasSetCorrectly() external view {
        assert(dscEngine.getPriceFeedAddress(weth) != address(0));
        assertEq(dscEngine.getPriceFeedAddress(weth), ethUsdPriceFeed);
    }

    function testDscEngineBtcUsdPriceFeedWasSetCorrectly() external view {
        assert(dscEngine.getPriceFeedAddress(wbtc) != address(0));
        assertEq(dscEngine.getPriceFeedAddress(wbtc), btcUsdPriceFeed);
    }
}
