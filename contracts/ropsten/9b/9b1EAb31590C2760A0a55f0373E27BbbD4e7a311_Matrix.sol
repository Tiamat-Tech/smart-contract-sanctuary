pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Matrix is ERC721, Ownable, ReentrancyGuard {
    using Counters for Counters.Counter;

    Counters.Counter private circulating;
    string public constant URI = "https://rcw.io/chronomatrix/assets/metadata/metadata.json";
    uint256 public constant MAX_SUPPLY = 100; // limit to 100
    uint256 public constant PRICE = 10000000000000000; // 0.01 ETH measured in wei

    constructor() ERC721("Matrix", "MTX") {}
 
    function tokenURI(uint256)
        public
        pure
        override 
        returns (string memory)
    {
        return URI;
    }

    function mint() external payable nonReentrant {
        require(circulating.current() <= MAX_SUPPLY, "No supply left.");
        require(msg.value == PRICE, "The price is 0.01 ETH.");

        _safeMint(msg.sender, circulating.current());
        circulating.increment();
    }

    function totalSupply() external view returns(uint256) {
        return circulating.current();
    }
}