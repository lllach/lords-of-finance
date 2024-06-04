// SPDX-License-Identifier: UNLICENSED 
pragma solidity ^0.8.25; 

import "./Florint.sol";
import "./Castle.sol"; // Adjust the path if needed
import "./SolidusStaking.sol"; // Adjust the path if needed
import "./OrderBook.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol"; 
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/interfaces/KeeperCompatibleInterface.sol";


IOrderBook public orderBook;
address[] public eligibleCastles; 
SolidusStaking public stakingContract;
address public kingAddress; // Address to receive the King's share
FlorintStaking public florintStaking; // Reference to your Florint staking contract

uint256 public totalMintableSUS;  // Total SUS available for Kingdom-level minting
uint256 public totalBurnableSUS;   // Total SUS burnable at the 0.995 price
uint256 public lastLiquidationCheck; 
uint256 public liquidationCheckInterval = 10 * 60; // Example: Check every 10 min. 
uint256 public lastGiftTime; // Tracks the timestamp of the last Gift Time event
uint256 public giftTimeInterval = 60; // Example: 1 minute for testing
uint256 public annualDistributionInterval = 365 * 24 * 60 * 60; // 1 year in seconds
int256 public accumulatedFlorintSeigniorage; // Store seigniorage for Florint holders
uint256 remainingSupply = florint.MAX_SUPPLY() - florint.mintedSupply();
uint256 public knightlyCastleThreshold; 
uint256 public lastKnightlyThresholdUpdate;
uint256 public knightlyThresholdUpdateInterval = 3600; // 1 hour (in seconds)
uint256 currentCollateralizationRatio = (weethCollateral * getLatestWETHPrice() * 1000) / (susDebt * 10**8); // Assuming 8 decimals for WEETH

contract Kingdom is VRFConsumerBaseV2, KeeperCompatibleInterface { 
    VRFCoordinatorV2Interface COORDINATOR;
    // Your subscription ID, etc. (Chainlink setup required) ...
    AggregatorV3Interface internal ethPriceFeed;
    uint256 public weethPrice; // Example: price in USD with appropriate decimals 
    uint256 public lastPriceUpdate; 
    uint256 giftTimeInterval = 60; // 1 minute for testing 
    // Cache for totalMintableSUS and timestamp
    uint256 public cachedTotalMintableSUS;
    uint256 public lastTotalMintableSUSCalculation;
    // Cache update interval (in seconds) - adjust as needed
    uint256 public mintableSUSCacheUpdateInterval = 600; // 10 minutes
    address public kingAddress; 
    IERC20 public solidus;  
    Florint public florint; 
    
    function wethPriceFor1005Usd() public view override returns (uint256) {
        uint256 weethPriceUsd = getLatestWETHPrice(); // Assuming 8 decimals for wethPrice
        return 1005 * 10**18 / weethPriceUsd; // 1.005 USD in WEETH, adjust decimals if needed
    }

    function wethPriceFor995Usd() public view override returns (uint256) {
        uint256 weethPriceUsd = getLatestWETHPrice(); // Assuming 8 decimals for wethPrice
        return 995 * 10**18 / weethPriceUsd;  // 0.995 USD in WEETH, adjust decimals if needed
    }
      // Event to signal an error during SUS burn
  event BurnError(address indexed castleAddress, string reason);

    // ... (Constructor to initialize VRFCoordinatorV2Interface) ...
// Constructor
    constructor(address _weeth, address _solidus, address _florint,
        address _florintStaking, 
        address vrfCoordinator, 
        address _ethPriceFeedAddress) {
        weeth = IERC20(_weeth);
        solidus = IERC20(_solidus);
        florint = Florint(_florint);
        minimumMintingAmount = 10 * 10**18; // Example: 10 WEETH
        minimumBurningAmount = 10 * 10**18; // Example: 10 Solidus
        lastGiftTime = block.timestamp; 
        florintStaking = FlorintStaking(_florintStaking);
        lastAnnualDistribution = block.timestamp;
        orderBook = IOrderBook(addressOfYourDeployedOrderBookContract);
        // Initialize Chainlink price feed
        ethPriceFeed = AggregatorV3Interface(0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612); // **REPLACE with correct address** 
        updateWeethPrice(); // Get initial price
         // Instantiate the Solidus staking contract
        stakingContract = new SolidusStaking(_solidus); // Pass your Solidus token address
        // Mapping to store the index of each castle in eligibleCastles
        mapping(address => uint256) public eligibleCastleIndex;
        // Constant for the Golden Ratio threshold
        uint256 public constant GOLDEN_RATIO_THRESHOLD = 1618 * 10**3;
    }

    function checkUpkeep(bytes calldata /* checkData */) external view override returns (bool upkeepNeeded, bytes memory /* performData */) {
        upkeepNeeded = (block.timestamp - lastGiftTime) > giftTimeInterval;
        // ... return upkeepNeeded;
    }

    function performUpkeep(bytes calldata /* performData */) external override {
        // Ensure only Chainlink Keeper can call this
        if ((block.timestamp - lastGiftTime) > giftTimeInterval) {
            lastGiftTime = block.timestamp;
            requestRandomness(); 
        }
    }

    function requestRandomness() internal {
        COORDINATOR.requestRandomWords(/* ... Chainlink VRF parameters ... */);
    }

    function fulfillRandomWords(uint256,  uint256[] memory randomWords) internal override {
        uint256 randomness = randomWords[0];
        if (randomness % 1440 == 0) { // Simulating 1/1440 probability
            triggerGiftTime(); 
        } 
    }

    function getLatestWETHPrice() public returns (uint256) {
    if (block.timestamp - lastPriceUpdate > 300) { // Update every 5 minutes
      updateWeethPrice();
      lastPriceUpdate = block.timestamp;
    }
    return weethPrice;
    
    function updateWeethPrice() internal {
    (, int price, , , ) = ethPriceFeed.latestRoundData();
    // Adjust decimals based on ETH price feed and your desired precision
    weethPrice = uint256(price) * 10**8; // Assuming 8 decimals for ETH price
  }

  }
   // Replace with placeholders for now
    uint256[] memory stakerAmounts = getStakerAmounts(); 
    address[] memory castleAddresses = getEligibleCastles();
    uint256[] memory castleAmounts = calculateCastleDistribution(distributionAmount);

    // Call giftTimeDistribution on Florint contract 
    Florint(florintAddress).giftTimeDistribution(distributionAmount, stakerAddresses, stakerAmounts, castleAddresses, castleAmounts); 
}

