// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Base64 } from "./lib/Base64.sol";

import '@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol';
import '@openzeppelin/contracts/access/Ownable.sol';


contract ColoredNumbers is ERC721Enumerable, Ownable {

    using Strings for uint256;

    string _baseTokenURI;
    uint256 private _price = 0.0001 ether;
    bool public _paused = false;

    mapping(uint256 => uint256) public mintedBlockNumber;

    constructor(string memory baseURI) ERC721("Colored Numbers", "COLORNUM")  {
        setBaseURI(baseURI);
    }

    function awardItem(uint256 num) public payable {
        uint256 supply = totalSupply();
        require( !_paused,                    "Sale paused" );
        require( num < 11,                    "You can mint a maximum of 10 NFTs at once");
        require( supply + num < 11,            "Exceeds maximum NFT supply" );
        require( msg.value >= _price * num,   "Ether sent is not correct" );

        for(uint256 i = 1; i <= num; i++) {
            _safeMint( msg.sender, supply + i );
            mintedBlockNumber[supply + i] = block.number;
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

    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }

    function setBaseURI(string memory baseURI) public onlyOwner {
        _baseTokenURI = baseURI;
    }

    function pause(bool val) public onlyOwner {
        _paused = val;
    }

    function withdrawAll(uint256 amount) public onlyOwner {
        require(amount <= getBalance());
        payable(msg.sender).transfer(amount);
    }

     function getBalance() public view returns (uint256) {
         return address(this).balance;
     }

    function seed(uint256 tokenId) public view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(blockhash(mintedBlockNumber[tokenId] - 1))));
    }

    function formatTokenURI(uint256 tokenId, uint256 tokenRandom, string memory imageURI) public pure returns (string memory) {
        return string(
            abi.encodePacked(
                "data:application/json;base64,",
                Base64.encode(
                    bytes(
                        abi.encodePacked(
                            '{',
                            '"name": "Colored Number ', tokenId.toString(), '"',
                            ', "description": "Colored Numbers description"',
                            ', "attributes": ""',
                            ', "image": "', imageURI, '.png"',
                            ', "seed": "',  tokenRandom.toString(), '"',
                            '}'
                        )
                    )
                )
            )
        );
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

        string memory baseURI = _baseURI();
        string memory imageURI = string(abi.encodePacked(baseURI, tokenId.toString()));
        return formatTokenURI(tokenId, seed(tokenId), imageURI);
    }

    // testOnly
    function destroy() public onlyOwner {
        selfdestruct(payable(owner()));
    }
}