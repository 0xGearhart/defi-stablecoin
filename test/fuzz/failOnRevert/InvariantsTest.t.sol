// SPDX-License-Identifier: MIT

// what are the invariants?
// 1. The total amount of DSC should always be less than the total value of collateral
// 2. Getter functions should never revert
// 3. Users should never be able to withdraw more than the deposited (excluding liquidation bonuses)
// 4. Users with broken health factors should be liquidate-able
// 5. Users with good health factors should never be liquidated

pragma solidity 0.8.33;

import {DeployDSC} from "../../../script/DeployDSC.s.sol";
import {HelperConfig} from "../../../script/HelperConfig.s.sol";
import {DSCEngine} from "../../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../../src/DecentralizedStableCoin.sol";
import {Handler} from "./Handler.t.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {Test, console2} from "forge-std/Test.sol";

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

        console2.log("total weth value: ", totalWethValue);
        console2.log("total wbtc value: ", totalWbtcValue);
        console2.log("DSC total supply: ", totalDscSupply);
        console2.log("Times Mint Called Successfully: : ", handler.timesMintCalled());
        console2.log("Times Deposit Called Successfully: : ", handler.timesDepositCalled());
        console2.log("Times Redeem Called Successfully: : ", handler.timesRedeemCalled());
        console2.log("Times Burn Called Successfully: : ", handler.timesBurnCalled());
        console2.log("Times Liquidate Called Successfully: : ", handler.timesLiquidateCalled());
        console2.log("Times DepositAndMint Called Successfully: : ", handler.timesDepositAndMintCalled());

        // compare value to the total amount of DSC minted
        assert(totalDepositedValue >= totalDscSupply);
    }

    // ToDo: finish this invariant
    function invariant_userShouldNeverWithdrawMoreThanWhatTheyDeposit() public view {
        // ToDo: get deposits and withdraws from handler address and run asserts to verify invariant
    }

    // ToDo: finish this invariant. think if liquidations would change this or not
    function invariant_dscEngineCollateralBalancesShouldEqualTotalDeposits/*WithoutLiquidations?*/ () public view {
        // ToDo: get individual balances from a mapping in handler contract and iterate over amounts to verify against ending contract balances
    }

    // ToDo: get variables from handler contract so all view functions can be uncommented and included
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

// ToDo: maybe a second separate contract with a different handler for testing liquidations without breaking other invariants?
// maybe there is a better way to integrate liquidation testing into the contract above instead but that will take some research
// contract InvariantLiquidationTest is StdInvariant, Test {
//     DeployDSC deployer;
//     DSCEngine dscEngine;
//     DecentralizedStableCoin dsc;
//     HelperConfig config;
//     LiquidationHandler handler;
//     address weth;
//     address wbtc;

//     function setUp() external {
//         deployer = new DeployDSC();
//         (dsc, dscEngine, config) = deployer.run();
//         (,, weth, wbtc,) = config.activeNetworkConfig();
//         handler = new LiquidationHandler(dscEngine, dsc);

//         targetContract(address(handler));
//     }

//     // ToDo: finish this invariant
//     function invariant_accountsWithBrokenHealthFactorsCanBeLiquidated() public view {}
// }
