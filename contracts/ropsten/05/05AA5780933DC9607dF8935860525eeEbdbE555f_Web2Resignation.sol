// SPDX-License-Identifier: UNLISENCE
pragma solidity ^0.8.4;

import '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import '@openzeppelin/contracts/access/Ownable.sol';

contract Web2Resignation is ERC721, Ownable {
    uint256 public mintPrice = 0.00 ether;
    uint256 public totalSupply; 
    uint256 public maxSupply = 1000;
    bool public isMintEnabled = true;
    uint256 public constant MAX_MINTS_PER_TX = 2;
    string private baseURI = "ipfs://QmYYgBY9de1gfs7DLg454ukGj2rjH7TGWS3PXN7yYtXzet";
    mapping (address => uint256) public mintedWallets;


    constructor () payable ERC721 ('Web2Resignation', 'QUIT') {
        maxSupply = 1000;
    }

    function toggleIsMintEnabled () external onlyOwner {
        isMintEnabled = !isMintEnabled;
    }

    function setMaxSupply(uint256 maxSupply_) external onlyOwner {
        maxSupply = maxSupply_;
    }

   function mint() external payable { 
        require (isMintEnabled, 'minting not enabled');
        require (mintedWallets [msg.sender] < 2, 'exceed max per wallet');
        require (msg.value == mintPrice, 'wrong value');
        require(maxSupply > totalSupply, 'sold out');

        mintedWallets [msg.sender]++;
        totalSupply++;
        uint256 tokenId = totalSupply;
        _safeMint(msg.sender, tokenId);
    }
    modifier maxMintsPerTX(uint256 numberOfTokens) {
        require(
            numberOfTokens <= MAX_MINTS_PER_TX,
            "Max mints per transaction exceeded"
        );
        _;
    }
        function withdraw() public onlyOwner {
        uint256 balance = address(this).balance;
        payable(msg.sender).transfer(balance);
        }
}