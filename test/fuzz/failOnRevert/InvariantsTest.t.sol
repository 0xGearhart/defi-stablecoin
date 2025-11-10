// SPDX-License-Identifier: MIT

// what are the invariants?
// 1. The total amount of DSC should always be less than the total value of collateral
// 2. Getter functions should never revert

pragma solidity ^0.8.19;

import {DeployDSC} from "../../../script/DeployDSC.s.sol";
import {CodeConstants, HelperConfig} from "../../../script/HelperConfig.s.sol";
import {DSCEngine} from "../../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../../src/DecentralizedStableCoin.sol";
import {Handler} from "./Handler.t.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {Test, console} from "forge-std/Test.sol";

contract InvariantTest is StdInvariant, Test {
    DeployDSC deployer;
    DSCEngine dscEngine;
    DecentralizedStableCoin dsc;
    HelperConfig config;
    Handler handler;
    address weth;
    address wbtc;

    function setUp() external {
        deployer = new DeployDSC();
        (dsc, dscEngine, config) = deployer.run();
        (,, weth, wbtc,) = config.activeNetworkConfig();
        handler = new Handler(dscEngine, dsc);

        // would make dscEngine target contract in open invariant testing but need to set target contract to handler address if we want our calls to be made in a sensible order (deposit => mint => burn => withdraw)
        // targetContract(address(dscEngine));

        // using a handler like this makes it less random but gives us more valid calls
        targetContract(address(handler));
    }

    function invariant_protocolMustHaveMoreCollateralValueThanTotalDscSupply() public view {
        // get the value of all collateral in the protocol
        uint256 totalWethDeposited = IERC20(weth).balanceOf(address(dscEngine));
        uint256 totalWbtcDeposited = IERC20(wbtc).balanceOf(address(dscEngine));
        uint256 totalWethValue = dscEngine.getUsdValue(weth, totalWethDeposited);
        uint256 totalWbtcValue = dscEngine.getUsdValue(wbtc, totalWbtcDeposited);
        uint256 totalDepositedValue = totalWethValue + totalWbtcValue;

        // get total amount of DSC minted
        uint256 totalDscSupply = dsc.totalSupply();

        console.log("total weth value: ", totalWethValue);
        console.log("total wbtc value: ", totalWbtcValue);
        console.log("DSC total supply: ", totalDscSupply);
        console.log("Times Mint Called Successfully: : ", handler.timesMintCalled());
        console.log("Times Deposit Called Successfully: : ", handler.timesDepositCalled());
        console.log("Times Redeem Called Successfully: : ", handler.timesRedeemCalled());
        console.log("Times Burn Called Successfully: : ", handler.timesBurnCalled());
        console.log("Times Liquidate Called Successfully: : ", handler.timesLiquidateCalled());
        console.log("Times DepositAndMint Called Successfully: : ", handler.timesDepositAndMintCalled());

        // compare value to the total amount of DSC minted
        assert(totalDepositedValue >= totalDscSupply);
    }

    function invariant_gettersShouldNeverRevert() public view {
        dscEngine.getCollateralTokenAddresses();
        dscEngine.getMinHealthFactor();
        dscEngine.getPrecision();
        dscEngine.getAdditionalPriceFeedPrecision();
        dscEngine.getLiquidationBonus();
        dscEngine.getLiquidationThreshold();
        dscEngine.getLiquidationPrecision();
        // dscEngine.getAccountInformation(address);
        // dscEngine.getHealthFactor(address);
        // dscEngine.getPriceFeedAddress(address);
        // dscEngine.getAccountCollateralBalance(address, uint256);
        // dscEngine.getTokenAmountFromUsd(address, uint256);
        // dscEngine.getAccountCollateralValueInUsd(address);
        // dscEngine.getUsdValue(address, uint256);
    }
}
