// SPDX-License-Identifier: MIT LICENSE
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract doodledog is ERC721, Ownable {    
    constructor() ERC721("Doodle Dogs", "DODLDOG") {}

    uint256 public constant MINT_PRICE = 0 ether;

    uint256 public MAX_TOKENS = 10;
    uint256 public minted = 0;

    bool public onSale = false;

    string public baseTokenURI = "ipfs://QmSZXdjo5issZNZEXgW28vwSeoHkks21Ns9JhYCvx57GyM/";

    function mint(uint256 amount) external payable {
        require(onSale, "Minting not live");
        require(minted + amount <= MAX_TOKENS, "All tokens minted");
        require(amount > 0 && amount <= 10, "Invalid mint amount");
        require(amount * MINT_PRICE == msg.value, "Invalid payment amount");
        
        for (uint i = 0; i < amount; i++) {
            minted++;
            _mint(msg.sender, minted);
        }
    }

    function mintFree(uint256 amount) external {
        require(onSale, "Minting not live");
        require(minted + amount <= MAX_TOKENS, "All tokens minted");
        require(amount > 0 && amount <= 5, "Invalid mint amount");

        for (uint i = 0; i < amount; i++) {
            minted++;
            _mint(msg.sender, minted);
        }
    }

    function changeOnSale() external onlyOwner(){
        onSale = !onSale;
    }

    function setBaseURI(string calldata _uri) external onlyOwner(){
        baseTokenURI = _uri;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return baseTokenURI;
    }

    function totalSupply() public view returns (uint256){
        return minted;
    }

    //Utilities
    function withdrawAll() external onlyOwner() {
        require(payable(msg.sender).send(address(this).balance));
    }
}