// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";


// MetaMask Ropsten - 0x59791898EBE5B3f4ebFb799ad5cf83CF75810b9c

contract SportsCards is ERC721, ERC721URIStorage, Ownable {

    address SPORTS_WALLET = 0xB28936A128a5a5b934fE74f0fDC8326865b8A13D;

    constructor() ERC721("SportsCards", "CARD") {}

    function mint(uint256 tokenId, string memory tokenURIKey)
        public
        onlyOwner
        returns (uint256)
    {
        _safeMint(SPORTS_WALLET, tokenId);
        _setTokenURI(tokenId, tokenURIKey);

        return tokenId;
    }

    function redeem(address payable recipient, uint256 tokenId)
        public
        payable
        returns (uint256)
    {
        // Token has to have been minted
        require(_exists(tokenId), "Token hasn't been minted.");

        // blow up if the token has already been redeemed (current owner != Sports DAO)
        // require(ownerOf(tokenId) != owner, "Token has already been redeemed.");
        
        // blow up if there isn't enough ETH attached
        require(msg.value >= _costForRedemption(tokenId), "Not enough ETH sent.");

        // blow up if it's too early to mint this one

        // if it's a premier card and the premier card has been redeemed
        if(false) {
            payable(ownerOf(tokenId)).transfer(SafeMath.mul(SafeMath.div(msg.value, 10), 2));
            payable(SPORTS_WALLET).transfer(SafeMath.mul(SafeMath.div(msg.value, 10), 8));
        } else {
            payable(SPORTS_WALLET).transfer(msg.value);
        }

        approve(recipient, tokenId);        // approve transfer
        transferFrom(SPORTS_WALLET, recipient, tokenId); // transfer the token to the recipient

        return tokenId;
    }

    function _costForRedemption(uint256 tokenId) private returns(uint8) {
        if(tokenId > 0) {
            return 0;
        }
    }

    // The following functions are overrides required by Solidity.

    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }
}