// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import './@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol';
import './@openzeppelin/contracts/access/Ownable.sol';
import {IERC20} from "./@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract TownNFT is ERC721Enumerable, Ownable {

    using Strings for uint256;

    string _baseTokenURI;
    bool public _paused = true;

    uint256 private _reserved = 500;
    uint256 private _price = 0.03 ether;

    constructor(string memory baseURI) ERC721("The Town Collections", "TOWN")  {
        setBaseURI(baseURI);
    }

    function mint(uint256 num) public payable {
        uint256 supply = totalSupply();
        require(!_paused, "Sale paused");
        require(num < 21, "You can mint a maximum of 20 items");
        require(supply + num <= 10000 - _reserved, "Exceeds maximum supply");
        require(msg.value >= _price * num, "Ether sent is not correct");

        for (uint256 i; i < num; i++) {
            _safeMint(msg.sender, supply + i);
        }
    }

    function giveAway(address _to, uint256 _amount) external onlyOwner {
        require(_amount <= _reserved, "Exceeds reserved supply");

        uint256 supply = totalSupply();
        for (uint256 i; i < _amount; i++) {
            _safeMint(_to, supply + i);
        }

        _reserved -= _amount;
    }

    function walletOfOwner(address _owner) public view returns (uint256[] memory) {
        uint256 tokenCount = balanceOf(_owner);

        uint256[] memory tokensId = new uint256[](tokenCount);
        for (uint256 i; i < tokenCount; i++) {
            tokensId[i] = tokenOfOwnerByIndex(_owner, i);
        }
        return tokensId;
    }

    function setPrice(uint256 _newPrice) public onlyOwner {
        _price = _newPrice;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }

    function setBaseURI(string memory baseURI) public onlyOwner {
        _baseTokenURI = baseURI;
    }

    function getPrice() public view returns (uint256){
        return _price;
    }

    function pause(bool val) public onlyOwner {
        _paused = val;
    }

    function withdrawEther(address _to) public payable onlyOwner {
        require(payable(_to).send(address(this).balance));
    }

    function retrieveERC20(address _tracker, uint256 amount) external onlyOwner {
        IERC20(_tracker).transfer(msg.sender, amount);
    }

    function retrieve721(address _tracker, uint256 id) external onlyOwner {
        IERC721(_tracker).transferFrom(address(this), msg.sender, id);
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

        string memory baseURI = _baseURI();
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, tokenId.toString())) : "";
    }
}