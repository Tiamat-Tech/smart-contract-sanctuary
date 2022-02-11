// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "./ERC20.sol";
import "./NFT.sol";

contract MasterStore {
    BaseToken public token;
    NFT public nft;
    event Claim(uint256 indexed _pid, uint256 tokenId, address customer);
    constructor(address _token, address _nft) {
        token = BaseToken(_token);
        nft = NFT(_nft);
    }

    function givePoint(address to, uint256 amount) public {
        token.mint(to, amount);
    }

    function redeem(string memory _tokenURI, uint256 _pid) public {
        // check token amount for redeem
        (,, uint256 requiredPoints,) = nft.rewardInfo(_pid);
        require(token.balanceOf(msg.sender) >= requiredPoints, "ERC20: redeem amount exceeds balance" );
        // burn token from caller
        token.burn(msg.sender, requiredPoints);
        // mint NFT
        nft.mint(msg.sender, _tokenURI, _pid);
    }

    function claim(uint256 tokenId, uint256 _pid) public {
        // check NFT
        (, uint256 expMinutes,,) = nft.nftCouponInfo(_pid);
        address owner = nft.ownerOf(tokenId);
        require(owner == msg.sender, "ERROR: You are not the owner of this nft");
        require(block.timestamp <= expMinutes * 1 days, "NFT Coupon expired");
        // burn NFT from caller
        nft.burn(tokenId);
        emit Claim(_pid, tokenId, msg.sender);
    }
}