contract Kingdom { 

function calculateGCR() public view returns (uint256) {
    uint256 totalCollateral = calculateTotalCollateral(); // You likely already have or can easily implement this
    uint256 totalSusDebt = calculateTotalSusDebt();  // You'll need a function for this

    // Handle potential division by zero
    if (totalSusDebt == 0) {
        return type(uint256).max; // Or some very high value to represent an over-collateralized system 
    }

    // Calculate GCR (adjust decimals if needed)
    uint256 gcr = (totalCollateral * 1000) / totalSusDebt;  
    return gcr;
}

  function calculateGiftTimeMintAmount() public view returns (uint256) {
        uint256 remainingSupply = florint.MAX_SUPPLY() - florint.mintedSupply(); // Use florint instance variable 
        uint256 annualMintAmount = remainingSupply * 10 / 100; // 10% of remaining supply
        uint256 giftTimeMintAmount = annualMintAmount / 365;
        return giftTimeMintAmount;
    }

function triggerGiftTime() internal { 
    // 1. Calculate GCR 
    uint256 gcr = calculateGCR(); 

    // 2. Calculate Distribution Ratios 
    (uint256 stakerFraction, uint256 castleFraction) = calculateDistributionRatios(gcr);

   // Calculate the amount of Florint to mint for Gift Time distribution
        uint256 giftTimeFlorint = calculateGiftTimeMintAmount();

        // Calculate amounts for each group
        uint256 distributionAmount = giftTimeFlorint * 80 / 100;

        // Gather distribution data (using the optimized method for stakers)
        address[] memory stakerAddresses = stakingContract.stakerAddresses();
        uint256[] memory stakerAmounts = new uint256[](stakerAddresses.length);
        uint256 totalStaked = 0;
        
        for (uint256 i = 0; i < stakerAddresses.length; i++) {
            stakerAmounts[i] = stakingContract.stakedBalances(stakerAddresses[i]);
            totalStaked += stakerAmounts[i];
            uint256 share = accumulatedFlorintSeigniorage * stakerAmounts[i] / totalStaked;
            weth.transfer(stakerAddresses[i], share); 
        }

        // Calculate castle distribution
        address[] memory eligibleCastles = getEligibleCastles(1618 * 10**3); 
        uint256[] memory castleAmounts = calculateCastleDistribution(distributionAmount * castleFraction / 1000); 

        // Call Florint's giftTimeDistribution
         florint.giftTimeDistribution(
            giftTimeFlorint,
            stakerAddresses,
            stakerAmounts,
            castleAddresses,
            castleAmounts
        );

        // Seigniorage distribution to stakers (Optimized)
       for (uint i = 0; i < stakerAddresses.length; i++) {
            uint256 share = accumulatedFlorintSeigniorage * stakerAmounts[i] / totalStaked;
            weth.transfer(stakerAddresses[i], share);
        }

        accumulatedFlorintSeigniorage = 0; // Reset the accumulated seigniorage

        lastGiftTime = block.timestamp; // Update after Gift Time distributions
    }

    // Function to distribute WEETH to Florint holders
    function distributeToFlorintStakers(uint256 wethAmount) public {
        require(msg.sender == address(this), "Only the Kingdom can distribute to Florint stakers");
        address[] memory stakerAddresses = florintStaking.getStakerAddresses();
        uint256[] memory stakerAmounts = florintStaking.getStakerAmounts();

        uint256 totalStaked = 0;
        for (uint i = 0; i < stakerAmounts.length; i++) {
            totalStaked += stakerAmounts[i];
        }

        for (uint i = 0; i < stakerAddresses.length; i++) {
            uint256 share = wethAmount * stakerAmounts[i] / totalStaked;
            weth.transfer(stakerAddresses[i], share);
        }
    }

function calculateCastleDistribution(uint256 totalCastleShare) private view returns (address[] memory, uint256[] memory) {
    address[] memory eligibleCastles = getEligibleCastles(/* Threshold Ratio */);
    uint256[] memory castleAmounts = new uint256[](eligibleCastles.length);

    uint256 totalExcessCollateral = calculateTotalExcessCollateral(eligibleCastles);

    for (uint256 i = 0; i < eligibleCastles.length; i++) {
        address castleAddress = eligibleCastles[i];
        uint256 castleExcessCollateral = getCastleExcessCollateral(castleAddress);
        castleAmounts[i] = (totalCastleShare * castleExcessCollateral) / totalExcessCollateral;
    }

    return (eligibleCastles, castleAmounts);
}
// Seigniorage distribution to stakers
   uint256 totalStaked = 0;
    for (uint i = 0; i < stakerAddresses.length; i++) {
        totalStaked += stakerAmounts[i];
    }
    for (uint i = 0; i < stakerAddresses.length; i++) {
        uint256 share = accumulatedFlorintSeigniorage * stakerAmounts[i] / totalStaked;
        weth.transfer(stakerAddresses[i], share); 
    }

    accumulatedFlorintSeigniorage = 0; // Reset the accumulated seigniorage

    lastGiftTime = block.timestamp; // Update after Gift Time distributions
 }

  for (uint i = 0; i < stakerAddresses.length; i++) {
    uint256 share = accumulatedFlorintSeigniorage * stakerAmounts[i] / totalStaked;
    weth.transfer(stakerAddresses[i], share); 

function calculateDistributionRatios(uint256 gcr) public view returns (uint256 stakerFraction, uint256 castleFraction) {
    uint256 phi = 1618 * 10**3; // Golden Ratio (adjust decimals as needed)

    if (gcr < (1300 * 10**3)) {
        gcr = 1300 * 10**3; // Minimum GCR
    } else if (gcr > (2718 * 10**3)) {
        gcr = 2718 * 10**3; // Approximate GCR based on 'e'
    }

    // Interpolation for stakers (50% at phi, 100% at e)
    stakerFraction = (gcr - phi) * 10**3 / (1418 * 10**3); 

    // Interpolation for Castles (50% at phi, 0% at 1.3)
    castleFraction = (1300 * 10**3 - gcr) * 10**3 / (318); 
}

function distributeFlorint(uint256 florintAmount) private { 
    // 1. Get eligible Castles (you can reuse getEligibleCastles)
     address[] memory eligibleCastlesArray = new address[](castles.length); // Potentially optimize array size later
    uint256 numEligibleCastles = 0;

    // Iterate through the castles mapping
    for (address castleAddress : castles) {
      CastleRecord storage record = castles[castleAddress];

      if (record.collateralizationRatio >= thresholdRatio) {
        eligibleCastlesArray[numEligibleCastles] = castleAddress;
        eligibleCastleIndex[castleAddress] = numEligibleCastles;
        numEligibleCastles++;
      } else {
        // Remove from the list of eligible castles if it falls below the threshold
        eligibleCastleIndex[castleAddress] = 0;
      }
    }
    // Return the array of eligible Castle addresses
    return eligibleCastlesArray;
  }

    // 2. Calculate total excess collateral (reuse existing logic)
    uint256 totalExcessCollateral = calculateTotalExcessCollateral(eligibleCastles);

    // 3. Distribute Florint based on each Castle's share of the total excess collateral
    for (uint256 i = 0; i < eligibleCastles.length; i++) {
        address castleAddress = eligibleCastles[i];
        uint256 castleExcessCollateral = getCastleExcessCollateral(castleAddress);

        // Calculate the amount of Florint to distribute to this Castle
        uint256 florintAmountForCastle = (castleExcessCollateral * florintAmount) / totalExcessCollateral;

        // Trigger Florint transfer to the Castle 
        Florint(florintAddress).transfer(castleAddress, florintAmountForCastle); 

        // Note: You won't need the 'seigniorage' logic as Florint is not being minted here
    }
}

