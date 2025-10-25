// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";

contract DecentralizedStableCoinTest is Test {
    DecentralizedStableCoin public dsc;
    DeployDSC public deployer;
    HelperConfig public helperConfig;
    HelperConfig.NetworkConfig public config;

    // address user = madeAddr("user");
    // address user2 = makeAddr("user2");

    function setUp() external {
        deployer = new DeployDSC();
        (dsc, helperConfig) = deployer.run();
        config = helperConfig.getConfig();
    }
}
