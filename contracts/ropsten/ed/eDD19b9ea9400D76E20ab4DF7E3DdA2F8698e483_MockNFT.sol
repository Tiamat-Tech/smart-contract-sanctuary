pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MockNFT is ERC721, Ownable {
    uint256 public totalSupply = 0;

    constructor(string memory name_, string memory symbol_) ERC721(name_, symbol_) {
    }

    function reserveMint(address to, uint256 amount) public onlyOwner {
        for (uint256 i = 0; i < amount; i++) {
            mint(to);
        }
    }
    function mint(address to) public onlyOwner {
        _safeMint(to, totalSupply);
        totalSupply +=1;
    }

}