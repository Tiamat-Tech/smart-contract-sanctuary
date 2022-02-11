// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "./ERC20.sol";
import "./NFT.sol";

contract MasterStore is AccessControl {
    BaseToken public token;
    NFT public nft;
    bool public setup = false;
    event Claim(uint256 indexed _pid, uint256 tokenId, address customer);

    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    function setupContract(address _token, address _nft)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(setup == false, "ERROR: The contract has been set up");
        token = BaseToken(_token);
        nft = NFT(_nft);
        setup = true;
        renounceRole(DEFAULT_ADMIN_ROLE, address(0));
    }

    function givePoint(address to, uint256 amount) public {
        token.mint(to, amount);
    }

    function redeem(string memory _tokenURI, uint256 _pid) public {
        // check token amount for redeem
        (, , uint256 requiredPoints, ) = nft.rewardInfo(_pid);
        require(
            token.balanceOf(_msgSender()) >= requiredPoints,
            "ERC20: redeem amount exceeds balance"
        );
        // burn token from caller
        token.burn(_msgSender(), requiredPoints);
        // mint NFT
        nft.mint(_msgSender(), _tokenURI, _pid);
    }

    function claim(uint256 tokenId) public {
        // check NFT
        (uint256 pid, uint256 expMinutes, , ) = nft.nftCouponInfo(tokenId);
        address owner = nft.ownerOf(tokenId);
        require(
            owner == _msgSender(),
            "ERROR: You are not the owner of this nft"
        );
        require(block.timestamp <= expMinutes, "NFT Coupon expired");
        // burn NFT from caller
        nft.burn(tokenId);
        emit Claim(pid, tokenId, _msgSender());
    }
}