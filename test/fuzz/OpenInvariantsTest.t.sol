// SPDX-License-Identifier: MIT

// what are the invariants?
// 1. The total amount of DSC should always be less than the total value of collateral
// 2. Getter functions should never revert

pragma solidity ^0.8.19;

// import {DeployDSC} from "../../script/DeployDSC.s.sol";
// import {CodeConstants, HelperConfig} from "../../script/HelperConfig.s.sol";
// import {DSCEngine} from "../../src/DSCEngine.sol";
// import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
// import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import {StdInvariant} from "forge-std/StdInvariant.sol";
// import {Test, console} from "forge-std/Test.sol";

// contract OpenInvariantTest is StdInvariant, Test {
//     DeployDSC deployer;
//     DSCEngine dscEngine;
//     DecentralizedStableCoin dsc;
//     HelperConfig config;
//     address weth;
//     address wbtc;

//     function setUp() external {
//         deployer = new DeployDSC();
//         (dsc, dscEngine, config) = deployer.run();
//         (,, weth, wbtc,) = config.activeNetworkConfig();
//         targetContract(address(dscEngine));
//     }

//     function invariant_protocolMustHaveMoreCollateralValueThanTotalDscSupply() public view {
//         // get the value of all collateral in the protocol
//         uint256 totalWethDeposited = IERC20(weth).balanceOf(address(dscEngine));
//         uint256 totalWbtcDeposited = IERC20(wbtc).balanceOf(address(dscEngine));
//         uint256 totalWethValue = dscEngine.getUsdValue(weth, totalWethDeposited);
//         uint256 totalWbtcValue = dscEngine.getUsdValue(wbtc, totalWbtcDeposited);
//         uint256 totalDepositedValue = totalWethValue + totalWbtcValue;
//         // compare it to the total amount of DSC minted
//         uint256 totalDscSupply = dsc.totalSupply();
//         assert(totalDepositedValue >= totalDscSupply);
//     }
// }

