// Contract based on https://docs.openzeppelin.com/contracts/3.x/erc721
// SPDX-License-Identifier: MIT
pragma solidity >=0.7.3;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

contract ExampleNFT is ERC721, Ownable {

    using SafeMath for uint256;





    /*
        Constant Variables
    */
    
    uint256 public constant MAX_TOKENS = 100;
    uint256 public constant MAX_TOKENS_PER_PURCHASE = 10;

    /*
        Other Variables
    */

    uint256 public price = 50000000000000000; // 0.05 ETH

    bool public isSaleActive = false;





    /*
        Constructor
    */

    constructor() ERC721("ExampleNFT", "EXMPL") {}





    /*
        Set the base URI for all token IDs.
        It is automatically added as a prefix to the value returned in tokenURI.
    */

    function setBaseURI(string memory _baseURI) public onlyOwner {
        _setBaseURI(_baseURI);
    }

    /*
        Activate/Deactivate Sale
    */

    function flipSaleState() public onlyOwner {
        isSaleActive = !isSaleActive;
    }

    /*
        Withdraw
    */

    function withdraw() public onlyOwner {
        uint256 balance = address(this).balance;
        msg.sender.transfer(balance);
    }

    /*
        Set Price
    */

    function setPrice(uint256 _newPrice) public onlyOwner {
        price = _newPrice;
    }

    /*
        Reserve Tokens 
    */

    function reserveTokens(address _to, uint256 _numberOfTokens) public onlyOwner {

        uint256 supply = totalSupply();

        require(supply.add(_numberOfTokens) < MAX_TOKENS, "Purchase would exceed max supply of tokens");

        for (uint256 i = 0; i < _numberOfTokens; i++) {
            uint256 mintIndex = totalSupply();
            if (mintIndex < MAX_TOKENS) {
                _safeMint(_to, mintIndex.add(1));
            }
        }

    }
    
    /*
        Mint
    */

    function mint(uint256 _numberOfTokens) public payable {

        uint256 supply = totalSupply();

        require(isSaleActive, "Sale must be active to mint tokens");
        require(_numberOfTokens > 0 && _numberOfTokens <= MAX_TOKENS_PER_PURCHASE, "Can only mint 10 tokens per transaction");
        require(supply.add(_numberOfTokens) <= MAX_TOKENS, "Purchase would exceed max supply of tokens");
        require(msg.value >= price.mul(_numberOfTokens), "ETH value sent is not correct");

        for (uint256 i = 0; i < _numberOfTokens; i++) {
            uint256 mintIndex = totalSupply();
            if (mintIndex < MAX_TOKENS) {
                _safeMint(msg.sender, mintIndex.add(1));
            }
        }

    }





}