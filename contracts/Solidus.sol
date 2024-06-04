// SPDX-License-Identifier: UNLICENSED 
pragma solidity ^0.8.25; 

import "@openzeppelin/contracts/token/ERC20/ERC20.sol"; 

contract Solidus is ERC20 {
    address public kingdomContract; // Address of the authorized Kingdom contract

    constructor() ERC20("Solidus", "SUS") { 
        // Initial minting might go here
    }

    modifier onlyKingdom() {
        require(msg.sender == kingdomContract, "Only the Kingdom contract can call this function");
        _;
    }

    // Function to set the Kingdom contract address
    function setKingdomContract(address _kingdomContract) external onlyOwner { // Replace onlyOwner with appropriate access control
         kingdomContract = _kingdomContract;
    }

    function burn(address from, uint256 amount) external onlyKingdom {
        _burn(from, amount); 
    }
    function selfBurn(address from, uint256 amount) external {
    require(from == msg.sender, "Only the owner can self-burn");
    _burn(from, amount);
}
}