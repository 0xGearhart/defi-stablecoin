// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";

contract DecentralizedStableCoinTest is Test {
    DeployDSC public deployer;
    HelperConfig public helperConfig;
    DecentralizedStableCoin public dsc;
    HelperConfig.NetworkConfig public config;

    function setUp() external {
        deployer = new DeployDSC();
        (dsc, helperConfig) = deployer.run();
        config = helperConfig.getConfig();
    }

    /*//////////////////////////////////////////////////////////////
                           INITIAL DSC STATE
    //////////////////////////////////////////////////////////////*/

    function testDscNameWasSetCorrectly() external {
        assertEq(dsc.name(), );
    }

    function testDscSymbolWasSetCorrectly() external {
        assertEq(dsc.symbol(), );
    }

    function testDscOwnerWasSetCorrectly() external {}

    /*//////////////////////////////////////////////////////////////
                       INITIAL DSC ENGINE STATE
    //////////////////////////////////////////////////////////////*/

    function testDscEngineWethUsdPriceFeedWasSetCorrectly() external {}

    function testDscEngineWbtcUsdPriceFeedWasSetCorrectly() external {}

    function testDscEngineWethAddressWasSetCorrectly() external {}

    function testDscEngineWbtcAddressWasSetCorrectly() external {}
}
