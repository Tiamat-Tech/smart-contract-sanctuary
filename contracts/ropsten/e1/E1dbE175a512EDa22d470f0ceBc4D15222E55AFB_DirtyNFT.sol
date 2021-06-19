//Contract based on https://docs.openzeppelin.com/contracts/3.x/erc721
// SPDX-License-Identifier: MIT
pragma solidity ^0.7.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract DirtyNFT is Ownable, ERC721 {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    mapping(address => bool) public mintingWallet;
    mapping(string => uint) public mintedCountURI;
    mapping(uint256 => string) private nftURI;
    uint private minted;

    constructor() public ERC721("DirtyNFT", "XXXNFT") {}


    function mint(address recipient, uint256 id) public returns (uint256) {

        require(msg.sender == address(0x155a119c1Da8d0c749a50E54a9751e088EB6E056), "Minting not allowed outside of the farming contract");

        _tokenIds.increment();
        
        uint256 newItemId = _tokenIds.current();
        _mint(recipient, newItemId);
        _setTokenURI(newItemId, nftURI[id]);

        minted = mintedCountURI[nftURI[id]];
        mintedCountURI[nftURI[id]] = minted + 1;

        return newItemId;

    }


    //returns the total number of minted NFT
    function totalMinted() public view returns (uint256) {
        return _tokenIds.current();
    }
    //returns the balance of the erc20 token required for validation
    function checkBalance(address _token, address _holder) public view returns (uint256) {
        IERC20 token = IERC20(_token);
        return token.balanceOf(_holder);
    }
    //returns the number of mints for each specific NFT based on URI
    function mintedCount(string memory tokenURI) public view returns (uint256) {
        return mintedCountURI[tokenURI];
    }

    function setNFTUri(uint256 _id, string memory _uri) public onlyOwner {
        nftURI[_id] = _uri;
    }
    
}