function updateCastleState(address castleAddress, uint256 newCollateral, uint256 newDebt) public {
    require(msg.sender == castleAddress, "Only the Castle can update its state");

    CastleRecord storage record = castles[castleAddress];
    record.weethCollateral = newCollateral;
    record.susDebt = newDebt;
    record.collateralizationRatio = (newCollateral * getLatestWETHPrice()) / (newDebt * 10**8); // Assuming 8 decimals for WEETH
}

function calculateTotalCollateral() public view returns (uint256) {
    uint256 totalCollateral = 0;
    for (address castleAddress : castles) {
        CastleRecord storage record = castles[castleAddress];
        totalCollateral += record.weethCollateral;
    }
    return totalCollateral;
}

function calculateTotalSusDebt() public view returns (uint256) {
    uint256 totalSusDebt = 0;
    for (address castleAddress : castles) {
        CastleRecord storage record = castles[castleAddress];
        totalSusDebt += record.susDebt;
    }
    return totalSusDebt;
}
function calculateDistributionAmounts(uint256 giftTimeFlorint) public view returns (uint256 stakerShare, uint256 castleShare) {
    uint256 gcr = calculateGCR(); 

    // Ensure GCR is within the valid range (1.3 to e)
    if (gcr < 1300 / 1000) {
        gcr = 1300 / 1000; 
    } else if (gcr > 2718 / 1000) { // Approximation of 'e'
        gcr = 2718 / 1000;
    }

    // Define the Golden Ratio (phi) 
    uint256 phi = 1618; // 1.618

   // Interpolation for stakers (50% at phi, 100% at e)
        stakerFraction = (gcr - phi * 10**3) * 10**3 / ((2718 - phi) * 10**3);

        // Interpolation for Castles (50% at phi, 0% at 1.3)
        castleFraction = (1300 - gcr) * 10**3 / ((phi - 1300) * 10**3);

   // Adjust for the King's share (20% of giftTimeFlorint) 
    uint256 totalDistribution = giftTimeFlorint * 80 / 100; 
    stakerShare = totalDistribution * stakerFraction;
    castleShare = totalDistribution * castleFraction;
}

