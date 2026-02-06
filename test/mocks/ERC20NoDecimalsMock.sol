// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ERC20NoDecimalsMock is ERC20 {
    constructor(string memory name, string memory symbol) ERC20("ERC20NoDecimalsMock", "ND") {}

    function decimals() public pure override returns (uint8) {
        revert("NO_DECIMALS");
    }

    function mint(address account, uint256 amount) external {
        _mint(account, amount);
    }
}
