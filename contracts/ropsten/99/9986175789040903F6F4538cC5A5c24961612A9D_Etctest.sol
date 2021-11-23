// SPDX-License-Identifier: MIT
/*

███████╗░█████╗░██████╗░████████╗██╗░░██╗███████╗██████╗░███████╗██╗░░░██╗███╗░░░███╗
██╔════╝██╔══██╗██╔══██╗╚══██╔══╝██║░░██║██╔════╝██╔══██╗██╔════╝██║░░░██║████╗░████║
█████╗░░███████║██████╔╝░░░██║░░░███████║█████╗░░██████╔╝█████╗░░██║░░░██║██╔████╔██║
██╔══╝░░██╔══██║██╔══██╗░░░██║░░░██╔══██║██╔══╝░░██╔══██╗██╔══╝░░██║░░░██║██║╚██╔╝██║
███████╗██║░░██║██║░░██║░░░██║░░░██║░░██║███████╗██║░░██║███████╗╚██████╔╝██║░╚═╝░██║
╚══════╝╚═╝░░╚═╝╚═╝░░╚═╝░░░╚═╝░░░╚═╝░░╚═╝╚══════╝╚═╝░░╚═╝╚══════╝░╚═════╝░╚═╝░░░░░╚═╝

████████╗██████╗░███████╗░█████╗░░██████╗██╗░░░██╗██████╗░███████╗░██████╗
╚══██╔══╝██╔══██╗██╔════╝██╔══██╗██╔════╝██║░░░██║██╔══██╗██╔════╝██╔════╝
░░░██║░░░██████╔╝█████╗░░███████║╚█████╗░██║░░░██║██████╔╝█████╗░░╚█████╗░
░░░██║░░░██╔══██╗██╔══╝░░██╔══██║░╚═══██╗██║░░░██║██╔══██╗██╔══╝░░░╚═══██╗
░░░██║░░░██║░░██║███████╗██║░░██║██████╔╝╚██████╔╝██║░░██║███████╗██████╔╝
░░░╚═╝░░░╚═╝░░╚═╝╚══════╝╚═╝░░╚═╝╚═════╝░░╚═════╝░╚═╝░░╚═╝╚══════╝╚═════╝░

*/

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


/**
 * Title Earthereum contract
 * Dev Extends ERC721 Non-Fungible Token Standard basic implementation
 */
//contract Earthereum is ERC721Enumerable, Ownable {

            contract Etctest is ERC721Enumerable, Ownable {

    using Strings for uint256;

    string public PROVENANCE = "";
    uint256 public tokenPrice = 90000000000000000; // 0.09 ETH
    uint public constant maxTokenPurchase = 15;
    uint256 public MAX_TOKENS = 11011;
    bool public saleIsActive = false;
    event Giveaway(address to, uint numberOfTokens);
    string baseURI;
    string public baseExtension = ".json";


    // withdraw addresses
    address t1 = 0xd97aEE51E95927b0dc64B346eB4a8cae098000B8;
    address t2 = 0x20b987dF9CC5751B7a91eF3020e336E7dc134A46;
    address t3 = 0xE05FcEa1a45470B98f8a0ebD26Fd7F812bd27b92;

    constructor() ERC721("Etctest", "ETCTEST") {
    }

    
    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal override( ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721Enumerable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    
        // --    function setBaseURI(string memory baseURI_) external onlyOwner() {
         // --    _baseURIextended = baseURI_;
         // --   }
//
function setBaseURI(string memory _newBaseURI) public onlyOwner {
    baseURI = _newBaseURI;
  }
//   
            // --   function _baseURI() internal view virtual override returns (string memory) {
            // --      return _baseURIextended;
            // --  }
//
function _baseURI() internal view virtual override returns (string memory) 
  {
    return baseURI;
  }
//
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
    require(
      _exists(tokenId),
      "ERC721Metadata: URI query for nonexistant token"
    );

    string memory currentBaseURI = _baseURI();
    return bytes(currentBaseURI).length > 0
        ? string(abi.encodePacked(currentBaseURI, tokenId.toString(), baseExtension))
        : "";
    }

    function setProvenance(string memory provenance) public onlyOwner {
        PROVENANCE = provenance;
    }

    function reserveTokens() public onlyOwner {        
        uint supply = totalSupply();
        uint i;
        for (i = 0; i < 100; i++) {
            _safeMint(msg.sender, supply + i);
        }
    }
    
    function flipSaleState() public onlyOwner {
        saleIsActive = !saleIsActive;
    }
    
    function settokenPrice(uint _fee) external onlyOwner {
        tokenPrice = _fee;
    }

    function gettokenPrice() external view returns (uint){
        return tokenPrice;
    }

    function giveaway(address to, uint numberOfTokens) external onlyOwner {
        require(numberOfTokens <= MAX_TOKENS, "SUPPLY: Value exceeds totalSupply");
        require(totalSupply() + numberOfTokens <= MAX_TOKENS,"Giveaway would exceed max supply of tokens");

        for(uint i = 0; i < numberOfTokens; i++) {
            uint mintIndex = totalSupply();
            if (totalSupply() < MAX_TOKENS) {
                _safeMint(to, mintIndex);
            }
        }
    }

    function Mint(uint numberOfTokens) public payable {
        require(saleIsActive, "Sale must be active to mint Tokens");
        require(numberOfTokens <= maxTokenPurchase, "Exceeded max token purchase");
        require(totalSupply() + numberOfTokens <= MAX_TOKENS, "Purchase would exceed max supply of tokens");
        require(tokenPrice * numberOfTokens <= msg.value, "Ether value sent is not correct");
        
        for(uint i = 0; i < numberOfTokens; i++) {
            uint mintIndex = totalSupply();
            if (totalSupply() < MAX_TOKENS) {
                _safeMint(msg.sender, mintIndex);
            }
        }
    }

     function withdrawAll() public payable onlyOwner {
        uint256 _each = address(this).balance / 3;
        require(payable(t1).send(_each));
        require(payable(t2).send(_each));
        require(payable(t3).send(_each));
    }

}