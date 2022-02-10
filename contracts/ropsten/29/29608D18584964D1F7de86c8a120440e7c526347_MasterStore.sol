// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// import "@openzeppelin/contracts/access/AccessControl.sol";
// import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./ERC20.sol";
import "./NFT.sol";

contract MasterStore {
    BaseToken public token;
    NFT public nft;
    constructor(address _token, address _nft) {
        token = BaseToken(_token);
        nft = NFT(_nft);
    }

    function givePoint(address to, uint256 amount) public {
        token.mint(to, amount);
    }

    function redeem(uint256 amount, string memory _tokenURI) public {
        token.burn(msg.sender, amount);
        // check token amount for redeem
        // burn token from caller
        // mint NFT
        nft.mint(msg.sender, _tokenURI);
        // 
    }

    function claim(uint256 tokenId) public {
        // check NFT
        nft.burn(tokenId);
        // burn NFT from caller
    }
}