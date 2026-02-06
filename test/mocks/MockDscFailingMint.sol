// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

contract MockDscFailingMint {
    function mint(address, uint256) external pure returns (bool) {
        return false;
    }

    function burn(uint256) external pure {}
}