function getStakerAmounts() public view returns (uint256[] memory) {
    address[] memory addresses = stakingContract.stakerAddresses();
    uint256[] memory amounts = new uint256[](addresses.length);
    for (uint256 i = 0; i < addresses.length; i++) {
        amounts[i] = stakingContract.stakedBalances(addresses[i]);
    }
    return amounts;
}

function checkForLiquidations() public {
    require(block.timestamp >= lastLiquidationCheck + liquidationCheckInterval, "Not time for liquidation check yet");
    lastLiquidationCheck = block.timestamp;

    // Iterate through Castles
    for (address castleAddress : castles) {
        CastleRecord storage record = castles[castleAddress];

        if (record.collateralizationRatio <= 1200 / 1000) {
            Castle(castleAddress).liquidateCastle();
        }
    }
}

function distributeToKnightlyCastles(uint256 collateralAmount, uint256 susDebt) private {
    // 1. Get all castles with collateralization ratio above the Golden Ratio
    address[] memory eligibleCastles = getEligibleCastles(1618 * 10**3); // Golden Ratio Threshold

    // 2. Calculate total collateral of eligible castles
    uint256 totalEligibleCollateral = 0;
    for (uint256 i = 0; i < eligibleCastles.length; i++) {
        totalEligibleCollateral += castles[eligibleCastles[i]].weethCollateral;
    }

    // 3. Find the collateral threshold for knightly castles (20% of total)
    uint256 knightlyCollateralThreshold = (totalEligibleCollateral * 20) / 100; 

    // 4. Create a sorted array of eligible castles by collateralization ratio
    CastleRecord[] memory castleDataArray = new CastleRecord[](eligibleCastles.length);
    for (uint256 i = 0; i < eligibleCastles.length; i++) {
        castleDataArray[i] = CastleRecord(
            eligibleCastles[i], 
            castles[eligibleCastles[i]].collateralizationRatio
        );
    }
    sortCastlesByCollateralizationRatio(castleDataArray); // Implement sorting here (descending order)

    // 5. Select Knightly Castles
    address[] memory knightlyCastles = new address[](eligibleCastles.length); // Max possible size
    uint256 knightlyCastleCount = 0;
    uint256 accumulatedCollateral = 0;

    for (uint256 i = 0; i < castleDataArray.length; i++) {
        accumulatedCollateral += castleDataArray[i].weethCollateral;
        knightlyCastles[knightlyCastleCount] = castleDataArray[i].castleAddress;
        knightlyCastleCount++;

        if (accumulatedCollateral >= knightlyCollateralThreshold) {
            break;
        }
    }
    
    // Resize knightlyCastles array
    assembly { mstore(knightlyCastles, knightlyCastleCount) } // Adjust the length of the array to the actual number of knightly castles

    // 6. Calculate total collateral of knightly castles
    uint256 totalKnightlyCollateral = 0;
    for (uint256 i = 0; i < knightlyCastleCount; i++) { // using knightlyCastleCount to avoid iterating on empty slots
        totalKnightlyCollateral += castles[knightlyCastles[i]].weethCollateral;
    }

    // 7. Distribute proportionally
    for (uint256 i = 0; i < knightlyCastleCount; i++) { // using knightlyCastleCount to avoid iterating on empty slots
        address castleAddress = knightlyCastles[i];
        CastleRecord storage record = castles[castleAddress];

        uint256 collateralShare = (record.weethCollateral * collateralAmount) / totalKnightlyCollateral;
        uint256 debtShare = (record.susDebt * susDebt) / totalKnightlyCollateral;

        Castle(castleAddress).increaseCollateral(collateralShare); // New function in Castle.sol
        Castle(castleAddress).increaseSusDebt(debtShare);           // New function in Castle.sol
    }
}

