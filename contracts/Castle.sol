// SPDX-License-Identifier: UNLICENSED 
pragma solidity ^0.8.25; // Specify Solidity version

import "@openzeppelin/contracts/token/ERC20/IERC20.sol"; 
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "./Kingdom.sol"; // Import the Kingdom contract


contract Castle {
    // Data Structures
    address public owner; 
    IERC20 public weeth; // Declare Interface for WEETH
    uint256 public weethCollateral; 
    uint256 public susDebt;
    string public title; 
    enum Status { Active, Dormant, Liquidated } // Add an Enum for Castle states
    Status public status; 
    function refreshPriceIfNeeded() internal {
    if (block.timestamp - lastPriceUpdate > 300) { // Update if 5 mins have passed
        updateWeethPrice();
        lastPriceUpdate = block.timestamp;
    }
}

    // Constructor (when building a castle)
    constructor(address _weeth, uint256 initialCollateral, address _kingdomContract, address _solidusContract) {
        owner = msg.sender; 
        weeth = IERC20(_weeth); 
        weethCollateral = initialCollateral;
        susDebt = 0; 
        title = "Humble Abode"; 
        status = Status.Active; // Initialize the status to Active
        kingdomContract = _kingdomContract; // Store the Kingdom contract address
        ethPriceFeed = AggregatorV3Interface(0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612); // Replace 0xABC... with the actual Aggregator address on your testnet
         // Automatic approval for Kingdom contract to burn/mint Solidus
    Solidus(_solidusContract).approve(_kingdomContract, type(uint256).max);
    }

    function depositCollateral() public payable {
        require(msg.sender == owner, "Only the owner can deposit collateral");
        weeth.transferFrom(msg.sender, address(this), msg.value);
        weethCollateral += msg.value; 
    }

function updateWeethPrice() internal {
    (, int price, , , ) = ethPriceFeed.latestRoundData();

    // Adjust decimals based on ETH price feed and your desired precision
    weethPrice = uint256(price) * 10**8; // Assuming 8 decimals for ETH price
}

     function withdrawCollateral(uint256 amount) public {
        require(msg.sender == owner, "Only the owner can withdraw collateral");
        // Add logic here to check collateralization ratio before withdrawal
        weethCollateral -= amount; 
        weeth.transfer(msg.sender, amount);
    }

    function selfMint(uint256 amount) public {
        require(msg.sender == owner, "Only the owner can self-mint Solidus");
        
         // Fetch the latest WETH price from the Kingdom contract
        uint256 currentWEETHPrice = Kingdom(kingdomContract).getLatestWETHPrice(); // Assuming kingdomContract is the Kingdom contract's address
        uint256 weethAmount = amount * 1005 / (1000 * currentWEETHPrice);  // Corrected calculationuint256 currentWEETHPrice = updateWeethPrice(); // Fetch price from Chainlink
        refreshPriceIfNeeded(); // Ensure fresh price 
        uint256 susAmount = weethAmount * currentWEETHPrice; 
        uint256 newCollateral = weethCollateral + weethAmount * currentWEETHPrice; 
        uint256 newSusDebt = susDebt + susAmount;
        require(newCollateral >= newSusDebt * 1200 / 1000, "Minting would violate collateralization ratio");
        // ... minting logic will go here 
    }

    function selfBurn(uint256 amount) public {
        require(msg.sender == owner, "Only the owner can self-burn Solidus");
        // Fetch the latest WETH price from the Kingdom contract
        uint256 currentWEETHPrice = Kingdom(kingdomContract).getLatestWETHPrice(); 
        uint256 weethAmount = amount * 995 / (1000 * currentWEETHPrice); // Corrected calculation
        refreshPriceIfNeeded(); // Ensure fresh price 
        uint256 weethAmount = susAmount / currentWEETHPrice; 
        uint256 currentWEETHPrice = updateWeethPrice(); 
        refreshPriceIfNeeded(); 
        uint256 weethAmount = amount / currentWEETHPrice; 
        // ... burning logic will go here 
    }   
function kingdomMint(uint256 amount) external {
    require(msg.sender == kingdomContract, "Only the Kingdom contract can call this function");
    // ... Logic to mint Solidus (likely via Solidus.sol interaction)

    // Update collateralization state 
    weethCollateral += amount * 1000 / 1005; // Example, adjust based on how Kingdom sends WEETH
    susDebt += amount; 
}
function kingdomBurn(uint256 amount) external {
    require(msg.sender == kingdomContract, "Only the Kingdom contract can call this function");

    // Ensure sufficient WEETH collateral (with alarm)
    if (weethCollateral < amount) {
        emit CastleApproachingLiquidation(address(this)); // Emit an event 
        return;  // Skip the burn for this Castle
    }

    // Burn Solidus tokens 
    Solidus(solidusContract).burn(owner, amount);

    // Update collateralization state
    susDebt -= amount; // Reduce the SUS debt
    weethCollateral -= amount; // Reduce WEETH collateral proportionally 

    // ... (Optional) Perform additional book-keeping or event emission 
}



function reduceSusDebt(uint256 amount) external {
    require(msg.sender == kingdomContract, "Only the Kingdom contract can call this function");
    susDebt -= amount;
}

function reduceCollateral(uint256 amount) external {
    require(msg.sender == kingdomContract, "Only the Kingdom contract can call this function");
    weethCollateral -= amount;
}

function updateCollateralizationRatio() private { 
    uint256 currentWEETHPrice = updateWeethPrice(); 
    collateralizationRatio = (weethCollateral * currentWEETHPrice * 1000) / susDebt; // Adjust if needed 
}
function liquidateCastle() external { 
    require(collateralizationRatio <= 1200 / 1000, "Castle not eligible for liquidation"); 

    // 1. Calculate net worth 
    uint256 netWorth = weethCollateral - susDebt;

    // 2. Send 90% to Lord
    uint256 amountForLord = netWorth * 90 / 100; 
    address payable lordAddress = ...; // Retrieve from governance or config 
    lordAddress.transfer(amountForLord); 

    // 3. Send 5% to Florint holders
    uint256 amountForFlorint = netWorth * 5 / 100; 
    // ... Logic to distribute to Florint holders (we'll address this below)

    // 4. Distribute remaining assets to Knightly Castles 
    uint256 remainingCollateral = weethCollateral - amountForLord - amountForFlorint; 
    uint256 remainingDebt = susDebt;
    distributeToKnightlyCastles(remainingCollateral, remainingDebt); // Function to be designed

    // 5. Mark Castle as liquidated 
    status = Status.Liquidated; // Assuming you have an enum for Castle statuses
}

event CastleApproachingLiquidation(address indexed castleAddress);
}