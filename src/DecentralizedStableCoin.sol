// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC20, ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

/**
 * @title DecentralizedStableCoin
 * @author Gearhart
 * @notice This contract is only the ERC20 implementation of the DSC stablecoin system.
 * @dev DSC is meant to be governed by DSCEngine.
 *
 * The DSC stablecoin has the following properties:
 * - Collateral: Exogenous (wETH & wBTC)
 * - Stability: Dollar pegged
 * - Minting: Algorithmic
 */

contract DecentralizedStableCoin is ERC20Burnable, Ownable {
    error DecentralizedStableCoin__AmountMustBeMoreThanZero();
    error DecentralizedStableCoin__BurnAmountExceedsBalance();
    error DecentralizedStableCoin__NotZeroAddress();

    constructor(string memory tokenName, string memory tokenSymbol) ERC20(tokenName, tokenSymbol) Ownable(msg.sender) {}

    function mint(address to, uint256 amount) external onlyOwner returns (bool) {
        if (to == address(0)) {
            revert DecentralizedStableCoin__NotZeroAddress();
        }
        if (amount <= 0) {
            revert DecentralizedStableCoin__AmountMustBeMoreThanZero();
        }
        _mint(to, amount);
        return true;
    }

    function burn(uint256 amount) public override onlyOwner {
        uint256 balance = balanceOf(msg.sender);
        if (amount <= 0) {
            revert DecentralizedStableCoin__AmountMustBeMoreThanZero();
        }
        if (balance < amount) {
            revert DecentralizedStableCoin__BurnAmountExceedsBalance();
        }
        super.burn(amount);
    }
}