// Helper function to sort CastleRecords by collateralization ratio
function sortCastlesByCollateralizationRatio(CastleRecord[] memory _castles) private pure {
    uint256 n = _castles.length;
    for (uint256 i = 0; i < n - 1; i++) {
        for (uint256 j = 0; j < n - i - 1; j++) {
            if (_castles[j].collateralizationRatio < _castles[j + 1].collateralizationRatio) {
                CastleRecord memory temp = _castles[j];
                _castles[j] = _castles[j + 1];
                _castles[j + 1] = temp;
            }
        }
    }
}

function calculateKnightlyCastleThreshold() public {
    // Check if it's time to update
    require(block.timestamp - lastKnightlyThresholdUpdate >= knightlyThresholdUpdateInterval, "Not time to update yet");

    // Get eligible castles with collateralization ratio above the Golden Ratio
    address[] memory eligibleCastles = getEligibleCastles(1618 * 10**3); // Golden Ratio Threshold

    // Calculate total eligible collateral
    uint256 totalEligibleCollateral = 0;
    for (uint256 i = 0; i < eligibleCastles.length; i++) {
        totalEligibleCollateral += castles[eligibleCastles[i]].weethCollateral;
    }

    // Calculate 20% of total eligible collateral
    knightlyCastleThreshold = (totalEligibleCollateral * 20) / 100; 

    //Update all castles to knightly or not 
    for (address castleAddress : castles) {
        Castle(castleAddress).updateKnightlyStatus(castleAddress, knightlyCastleThreshold);
    }

    lastKnightlyThresholdUpdate = block.timestamp;
}

function updateKnightlyStatus(uint256 newKnightlyCastleThreshold) public {
    require(msg.sender == kingdomContract, "Only the Kingdom contract can call this function");
    uint256 currentWETHPrice = Kingdom(kingdomContract).getLatestWETHPrice();
    uint256 weethCollateralValue = weethCollateral * currentWETHPrice / 10 ** 8; // Adjust decimals
    if (weethCollateralValue >= newKnightlyCastleThreshold) {
      knightlyStatus = true;
    } else {
      knightlyStatus = false;
    }
}
    // Data Structures
    struct CastleRecord {
        address castleAddress;      
        uint256 collateralizationRatio; 
    }

    mapping(address => CastleRecord) public castles; 

    // Variables
    IERC20 public weeth;  
    IERC20 public solidus;  

uint256 public minimumMintingAmount;  
uint256 public minimumBurningAmount;


    // Minting Solidus 
    function mintSolidus(uint256 weethAmount) external {
              require(wethAmount >= minimumMintingAmount, "WEETH amount below minimum");

      // 1. Transfer WEETH from the user's wallet to the Kingdom contract
      weth.transferFrom(msg.sender, address(this), weethAmount);

      // 2. Calculate the amount of Solidus to mint based on USD equivalent
      uint256 weethPriceUsd = getLatestWETHPrice(); 
      uint256 usdEquivalent = weethAmount * weethPriceUsd / 10**18; // Convert WEETH to USD
      uint256 solidusAmount = usdEquivalent * 10**18 / 1005;       // Calculate SUS based on 1.005 USD per SUS

      // 3. Distribute minting across eligible Castles 
      distributeMinting(solidusAmount);

      // 4. Seigniorage distribution 
      distributeSeigniorage(solidusAmount); 

      // 5. Transfer minted Solidus to the user
      solidus.transfer(msg.sender, solidusAmount);

        // Check if it's time to update knightly castle threshold
        if (block.timestamp - lastKnightlyThresholdUpdate >= knightlyThresholdUpdateInterval) {
        calculateKnightlyCastleThreshold();
    }
    }

