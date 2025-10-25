// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {DecentralizedStableCoin} from "../src/DecentralizedStableCoin.sol";

contract DeployDSC is Script {
    function run() external returns (DecentralizedStableCoin, HelperConfig) {
        return deployContract();
    }

    function deployContract()
        public
        returns (DecentralizedStableCoin dsc, HelperConfig helperConfig)
    {
        helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory currentConfig = helperConfig
            .getConfig();

        vm.startBroadcast(currentConfig.account);
        dsc = new DecentralizedStableCoin();
        vm.stopBroadcast();
    }
}
