// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
// import {DeployDSC} from "../../script/DeployDSC.s.sol";
// import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";

contract DecentralizedStableCoinTest is Test {
    DecentralizedStableCoin public dsc;
    // DeployDSC public deployer;
    // HelperConfig public helperConfig

    address user = makeAddr("user");
    address user2 = makeAddr("user2");

    // uint256 startingUserBalance = ;

    function setUp() external {
        dsc = new DecentralizedStableCoin();
    }
}