function kingdomMint(uint256 mintAmount) public {
    // ... Require statements for valid amounts etc. ...

       // 1. Calculate total mintable SUS (from eligible castles)
    uint256 totalMintableSUS = calculateTotalMintableSUS();

    // 2. Update the kingdom's offer amount in the order book
    orderBook.updateKingdomOffer(); 

    // 3. If necessary, create a new kingdom offer in the order book
    if (totalMintableSUS > kingdomOfferAmount) {
        uint256 newOfferAmount = totalMintableSUS - kingdomOfferAmount;
        orderBook.createOffer(kingdomMintOfferPrice(), newOfferAmount);
    }

    // 4. Trigger matching of orders (this will also execute the mint if there's a match)
    orderBook.matchOrders();

    // 5. Safety check for large mints 
    if (mintAmount > totalMintableSUS * 80 / 100) { // Only check if mint is large
        for (address castleAddress : eligibleCastles) {
            require(Castle(castleAddress).collateralizationRatio() >= 1200 / 1000, "Minting would violate Castle's ratio");
        }
    }
}
  function kingdomBurn(uint256 burnAmount) public {
    // ... Require statements for valid amounts etc. ...

    // 1. Update the kingdom's bid amount in the order book
    orderBook.initializeKingdomBid(burnAmount); // Assuming kingdomBid.amount should be updated with the burnAmount

    // 2. Trigger matching of orders (this will also execute the burn if there's a match)
    orderBook.matchOrders();
  }


function calculateTotalMintableSUS() private view returns (uint256) {
        // Check if cache is stale (10 minutes passed)
        if (block.timestamp - lastTotalMintableSUSCalculation >= mintableSUSCacheUpdateInterval) {
            uint256 totalMintable = 0;
            address[] memory eligibleCastles = getEligibleCastles(1300 * 10**3); // Get castles eligible to mint Solidus

            for (uint256 i = 0; i < eligibleCastles.length; i++) {
                totalMintable += calculateCastleMintableSUS(eligibleCastles[i]);
            }

            // Update cache
            cachedTotalMintableSUS = totalMintable;
            lastTotalMintableSUSCalculation = block.timestamp;
            return totalMintable;
        } else {
            // Return cached value
            return cachedTotalMintableSUS;
        }
    }

