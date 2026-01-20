// SPDX-License-Identifier: MIT

pragma solidity 0.8.33;

import {DecentralizedStableCoin} from "./DecentralizedStableCoin.sol";
import {OracleLib} from "./libraries/OracleLib.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title DSCEngine
 * @author Gearhart
 * @notice This contract is the core of the DSC system. It handles all the logic for minting and redeeming DSC, as well as depositing and withdrawing collateral.
 * @dev This contract is very loosely based on the MakeDAO DSS (DAI) system.
 *
 * The system is designed to be as minimal as possible while maintaining a
 * 1 token == 1$ peg.
 *
 * DSC system must always be "overcollateralized". At no point, should the value of all
 * collateral be <= the $ backed value of all circulating DSC.
 *
 * The DSC stablecoin has the following properties:
 * - Collateral: Exogenous (wETH & wBTC)
 * - Stability: Dollar pegged
 * - Minting: Algorithmic
 *
 * DSC is similar to DAI if DAI had no governance, no fees, and was only backed by
 * wETH and wBTC.
 */

contract DSCEngine is ReentrancyGuard {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLength();
    error DSCEngine__AmountMustBeMoreThanZero();
    error DSCEngine__NotApprovedToken();
    error DSCEngine__BreaksHealthFactor(uint256 healthFactor);
    error DSCEngine__TransferFailed();
    error DSCEngine__MintFailed();
    error DSCEngine__UserNotEligibleForLiquidation();
    error DSCEngine__HealthFactorNotImproved();
    error DSCEngine__InvalidPriceFeedOrTokenAddress();

    /*//////////////////////////////////////////////////////////////
                           TYPE DECLARATIONS
    //////////////////////////////////////////////////////////////*/

    using OracleLib for AggregatorV3Interface;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    DecentralizedStableCoin private immutable i_dsc;

    uint256 private constant MIN_HEALTH_FACTOR = 1e18;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant ADDITIONAL_PRICE_FEED_PRECISION = 1e10;
    uint256 private constant LIQUIDATION_THRESHOLD = 50; // liquidation risk when debt/collateral falls below (50/100) ==> 200% overcollateralized
    uint256 private constant LIQUIDATION_BONUS = 10; // 10% bonus to be paid to the liquidator (10/100)
    uint256 private constant LIQUIDATION_PRECISION = 100;

    mapping(address token => address priceFeed) private s_priceFeeds;
    mapping(address user => uint256 amountDscMinted) private s_dscMinted;
    mapping(address user => mapping(address token => uint256 amount)) private s_collateralDeposited;
    address[] private s_collateralTokens;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event CollateralDeposited(address indexed user, address indexed token, uint256 indexed amount);
    event CollateralRedeemed(
        address indexed redeemedFrom, address indexed redeemedTo, address indexed token, uint256 amount
    );

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier moreThanZero(uint256 amount) {
        _moreThanZero(amount);
        _;
    }

    modifier onlyApprovedTokens(address token) {
        _onlyApprovedTokens(token);
        _;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address[] memory tokenAddresses, address[] memory priceFeedAddresses, address dscAddress) {
        uint256 tokenAddressesLength = tokenAddresses.length;
        if (tokenAddressesLength != priceFeedAddresses.length) {
            revert DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLength();
        }
        for (uint256 i = 0; i < tokenAddressesLength; i++) {
            if (tokenAddresses[i] == address(0) || priceFeedAddresses[i] == address(0)) {
                revert DSCEngine__InvalidPriceFeedOrTokenAddress();
            }
            s_priceFeeds[tokenAddresses[i]] = priceFeedAddresses[i];
            s_collateralTokens.push(tokenAddresses[i]);
        }
        i_dsc = DecentralizedStableCoin(dscAddress);
    }

    /*//////////////////////////////////////////////////////////////
                      EXTERNAL & PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Deposit collateral and mint DSC in one transaction
     * @param collateralTokenAddress The address of the token to deposit as collateral
     * @param amountCollateral The amount of collateral tokens to deposit
     * @param amountDscToMint The amount of decentralized stable coin to mint
     */
    function depositCollateralAndMintDsc(
        address collateralTokenAddress,
        uint256 amountCollateral,
        uint256 amountDscToMint
    )
        external
    {
        depositCollateral(collateralTokenAddress, amountCollateral);
        mintDsc(amountDscToMint);
    }

    /**
     * @notice Withdraw collateral and burn DSC in one transaction
     * @param collateralTokenAddress The address of the token to be withdrawn
     * @param amountCollateral The amount of collateral tokens to withdraw
     * @param amountDscToBurn The amount of DSC to be exchanged for collateral
     */
    function redeemCollateralForDsc(
        address collateralTokenAddress,
        uint256 amountCollateral,
        uint256 amountDscToBurn
    )
        external
    {
        burnDsc(amountDscToBurn);
        redeemCollateral(collateralTokenAddress, amountCollateral);
    }

    /**
     * @notice Repay outstanding DSC to redeem collateral from account with a broken health factor
     * @param userToBeLiquidated Address of account to be liquidated
     * @param collateralTokenAddress Address of collateral type to be liquidated
     * @param debtToCover Amount of DSC to burn in exchange for users collateral
     */
    function liquidate(
        address userToBeLiquidated,
        address collateralTokenAddress,
        uint256 debtToCover
    )
        external
        nonReentrant
        moreThanZero(debtToCover)
    {
        // verify user has broken health factor
        uint256 startingUserHealthFactor = _healthFactor(userToBeLiquidated);
        if (startingUserHealthFactor >= MIN_HEALTH_FACTOR) {
            revert DSCEngine__UserNotEligibleForLiquidation();
        }
        if (debtToCover == type(uint256).max) {
            (uint256 dscMinted,) = _getAccountInformation(userToBeLiquidated);
            debtToCover = dscMinted;
            _moreThanZero(dscMinted);
        }
        // calculate amount collateral + liquidation bonus to send liquidator
        uint256 tokenAmountFromDebtCovered = getTokenAmountFromUsd(collateralTokenAddress, debtToCover);
        uint256 bonusCollateral = (tokenAmountFromDebtCovered * LIQUIDATION_BONUS) / LIQUIDATION_PRECISION;
        uint256 totalCollateralToRedeem = tokenAmountFromDebtCovered + bonusCollateral;
        // redeem the liquidated collateral and burn DSC
        _redeemCollateral(userToBeLiquidated, msg.sender, collateralTokenAddress, totalCollateralToRedeem);
        _burnDsc(debtToCover, userToBeLiquidated, msg.sender);
        // make sure liquidation actually improved users health factor
        uint256 endingUserHealthFactor = _healthFactor(userToBeLiquidated);
        if (endingUserHealthFactor <= startingUserHealthFactor) {
            revert DSCEngine__HealthFactorNotImproved();
        }
        // make sure burning DSC doesn't break the liquidators health factor
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    /**
     * @notice Deposit collateral to mint DSC or improve health factor
     * @param collateralTokenAddress The address of the token to deposit as collateral
     * @param amountCollateral The amount of collateral tokens to deposit
     */
    function depositCollateral(
        address collateralTokenAddress,
        uint256 amountCollateral
    )
        public
        nonReentrant
        moreThanZero(amountCollateral)
        onlyApprovedTokens(collateralTokenAddress)
    {
        s_collateralDeposited[msg.sender][collateralTokenAddress] += amountCollateral;
        emit CollateralDeposited(msg.sender, collateralTokenAddress, amountCollateral);
        bool success = IERC20(collateralTokenAddress).transferFrom(msg.sender, address(this), amountCollateral);
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
    }

    /**
     * @notice Withdraw collateral. Withdrawing collateral will reduce health factor
     * @param collateralTokenAddress The address of the token to be withdrawn
     * @param amountCollateral The amount of collateral tokens to withdraw
     */
    function redeemCollateral(
        address collateralTokenAddress,
        uint256 amountCollateral
    )
        public
        nonReentrant
        moreThanZero(amountCollateral)
    {
        _redeemCollateral(msg.sender, msg.sender, collateralTokenAddress, amountCollateral);
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    /**
     * @notice Mint DSC against deposited collateral
     * @notice Users must have more collateral value deposited than the minimum threshold determined by their health factor
     * @param amountDscToMint The amount of decentralized stable coin to mint
     */
    function mintDsc(uint256 amountDscToMint) public nonReentrant moreThanZero(amountDscToMint) {
        s_dscMinted[msg.sender] += amountDscToMint;
        _revertIfHealthFactorIsBroken(msg.sender);
        bool minted = i_dsc.mint(msg.sender, amountDscToMint);
        if (!minted) {
            revert DSCEngine__MintFailed();
        }
    }

    /**
     * @notice Burn DSC to redeem collateral or improve health factor
     * @param amountDscToBurn The amount of DSC to be burned
     */
    function burnDsc(uint256 amountDscToBurn) public nonReentrant moreThanZero(amountDscToBurn) {
        _burnDsc(amountDscToBurn, msg.sender, msg.sender);
        _revertIfHealthFactorIsBroken(msg.sender); // don't think this will ever get hit
    }

    /*//////////////////////////////////////////////////////////////
                           PRIVATE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Low-level internal function, do not call unless the function calling it is
     * checking to make sure health factors are not broken
     */
    function _burnDsc(uint256 amountDscToBurn, address onBehalfOf, address dscFrom) private {
        s_dscMinted[onBehalfOf] -= amountDscToBurn;
        bool success = i_dsc.transferFrom(dscFrom, address(this), amountDscToBurn);
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
        i_dsc.burn(amountDscToBurn);
    }

    /**
     * @dev Low-level internal function, do not call unless the function calling it is
     * checking to make sure health factors are not broken
     */
    function _redeemCollateral(
        address redeemedFrom,
        address redeemedTo,
        address collateralTokenAddress,
        uint256 amountCollateral
    )
        private
    {
        s_collateralDeposited[redeemedFrom][collateralTokenAddress] -= amountCollateral;
        emit CollateralRedeemed(redeemedFrom, redeemedTo, collateralTokenAddress, amountCollateral);
        bool success = IERC20(collateralTokenAddress).transfer(redeemedTo, amountCollateral);
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
    }

    /*//////////////////////////////////////////////////////////////
                INTERNAL / PRIVATE VIEW & PURE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _getAccountInformation(address user)
        private
        view
        returns (uint256 totalDscMinted, uint256 totalCollateralValueInUsd)
    {
        totalDscMinted = s_dscMinted[user];
        totalCollateralValueInUsd = getAccountCollateralValueInUsd(user);
    }

    /**
     * Returns how close to liquidation a user is
     * If health factor falls below 1, then user can be liquidated
     */
    function _healthFactor(address user) private view returns (uint256) {
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = _getAccountInformation(user);
        return _calculateHealthFactor(totalDscMinted, collateralValueInUsd);
    }

    function _onlyApprovedTokens(address token) private view {
        if (s_priceFeeds[token] == address(0)) {
            revert DSCEngine__NotApprovedToken();
        }
    }

    function _moreThanZero(uint256 amount) private pure {
        if (amount <= 0) {
            revert DSCEngine__AmountMustBeMoreThanZero();
        }
    }

    function _revertIfHealthFactorIsBroken(address user) internal view {
        uint256 userHealthFactor = _healthFactor(user);
        if (userHealthFactor < MIN_HEALTH_FACTOR) {
            revert DSCEngine__BreaksHealthFactor(userHealthFactor);
        }
    }

    function _calculateHealthFactor(
        uint256 totalDscMinted,
        uint256 collateralValueInUsd
    )
        internal
        pure
        returns (uint256)
    {
        // if 0 dsc minted then return max health factor
        if (totalDscMinted == 0) {
            return type(uint256).max;
        }
        // calculate health factor
        // Example 1
        // $150 ETH / 100 DSC
        // 150 * 50 = 7500 / 100 = (75 / 100) < 1 == bad health factor, needs liquidating
        // Example 2
        // $1000 ETH / 100 DSC
        // 1000 * 50 = 50000 / 100 = (500 / 100) > 1 == good health factor, large margin before liquidation
        uint256 collateralAdjustedForThreshold = (collateralValueInUsd * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
        return (collateralAdjustedForThreshold * PRECISION) / totalDscMinted;
    }

    /*//////////////////////////////////////////////////////////////
                PUBLIC / EXTERNAL VIEW & PURE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Gets information related to a specific user
     * @param user Address of user to get information for
     * @return totalDscMinted Total amount of all outstanding DSC minted by the user
     * @return totalCollateralValueInUsd Total USD value of all collateral deposited by the user
     */
    function getAccountInformation(address user)
        external
        view
        returns (uint256 totalDscMinted, uint256 totalCollateralValueInUsd)
    {
        (totalDscMinted, totalCollateralValueInUsd) = _getAccountInformation(user);
    }

    /**
     * @notice Gets the health factor of a user
     * @param user The address of the user
     * @return The health factor of the user
     */
    function getHealthFactor(address user) external view returns (uint256) {
        return _healthFactor(user);
    }

    /**
     * @notice Gets the price feed address for a given token
     * @param token The address of the token
     * @return The address of the price feed
     */
    function getPriceFeedAddress(address token) external view returns (address) {
        return s_priceFeeds[token];
    }

    /**
     * @notice Gets the amount of collateral deposited for a specific user and token
     * @param user address of the user
     * @param token address of the collateral token
     * @return amount of collateral deposited
     */
    function getAccountCollateralBalance(address user, address token) external view returns (uint256) {
        return s_collateralDeposited[user][token];
    }

    /**
     * @notice Gets the addresses of all approved collateral tokens
     * @return amount Array of collateral token addresses
     */
    function getCollateralTokenAddresses() external view returns (address[] memory) {
        return s_collateralTokens;
    }

    /**
     * @notice Gets address of DSC token contract
     * @return Token address
     */
    function getDecentralizedStableCoin() external view returns (address) {
        return address(i_dsc);
    }

    /**
     * @notice Gets minimum health factor a user can have without being liquidated
     * @return Minimum health factor
     */
    function getMinHealthFactor() external pure returns (uint256) {
        return MIN_HEALTH_FACTOR;
    }

    /**
     * @notice Gets precision used as denominator during value calculations
     * @return Decimal precision
     */
    function getPrecision() external pure returns (uint256) {
        return PRECISION;
    }

    /**
     * @notice Gets additional precision needed to convert price feed values to valid decimal representations
     * @return Additional price feed precision
     */
    function getAdditionalPriceFeedPrecision() external pure returns (uint256) {
        return ADDITIONAL_PRICE_FEED_PRECISION;
    }

    /**
     * @notice Gets percent bonus paid to liquidator during successful liquidation
     * @return Liquidation bonus percent
     */
    function getLiquidationBonus() external pure returns (uint256) {
        return LIQUIDATION_BONUS;
    }

    /**
     * @notice Gets numerator used during liquidation and health factor calculations
     * @return Liquidation threshold
     */
    function getLiquidationThreshold() external pure returns (uint256) {
        return LIQUIDATION_THRESHOLD;
    }

    /**
     * @notice Gets denominator used during liquidation and health factor calculations
     * @return Liquidation precision
     */
    function getLiquidationPrecision() external pure returns (uint256) {
        return LIQUIDATION_PRECISION;
    }

    /**
     * @notice Gets the health factor for a simulated account
     * @param totalDscMinted Amount of DSC minted by simulated account
     * @param collateralValueInUsd Total collateral value of all deposits for simulated account
     * @return Estimated health factor based off given parameters
     */
    function getHealthFactorEstimate(
        uint256 totalDscMinted,
        uint256 collateralValueInUsd
    )
        external
        pure
        returns (uint256)
    {
        return _calculateHealthFactor(totalDscMinted, collateralValueInUsd);
    }

    /**
     * @notice Gets the amount of collateral tokens equivalent in value to the given USD amount
     * @param collateralTokenAddress Address of collateral token
     * @param amountUsdInWei Amount of USD with 18 decimals (1e18 = $1)
     * @return Amount of collateral tokens equivalent in value to the given USD amount
     */
    function getTokenAmountFromUsd(
        address collateralTokenAddress,
        uint256 amountUsdInWei
    )
        public
        view
        returns (uint256)
    {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[collateralTokenAddress]);
        (, int256 price,,,) = priceFeed.stalePriceFeedCheckLatestRoundData();
        return (amountUsdInWei * PRECISION) / (uint256(price) * ADDITIONAL_PRICE_FEED_PRECISION);
    }

    /**
     * @notice Gets the total USD value of all collateral deposited by a user
     * @param user address of the user
     * @return totalCollateralValueInUsd total USD value of all collateral deposited by the user
     */
    function getAccountCollateralValueInUsd(address user) public view returns (uint256 totalCollateralValueInUsd) {
        uint256 numberOfTokens = s_collateralTokens.length;
        for (uint256 i = 0; i < numberOfTokens; i++) {
            address token = s_collateralTokens[i];
            uint256 amount = s_collateralDeposited[user][token];
            totalCollateralValueInUsd += getUsdValue(token, amount);
        }
        return totalCollateralValueInUsd;
    }

    /**
     * @notice Gets the USD value of a given amount of an approved token
     * @param token address of the token
     * @param amount amount of the token
     * @return USD value of the given amount of the token
     */
    function getUsdValue(address token, uint256 amount) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (, int256 price,,,) = priceFeed.stalePriceFeedCheckLatestRoundData();
        // 1 eth = $1000
        // the returned value from chainlink will be 1000 * 1e8
        // need to change price to uint256 and get correct decimals before continuing
        // (1000 * 1e8) * 1e10
        uint256 priceWithAdditionalPrecision = uint256(price) * ADDITIONAL_PRICE_FEED_PRECISION;
        // divide by 1e18 after multiplying by amount to get final value
        // (priceWithAdditionalPrecision * amount) / 1e18
        return (priceWithAdditionalPrecision * amount) / PRECISION;
    }
}
