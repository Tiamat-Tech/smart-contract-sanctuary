// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import './ERC721Enumerable.sol';
import './Ownable.sol';

contract NFTTemplate is ERC721Enumerable, Ownable {

    using Strings for uint256;

    string _baseTokenURI;
    uint256 private _price = 0.001 ether;
    address public _withdrawAddress = 0x4368c224665CC098A70FE4C1322218ae03511395;

    constructor() ERC721("GG", "CC")  {
        setBaseURI("https://badgameshow.com/");
    }

    function adopt(uint256 num) public payable {
        uint256 supply = totalSupply();
        require(num < 21, "You can adopt a maximum of 20 Cats");
        require(supply + num < 10000, "Exceeds maximum Cats supply" );
        require(msg.value >= _price * num, "Ether sent is not correct" );

        for(uint256 i; i < num; i++){
            _safeMint(msg.sender, supply + i);
        }
    }

    function walletOfOwner(address _owner) public view returns(uint256[] memory) {
        uint256 tokenCount = balanceOf(_owner);

        uint256[] memory tokensId = new uint256[](tokenCount);
        for(uint256 i; i < tokenCount; i++){
            tokensId[i] = tokenOfOwnerByIndex(_owner, i);
        }
        return tokensId;
    }

    function setWithdrawAddress(address _newAddress) public onlyOwner() {
        _withdrawAddress = _newAddress;
    }

    function setBaseURI(string memory baseURI) public onlyOwner {
        _baseTokenURI = baseURI;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }

    function withdrawAll() public payable onlyOwner {
        require(payable(_withdrawAddress).send(address(this).balance));
    }
}