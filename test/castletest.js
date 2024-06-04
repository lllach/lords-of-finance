const { expect } = require("chai");
const { ethers } = require("hardhat");
import "../contracts/Castle.sol";
describe("Castle", function () {
  let Castle; // Will hold the deployed Castle contract
  let castle; // Will hold the instance of the contract

  beforeEach(async function () {
    // Code to deploy the contract before each test
  });

  it("Should allow the owner to deposit collateral", async function () {
     // Test logic for the depositCollateral function
  });
});
it("Should allow the owner to deposit collateral", async function () {
    const [owner] = await ethers.getSigners(); // Get sample test account 
    const initialCollateral = 100;  // Amount of WETH to deposit (adjust as needed)
  
    // Get the castle's initial WETH balance
    const initialBalance = await castle.wethCollateral();
  
    // Owner deposits collateral
    await castle.depositCollateral({ value: initialCollateral });
  
    // Get the updated WETH balance
    const updatedBalance = await castle.wethCollateral();
  
    // Assert that the balance increased correctly:
    expect(updatedBalance).to.equal(initialBalance.add(initialCollateral));
  });
  beforeEach(async function () {
    const CastleFactory = await ethers.getContractFactory("Castle");
  
    // Get the WETH contract address on Arbitrum for testing
    const wethAddress = "0x82aF49447D8a07e3bd95BD0d56f35241523fBab1"; 
  
    castle = await CastleFactory.deploy(wethAddress, 100); // 100 as initial collateral
  }); 
