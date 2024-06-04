// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./Kingdom.sol"; // Adjust the path if needed

Kingdom public kingdomContract; // Variable for the Kingdom contract

contract Florint is ERC20 {
    uint256 public constant MAX_SUPPLY = 1_000_000 * 10**18; // 1 million Florints
    uint256 public constant INDULGENCES_INITIAL_SHARE = 100_000 * 10**18; // 10%
    uint256 public annualDistributionPercent = 10; 
    uint256 public mintedSupply; 
    address public indulgencesFund; 

    // Constructor 
    constructor(address _indulgencesFund) ERC20("Florint", "₣") { 
        indulgencesFund = _indulgencesFund;
        _mint(indulgencesFund, INDULGENCES_INITIAL_SHARE); 
        mintedSupply = INDULGENCES_INITIAL_SHARE;
        kingdomContract = Kingdom(_kingdomContract); 
    }
    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
    _transfer(_msgSender(), recipient, amount);
    return true;
}
 function giftTimeDistribution(uint256 amount, address[] memory stakerAddresses, uint256[] memory stakerAmounts, address[] memory castleAddresses, uint256[] memory castleAmounts) external {
    require(msg.sender == address(kingdomContract), "Only Kingdom can trigger distribution");
    require(mintedSupply + amount <= MAX_SUPPLY, "Cannot mint beyond max supply");

    // Calculate amounts for each group
    uint256 kingsShare = amount * 20 / 100;
    uint256 distributionAmount = amount - kingsShare;

    // Get GCR from the Kingdom contract
    uint256 gcr = kingdomContract.calculateGCR();

    // Calculate Distribution Ratios
    (uint256 stakerFraction, uint256 castleFraction) = kingdomContract.calculateDistributionRatios(gcr);

    // Distribute to stakers based on their share
    uint256 totalStaked = 0;
    for (uint256 i = 0; i < stakerAddresses.length; i++) {
        totalStaked += stakerAmounts[i];
    }
    for (uint256 i = 0; i < stakerAddresses.length; i++) {
        uint256 stakerShare = (distributionAmount * stakerFraction * stakerAmounts[i]) / (totalStaked * 1000); // Adjust for fractions
        _mint(stakerAddresses[i], stakerShare);
    }

    // Distribute to castles based on their share
    for (uint256 i = 0; i < castleAddresses.length; i++) {
        _mint(castleAddresses[i], castleAmounts[i]);
    }

    // Distribute to the King
    _mint(kingAddress, kingsShare);

    mintedSupply += amount;
}

    // Function for annual minting (adjust permissions as needed)
    
    function annualDistribution() external { 
        uint256 remainingSupply = MAX_SUPPLY - mintedSupply;
        uint256 amountToMint = (MAX_SUPPLY - mintedSupply) * annualDistributionPercent / 100;
        _mint(address(this), amountToMint); // Mint to the Florint contract itself
        mintedSupply += amountToMint;
        lastAnnualDistribution = block.timestamp; // Update after annual distribution
    }
}