// Helper function (needs logic to determine how much a Castle can mint without dropping below 1.3 ratio)
function calculateCastleMintableSUS(address castleAddress) private view returns (uint256) {
    // ...  Your logic here ... 
}

 function distributeMinting(uint256 solidusAmount) private {
      // 1. Get eligible Castles
        address[] memory eligibleCastles = getEligibleCastles(1300 * 10**3); // Get castles eligible to mint Solidus

       for (uint256 i = 0; i < eligibleCastles.length; i++) {
        address castleAddress = eligibleCastles[i];
        uint256 weethCollateral = Castle(castleAddress).weethCollateral();
        uint256 susDebt = Castle(castleAddress).susDebt();
        updateCastleState(castleAddress, weethCollateral, susDebt);
        castles[eligibleCastles[i]].collateralizationRatio = Castle(eligibleCastles[i]).collateralizationRatio();
        castles[eligibleCastles[i]].weethCollateral = Castle(eligibleCastles[i]).weethCollateral();
        castles[eligibleCastles[i]].susDebt = Castle(eligibleCastles[i]).susDebt();
        }
      }

    function removeEligibleCastle(address castleAddress) public {
    // ... (Potentially add onlyOwner or governance checks as needed)
    uint256 index = eligibleCastleIndex[castleAddress];
    require(index != 0, "Castle not found or not eligible");
    eligibleCastles[index - 1] = eligibleCastles[eligibleCastles.length - 1];
        eligibleCastleIndex[eligibleCastles[index - 1]] = index - 1; // Update the index of the swapped castle
        eligibleCastles.pop();

        delete eligibleCastleIndex[castleAddress];
}

    // Helper function to find a Castle's index 
    indexOf(address castleAddress) private view returns (uint256) {
    for (uint256 i = 0; i < eligibleCastles.length; i++) {
        if (eligibleCastles[i] == castleAddress) {
            return i;
        }  
    }
    return type(uint256).max; 
}

    // 2. Calculate total excess collateral across the eligible Castles 
    uint256 totalExcessCollateral = calculateTotalExcessCollateral(eligibleCastles);

    // 3. Distribute minting based on each Castle's share of the total excess collateral
    for (uint256 i = 0; i < eligibleCastles.length; i++) {
        address castleAddress = eligibleCastles[i];
        uint256 castleExcessCollateral = getCastleExcessCollateral(castleAddress);

        // Calculate the amount of Solidus to be minted by this Castle
        uint256 mintAmountForCastle = (castleExcessCollateral * solidusAmount) / totalExcessCollateral;

        // Calculate Seigniorage
        uint256 seigniorageAmount = mintAmountForCastle * 5 / 1000;  
        uint256 amountToSendToCastle = mintAmountForCastle + seigniorageAmount;

        // Trigger minting in the Castle contract 
        weeth.transfer(castleAddress, amountToSendToCastle); // Transfer WEETH with seigniorage
        Castle(castleAddress).kingdomMint(mintAmountForCastle); 

        // Update collateralization state in the Castle contract and in the Kingdom's record
        // ... (code to update collateral and debt in the Castle)
        // ... (code to update the CastleRecord in the castles mapping)
    }

    // Burning Solidus
    function burnSolidus(uint256 solidusAmount) external {
    require(solidusAmount >= minimumBurningAmount, "Solidus amount below minimum");

    // 1. Transfer Solidus from the user's wallet to the Kingdom contract
    solidus.transferFrom(msg.sender, address(this), solidusAmount);

    // 2. Calculate the amount of WEETH to send to the user (solidusAmount * 995 / 1000)
    uint256 weethAmount = solidusAmount * 995 / 1000; 

    // Update the Kingdom's burnable SUS amount
    require(solidusAmount <= totalBurnableSUS, "Burn amount exceeds Kingdom bid"); // Use solidusAmount here 
    totalBurnableSUS -= solidusAmount;

    // 3. Distribute the burning task proportionally across Castles based on their net worth
    distributeBurning(solidusAmount); 
    
   function distributeBurning(uint256 solidusAmount) private {
      uint256 totalSusDebt = calculateTotalSusDebt();
      for (address castleAddress : castles) {
          CastleRecord storage record = castles[castleAddress];

          uint256 burnAmountForCastle = (record.susDebt * solidusAmount) / totalSusDebt;
          try Castle(castleAddress).kingdomBurn(burnAmountForCastle) {
              // Burn successful
          } catch (bytes memory reason) {
              // Emit the error and the Castle address for analysis
              emit BurnError(castleAddress, string(reason));
          }

          // Update the collateralization state in the Kingdom contract
            castles[castleAddress].collateralizationRatio = Castle(castleAddress).collateralizationRatio();
            castles[castleAddress].weethCollateral = Castle(castleAddress).weethCollateral();
            castles[castleAddress].susDebt = Castle(castleAddress).susDebt();

             // Check if it's time to update knightly castle threshold
        if (block.timestamp - lastKnightlyThresholdUpdate >= knightlyThresholdUpdateInterval) {
        calculateKnightlyCastleThreshold();
       
          uint256 newWeethCollateral = Castle(castleAddress).weethCollateral();
          uint256 newSusDebt = Castle(castleAddress).susDebt();
          updateCastleState(castleAddress, newWeethCollateral, newSusDebt);
      }

      // Distribute Seigniorage
      distributeSeigniorage(solidusAmount);
}
}
function getCastleExcessCollateral(address castleAddress) private view returns (uint256) {
    CastleRecord storage record = castles[castleAddress];

    // Calculate required collateral (example: minimum ratio is 1.2)
    uint256 requiredCollateral = record.susDebt * 1200 / 1000;

    // Ensure we don't underflow in case collateral is very low
    if (record.weethCollateral < requiredCollateral) {
        return 0; 
    }

    uint256 excessCollateral = record.weethCollateral - requiredCollateral;
    return excessCollateral;
}
function calculateCastleMintableSUS(address castleAddress) private view returns (uint256) {
  CastleRecord storage record = castles[castleAddress];
  uint256 weethCollateral = record.weethCollateral;
  uint256 susDebt = record.susDebt;

  // Convert WEETH collateral to USD equivalent using oracle
  uint256 weethPriceUsd = getLatestWETHPrice(); // Assuming 8 decimals for wethPrice
  uint256 usdCollateral = (weethCollateral * weethPriceUsd) / 10**8; // Adjust decimals if needed

  // Check if the castle already meets or exceeds the 1.3 requirement
  if (usdCollateral * 1000 >= susDebt * 1300) { // Assuming 8 decimals for WEETH
      return 0; // Castle cannot mint without going below 1.3 ratio
  }

  // Calculate maximum mintable SUS while maintaining 1.3 ratio
  uint256 numerator = (usdCollateral * 1000) - (susDebt * 1300);
  uint256 denominator = 300;
  uint256 maxMintableSUS = numerator / denominator;

  return maxMintableSUS;
}

    // Calculate minting capacity (maintains 1.3 ratio)
    uint256 mintableSUS = (totalCollateral - 13 * susDebt / 10) / 3 / 10; // Adjust decimals if needed
    return mintableSUS;
}

