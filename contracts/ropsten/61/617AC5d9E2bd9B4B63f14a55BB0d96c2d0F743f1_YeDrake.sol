//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract YeDrake is ERC721, Ownable {
    using SafeERC20 for IERC20;

    uint8 public immutable maxTokenId;
    uint8 public lastTokenId = 0;
    
    uint256 public immutable priceInETH;

    string public baseURIPath;

    event BaseURIUpdated(string newURI);

    constructor(uint8 _maxTokenId, uint256 _priceInETH, string memory _baseURIPath) ERC721("KanyeWestAndDrake", "YEDR") {
        maxTokenId = _maxTokenId;
        priceInETH = _priceInETH;
        baseURIPath = _baseURIPath;
    }

    function mint() external payable {
        require(msg.value == priceInETH, "msg.value != price");
        require(lastTokenId < maxTokenId, "Sold out");

        lastTokenId += 1;
        _safeMint(msg.sender, lastTokenId);
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "URI query for nonexistent token");

        string memory baseURI = _baseURI();
        // tokenURI is fixed to 1
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, "1")) : "";
    }

    function withdraw(address payable _to) external onlyOwner {
        require(_to != address(0), "Invalid address");
        _to.transfer(address(this).balance);
    }

    function updateBaseURI(string memory _newURI) external onlyOwner {
        baseURIPath = _newURI;
        emit BaseURIUpdated(baseURIPath);
    }

    function _baseURI() internal view override returns (string memory) {
        return baseURIPath;
    }
}