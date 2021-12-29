// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Importing relevant openzeppelin frameworks for required token function.
// ERC20 conforms to an indentifiable identical token standard like Shiba Inu. ERC20Burnable Allows from token burning
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";


contract DesertCoin is ERC20, ERC20Burnable {

/// Properties specified 
    string coinName = "DesertCoin";
    string coinSymbol = "DSC";

/// Token Constructed as ERC20 Token
    constructor() ERC20(coinName , coinSymbol) {

        /// 25 * 10^27 (Bear in mind the default 18 decimal places) tokens formed and placed in contract distrbuters wallet
        _mint(msg.sender, (25000000000 * (10 ** 18)));
    }

    /// Any required methods can be added here...
}