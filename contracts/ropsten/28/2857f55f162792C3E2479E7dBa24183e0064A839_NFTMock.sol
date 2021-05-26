pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract NFTMock is ERC721 {
    uint256 public increment;

    constructor(string memory name, string memory symbol) ERC721(name, symbol) {
        increment = 0;
    }

    function mintArbitrary(address to, uint256 amount) external {
        uint256 lastId =  increment;
        for (uint256 index = lastId; index < lastId + amount; index++) {
            _mint(to, increment);
            increment = increment + 1;
        }
    }
}