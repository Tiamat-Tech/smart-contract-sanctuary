pragma solidity ^0.8.0;

import "hardhat/console.sol";

import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";

/// Code Monkey Coin!
///
/// ERC20PresetMinterPause Batteries included ERC20 contract.
///
/// Minter: for being able to mint and burn coins.
/// Pauser: for being able to pause everything in the case of an emergency!
/// We do not implement a cap right now nor an initial supply.
///
/// At the moment, the contract deployer gets all access.
contract CMCToken is ERC20PresetMinterPauser {
    /// Create the token only. Allow the deployer to be a default Admin.
    constructor() ERC20PresetMinterPauser("Code Monkey Coin", "CMC") {
      console.log("Creating Code Monkey Coin with sender '%s'", msg.sender);
    }
}