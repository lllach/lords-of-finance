// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25; 

interface ISolidus {
    function burn(address from, uint256 amount) external;
    function getTotalBurned() external view returns (uint256); // Getter for test

}