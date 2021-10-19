// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


/*
██╗    ██╗ ██████╗ ██████╗ ███╗   ███╗
██║    ██║██╔═══██╗██╔══██╗████╗ ████║
██║ █╗ ██║██║   ██║██████╔╝██╔████╔██║
██║███╗██║██║   ██║██╔══██╗██║╚██╔╝██║
╚███╔███╔╝╚██████╔╝██║  ██║██║ ╚═╝ ██║
 ╚══╝╚══╝  ╚═════╝ ╚═╝  ╚═╝╚═╝     ╚═╝
*/
contract WigglyWorms is ERC721Enumerable, Ownable {
    using Strings for uint256;

    // Reserved for gifting
    uint256 public constant WORMS_PRIVATE = 2;

    // Number of worms released to the public
    uint256 public constant WORMS_PUBLIC = 8;
    uint256 public constant MAX_WORMS = WORMS_PUBLIC + WORMS_PRIVATE;
    uint256 public constant PRICE = 0.08 ether;
    uint256 public constant MAX_PER_MINT = 4;
    uint256 public constant MAX_WORMS_MINT = 4;
    
    uint256 public privateNumberWormsMinted;
    uint256 public publicNumberWormsMinted;
    bool public saleLive;
    string private _baseTokenURI;
    string private _contractURI;

    event ContractURIChanged(string URI);
    event BaseURIChanged(string URI);
    
    mapping(address => uint256) private _totalClaimed;

    constructor() ERC721("WigglyWorms", "WORM") { }

    // Set Contract-level URI
    function setContractURI(string calldata URI) external onlyOwner {
        _contractURI = URI;
        emit ContractURIChanged(URI);
    }

    // Set the Base URI
    function setBaseURI(string calldata URI) external onlyOwner {
        _baseTokenURI = URI;
        emit BaseURIChanged(URI);
    }

    // Retrieve the contract URI
    function contractURI() public view returns (string memory) {
        return _contractURI;
    }

    // Retrieve the base URI
    function baseURI() public view returns (string memory) {
        return _baseTokenURI;
    }

    // Turns the Sale on/off
    function toggleSaleStatus() external onlyOwner {
        saleLive = !saleLive;
    }

    // Buy/Mint Wiggly Worm
    function mint(uint256 amountOfWorms) external payable {
        require(saleLive, "Minting is not open yet");
        require(totalSupply() < MAX_WORMS, "All tokens have been minted");
        require(amountOfWorms <= MAX_PER_MINT, "Cannot purchase this many tokens in a single transaction");
        require(totalSupply() + amountOfWorms <= MAX_WORMS, "Minting would exceed max supply");
        require(_totalClaimed[msg.sender] + amountOfWorms <= MAX_WORMS_MINT, "Purchase exceeds max allowed per address");
        require(amountOfWorms > 0, "Must mint at least one worm");
        require(PRICE * amountOfWorms == msg.value, "ETH amount is incorrect");

        // Iterate through the number of worms desired and mint
        for (uint256 i = 0; i < amountOfWorms; i++) {
            publicNumberWormsMinted++;
            _totalClaimed[msg.sender]++;
            _safeMint(msg.sender, totalSupply() + 1);
        }
    }

    // Used to gift Wiggly Worms
    function gift(address[] calldata receivers) external onlyOwner {
        require(totalSupply() + receivers.length <= MAX_WORMS, "Gifting exceeded");
        require(privateNumberWormsMinted + receivers.length <= WORMS_PRIVATE, "All gifts have been minted");
        
        for (uint256 i = 0; i < receivers.length; i++) {
            privateNumberWormsMinted++;
            _safeMint(receivers[i], totalSupply() + 1);
        }
    }

    // Withdraw
    function withdraw() external onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }
}