// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

// ______                      _   _____                 
// | ___ \                    | | |  __ \                
// | |_/ /___  _   _ _ __   __| | | |  \/_   _ _   _ ___ 
// |    // _ \| | | | '_ \ / _` | | | __| | | | | | / __|
// | |\ \ (_) | |_| | | | | (_| | | |_\ \ |_| | |_| \__ \
// \_| \_\___/ \__,_|_| |_|\__,_|  \____/\__,_|\__, |___/
//                                              __/ |    
//                                             |___/    

// setBASEURI manually after deploying..
contract RoundGuys is ERC721, Ownable {
    using SafeMath for uint256;

    uint256 public maxItems = 900;
    uint256 public mintPrice = 0.04 ether; // Mutable by owner
    uint256 public maxItemsPerTx = 10; // Mutable by owner
    uint256 public totalSupply = 0; // Total items minted
    string public _baseTokenURI;
    uint public startTimestamp = 1633633200; // Thursday, October 7, 2021 7:00:00 PM

    constructor() ERC721("RoundGuys", "RGS") { }

    function ownerMint(uint numberOfTokens) external onlyOwner {
        for (uint i = 0; i < numberOfTokens; i++) {
            _safeMint(msg.sender, totalSupply);
            totalSupply += 1;
        }
    }

    function mintNFT(uint numberOfTokens) public payable returns (uint) {
        // require(block.timestamp >= startTimestamp, "publicMint: Not open yet");
        require(totalSupply.add(numberOfTokens) <= maxItems, "Purchase would exceed max supply of items");
        require(numberOfTokens > 0 && numberOfTokens <= maxItemsPerTx, "Can only mint 10 items at a time");
        require(msg.value >= 0.04 ether, "Ether value sent is not correct");
      
        for (uint i = 0; i < numberOfTokens; i++) {
            _safeMint(msg.sender, totalSupply);
            totalSupply += 1;
         
        }
        return totalSupply;
    }

    function setStartTimestamp(uint _startTimestamp) external onlyOwner {
        startTimestamp = _startTimestamp;
    }

    function setBaseTokenURI(string memory __baseTokenURI) external onlyOwner {
        _baseTokenURI = __baseTokenURI;
    }

    function setMintPrice(uint _mintPrice) external onlyOwner {
        mintPrice = _mintPrice;
    }

    function setMaxItemsPerTx(uint _maxItemsPerTx) external onlyOwner {
        maxItemsPerTx = _maxItemsPerTx;
    }

     /**
     * @dev Withdraw the contract balance to the dev address
     */

    function sendEth(address to, uint amount) internal {
        (bool success,) = to.call{value: amount}("");
        require(success, "Failed to send ether");
    }

    function withdraw() external onlyOwner {
        sendEth(owner(), address(this).balance);
    }

    /**
     * @dev Returns a URI for a given token ID's metadata
    */

    function tokenURI(uint256 _tokenId) public view override returns (string memory) {
        return string(abi.encodePacked(_baseTokenURI, Strings.toString(_tokenId)));
    }
}