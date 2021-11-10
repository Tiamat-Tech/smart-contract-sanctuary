// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract YangNFT is ERC721, AccessControl{

    uint256 private _tokenStartIndex = 1001;
    uint256 private _tokenIdTracker;
    using SafeMath for uint256;

    string public baseTokenURI = "ipfs://QmeSjSinHpPnmXmspMjwiXyN6zS4E9zccariGR3jxcaWtq/";
    uint256 public price  = 10000000000000000; //0.01 eth
    
    uint256 private constant MAXSUPPLY = 8000;
    bytes32 private constant CFO_ROLE = keccak256("CFO_ROLE");

    constructor() ERC721("YangNFT", "YNFT") {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(CFO_ROLE, msg.sender);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function _baseURI() internal view virtual override returns (string memory){
        return baseTokenURI;
    }

    function setBaseURI(string memory baseURI) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender),"only admin can set BaseURI!");
        baseTokenURI = baseURI;
    }

    function setPrice(uint256 _price) public {
        require(hasRole(CFO_ROLE, msg.sender),"only CFO can set price!");
        price = _price;
    }

    function setCFO(address cfo) public {
        //require(hasRole(DEFAULT_ADMIN_ROLE,msg.sender),"only admin can set CFO");
        grantRole(CFO_ROLE, cfo);
    }

    function mint() public payable{
        require(_tokenIdTracker<MAXSUPPLY+_tokenStartIndex, "tokenIndex out of scope");
        require(msg.value >= price, "Ether value sent is not correct!");
        _safeMint(msg.sender, _tokenIdTracker);
        _tokenIdTracker = _tokenIdTracker.add(1);
    }

    function withdraw() public {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender),"you are not the owner!");
        uint balance = address(this).balance;
        payable(msg.sender).transfer(balance);
    }

}