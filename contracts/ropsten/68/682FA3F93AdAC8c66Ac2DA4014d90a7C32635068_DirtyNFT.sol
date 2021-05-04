//Contract based on https://docs.openzeppelin.com/contracts/3.x/erc721
// SPDX-License-Identifier: MIT
pragma solidity ^0.7.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

/*import "@openzeppelin/contracts/access/Ownable.sol";*/


contract DirtyNFT is ERC721 {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    mapping(address => bool) public mintingWallet;
    mapping(string => uint) public mintedCountURI;
    uint minted;

    constructor() public ERC721("DirtyNFT", "XXXNFT") {}

    function mintNFT(address recipient, string memory tokenURI) public returns (uint256) {

        IERC20 token = IERC20(0x62EcF49636F282313cda51E2e3cbF0E258e65356);
         
       //require(!mintingWallet[address(msg.sender)], "Wallet has reached 1 NFT mint limit for this contract");
       //require(token.balanceOf(msg.sender) >= 100000000000000000000000000, "$DIRTY token balance insufficient (less than 100 Million)");
       require(_tokenIds.current() <= 690, "NFT Mint limit of 690 has been reached");
        _tokenIds.increment();

        uint256 newItemId = _tokenIds.current();
        _mint(recipient, newItemId);
        _setTokenURI(newItemId, tokenURI);

        mintingWallet[address(msg.sender)] = true;
        minted = mintedCountURI[tokenURI];
        mintedCountURI[tokenURI] = minted + 1;

        return newItemId;
    }

    //returns whether the mint limit has been reached or not
    function mintLimitReached() public view returns (bool) {
        uint256 newItemId = _tokenIds.current();
        if (newItemId == 690) {
            return (true);
        } else {
            return (false);
        }
    }

    function totalMinted() public view returns (uint256) {
        return _tokenIds.current();
    }

    function checkBalance(address token, address holder) public view returns (uint256) {
        IERC20 token = IERC20(token);
        return token.balanceOf(holder);
    }

    function mintedCount(string memory tokenURI) public view returns (uint256) {
        return mintedCountURI[tokenURI];
    }

    
}