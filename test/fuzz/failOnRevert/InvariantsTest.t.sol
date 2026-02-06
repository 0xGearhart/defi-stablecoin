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

        // using a handler makes it less random but gives us more valid calls
        targetContract(address(handler));

        bytes4[] memory selectors = new bytes4[](7);
        selectors[0] = Handler.depositCollateral.selector;
        selectors[1] = Handler.redeemCollateral.selector;
        selectors[2] = Handler.mintDsc.selector;
        selectors[3] = Handler.burnDsc.selector;
        selectors[4] = Handler.depositCollateralAndMintDsc.selector;
        selectors[5] = Handler.redeemCollateralForDsc.selector;
        selectors[6] = handler.attemptToLiquidateHealthyAccount.selector;

        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
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
        console2.log("Times RedeemAndBurn Called Successfully: : ", handler.timesRedeemAndBurnCalled());
        console2.log(
            "Times AttemptToLiquidateHealthyAccount Called Successfully: : ",
            handler.timesAttemptToLiquidateHealthyAccountCalled()
        );

        // compare value to the total amount of DSC minted
        assert(totalDepositedValue >= totalDscSupply);
    }

    function invariant_dscEngineCollateralBalancesShouldEqualTotalDeposits() public view {
        // get deposits from ghost variable
        uint256 totalWethDeposits = handler.totalDeposits(weth);
        uint256 totalWbtcDeposits = handler.totalDeposits(wbtc);
        // get actual ERC20 balances
        uint256 totalWethBalance = IERC20(weth).balanceOf(address(dscEngine));
        uint256 totalWbtcBalance = IERC20(wbtc).balanceOf(address(dscEngine));
        // assert invariant held
        assertEq(totalWethDeposits, totalWethBalance);
        assertEq(totalWbtcDeposits, totalWbtcBalance);
    }

    function invariant_userShouldNeverWithdrawMoreThanWhatTheyDeposit() public view {
        uint256 userCount = handler.getUsersEverDepositedCount();
        address[] memory collateralTokens = dscEngine.getCollateralTokenAddresses();
        for (uint256 i = 0; i < userCount; i++) {
            address user = handler.getUsersEverDepositedAt(i);
            for (uint256 j = 0; j < collateralTokens.length; j++) {
                address collateral = collateralTokens[j];
                uint256 deposited = handler.userDeposits(user, collateral);
                uint256 withdrawn = handler.userWithdrawals(user, collateral);
                assert(withdrawn <= deposited);
            }
        }
    }

    function invariant_gettersShouldNeverRevert() public view {
        dscEngine.getCollateralTokenAddresses();
        dscEngine.getMinHealthFactor();
        dscEngine.getPrecision();
        dscEngine.getAdditionalPriceFeedPrecision();
        dscEngine.getLiquidationBonus();
        dscEngine.getLiquidationThreshold();
        dscEngine.getLiquidationPrecision();
        address[] memory collateralTokens = dscEngine.getCollateralTokenAddresses();
        for (uint256 i = 0; i < collateralTokens.length; i++) {
            address collateral = collateralTokens[i];
            dscEngine.getPriceFeedAddress(collateral);
            uint256 tokenUnit = handler.getTokenUnit(collateral);
            dscEngine.getUsdValue(collateral, tokenUnit);
            dscEngine.getTokenAmountFromUsd(collateral, 1e18);
        }

        uint256 depositedCount = handler.getUsersWithCollateralDepositedCount();
        for (uint256 i = 0; i < depositedCount; i++) {
            address user = handler.getUsersWithCollateralDepositedAt(i);
            dscEngine.getAccountInformation(user);
            dscEngine.getHealthFactor(user);
            dscEngine.getAccountCollateralValueInUsd(user);
            for (uint256 j = 0; j < collateralTokens.length; j++) {
                dscEngine.getAccountCollateralBalance(user, collateralTokens[j]);
            }
        }
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

//         bytes4[] memory selectors = new bytes4[](7);
//         selectors[0] = Handler.depositCollateral.selector;
//         selectors[1] = Handler.redeemCollateral.selector;
//         selectors[2] = Handler.mintDsc.selector;
//         selectors[3] = Handler.burnDsc.selector;
//         selectors[4] = Handler.depositCollateralAndMintDsc.selector;
//         selectors[5] = Handler.redeemCollateralForDsc.selector;
//         selectors[6] = Handler.liquidate.selector;

//         targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
//     }

//     // ToDo: finish this invariant
//     function invariant_accountsWithBrokenHealthFactorsCanBeLiquidated() public view {}
// }