function distributeMinting(uint256 solidusAmount) private { 
    // 1. Get eligible Castles
    address[] memory eligibleCastles = getEligibleCastles(/* Threshold Ratio */);
    function getEligibleCastles(uint256 thresholdRatio) private view returns (address[] memory) {
    address[] memory eligibleCastlesArray = new address[](castles.length); // Potentially optimize array size later
    uint256 numEligibleCastles = 0; 

    // Iterate through the castles mapping
    for (address castleAddress : castles) {
        CastleRecord storage record = castles[castleAddress];

        if (record.collateralizationRatio >= thresholdRatio) {
            eligibleCastlesArray[numEligibleCastles] = castleAddress;
            numEligibleCastles++;
        }
    }

    // Return the array of eligible Castle addresses
    return eligibleCastlesArray;
}
    // 2. Calculate total excess collateral across the eligible Castles 
    uint256 totalExcessCollateral = calculateTotalExcessCollateral(eligibleCastles);
function calculateTotalExcessCollateral(address[] memory castles) private view returns (uint256) {
    uint256 totalExcess = 0;

    for (uint256 i = 0; i < castles.length; i++) {
        address castleAddress = castles[i];
        uint256 castleExcessCollateral = getCastleExcessCollateral(castleAddress);
        totalExcess += castleExcessCollateral;    
    }

    return totalExcess;
}
    // 3. Distribute minting based on each Castle's share of the total excess collateral
    for (uint256 i = 0; i < eligibleCastles.length; i++) {
        address castleAddress = eligibleCastles[i];
        uint256 castleExcessCollateral = getCastleExcessCollateral(castleAddress);
        castles[eligibleCastles[i]].collateralizationRatio = Castle(eligibleCastles[i]).collateralizationRatio();
            castles[eligibleCastles[i]].weethCollateral = Castle(eligibleCastles[i]).weethCollateral();
            castles[eligibleCastles[i]].susDebt = Castle(eligibleCastles[i]).susDebt();
       
        // Calculate the amount of Solidus to be minted by this Castle
        uint256 mintAmountForCastle = (castleExcessCollateral * solidusAmount) / totalExcessCollateral;

        // Trigger minting in the Castle contract 
        Castle(castleAddress).selfMint(mintAmountForCastle); 

        // Update collateralization state in the Castle contract and in the Kingdom's record
        // ... (code to update collateral and debt in the Castle)
        // ... (code to update the CastleRecord in the castles mapping)
    }
     
function addEligibleCastle(address castleAddress) public {
    // ... (Potentially add onlyOwner or governance checks as needed)
    eligibleCastles.push(castleAddress);
}

function removeEligibleCastle(address castleAddress) public {
    // ... (Potentially add onlyOwner or governance checks as needed)
    uint256 index = indexOf(castleAddress);
    require(index != type(uint256).max, "Castle not found"); 
    eligibleCastles[index] = eligibleCastles[eligibleCastles.length - 1];
    eligibleCastles.pop();
}

// Helper function to find a Castle's index 
function indexOf(address castleAddress) private view returns (uint256) {
    for (uint256 i = 0; i < eligibleCastles.length; i++) {
        if (eligibleCastles[i] == castleAddress) {
            return i;
        }  
    }
    return type(uint256).max; 
}

function updateTotalBurnableSUS() public { 
    // Logic to iterate through Castles and aggregate their susDebt 
    uint256 totalDebt = 0;
    for (address castleAddress : castles) {
        CastleRecord storage record = castles[castleAddress];
        totalDebt += record.susDebt; 
    }

    totalBurnableSUS = totalDebt; 
} 

// Variables for minting offer
uint256 public totalMintableSUS;  
uint256 public kingdomMintOfferPrice; // WEETH price per SUS for the Kingdom's mint offer

// Variables for burning bid
uint256 public totalBurnableSUS;  
uint256 public kingdomBurnBidPrice;  // WEETH price per SUS for the Kingdom's burn bid

}
