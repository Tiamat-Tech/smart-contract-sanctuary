// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

/*

░▒█░░▒█░░▀░░█▀▀▄░█▀▀▄░█░░░░▒█▀▄▀█░█▀▀░█▀▀░█▀▀▄░█▀▀░░
░░▒█▒█░░░█▀░█▄▄▀░█▄▄█░█░░░░▒█▒█▒█░█▀░░█▀▀░█▄▄▀░▀▀▄░░
░░░▀▄▀░░▀▀▀░▀░▀▀░▀░░▀░▀▀░░░▒█░░▒█░▀░░░▀▀▀░▀░▀▀░▀▀▀░░
░▄▀░█▄░█░▄▀▄░▀█▀░░░█▄▒▄█▒▄▀▄░█▀▄▒██▀░░░█░█▄░█░░░█▒░▒▄▀▄░██▄░▀▄░░
░▀▄░█▒▀█░▀▄▀░▒█▒▒░░█▒▀▒█░█▀█▒█▄▀░█▄▄▒░░█░█▒▀█▒░▒█▄▄░█▀█▒█▄█░▄▀▒░
   
*/

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract ViralMfers is ERC721, Ownable {

    using Counters for Counters.Counter;
    Counters.Counter private _nextTokenId;

    string private _baseTokenURI;

    uint256 public constant MAX_SUPPLY = 10000;
    uint256 public constant MAX_MINT = 10;
    uint256 public MINT_COST = 0.01 ether;
 
    bool public saleIsActive;

    constructor() ERC721("Viral Mfers", "VM") {
        _nextTokenId.increment(); // Start Token IDs at 1
        saleIsActive = false;
    }

    function mint(uint256 _mintAmount) public payable {
        require(saleIsActive, "Viral Mfers are not on sale yet.");
        require(_mintAmount > 0, "Cannot mint zero!");
        require(_mintAmount <= MAX_MINT, "Save some for the rest of us, fren! Max mint is 10 Viral Mfers.");
        require(totalSupply() + _mintAmount <= MAX_SUPPLY, "Not enough Viral Mfers remaining.");
        require(msg.value >= currentPrice() * _mintAmount, "Not enough ETH to buy Viral Mfers, :-(");
  
        for (uint256 i = 0; i < _mintAmount; i++) {
            uint256 mintIndex = _nextTokenId.current(); // Get next ID to mint
            _nextTokenId.increment();
            _safeMint(msg.sender, mintIndex);
        }
    }

    function mintForAddress(uint256 _mintAmount, address _receiver) public onlyOwner {
        require(_mintAmount > 0, "Cannot mint zero!");
        require(totalSupply() + _mintAmount <= MAX_SUPPLY, "Not enough Viral Mfers remaining.");
  
        for (uint256 i = 0; i < _mintAmount; i++) {
            uint256 mintIndex = _nextTokenId.current(); // Get next ID to mint
            _nextTokenId.increment();
            _safeMint(_receiver, mintIndex);
        }
    }

    function currentPrice() public view returns (uint256) {
        return MINT_COST;
    }

    function remainingSupply() public view returns (uint256) {
        uint256 numberMinted = totalSupply();
        return MAX_SUPPLY - numberMinted;
    }

    function totalSupply() public view returns (uint256) {
        return _nextTokenId.current() - 1;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }

    function setBaseURI(string memory baseURI) external onlyOwner {
        _baseTokenURI = baseURI;
    }

    function toggleSale() public onlyOwner {
        saleIsActive = !saleIsActive;
    }

    function setMintPrice(uint256 _newMintPrice) public onlyOwner {
        MINT_COST = _newMintPrice;
    }

    function withdrawBalance() public onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }
    
}