//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Pcwars is ERC721, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private tokenIds;
    uint public totalSupply = 100; // DO ZMIANY NA 10k
    uint public maxPresaleTokens = 25; // DO ZMIANY NA 2.5k
    uint public maxTokensOnPresale = 5; // per wallet
    uint public maxTokensOnSale = 5; // per transaction
    uint public maxTokensToMintPerAddress = 15; // max per wallet
    uint public priceChangeThreshold = totalSupply / 2;

    // Prices
    uint private price = 0.02 ether;
    uint private presalePrice = 0.015 ether;

    string private notRevealedJson = "ipfs://QmVHzfEQJygZyQGcRyog4fz1vhw6bbmM89iBUtdbtnrUmm";

    bool public presaleActive = false;
    bool public publicSaleActive = false;
    bool public isRevealed = false;


    mapping(address => bool) public presaleWhitelist;
    mapping(address => uint) public mintedPerWallet;

    string private ipfsBaseURI = "";
    constructor () ERC721 ("PCwars", "PCW"){
    }

    function setBaseURI(string memory _baseURI) public onlyOwner {
        ipfsBaseURI = _baseURI;
    }

    function setPresaleActive() public onlyOwner {
        require(!isSaleActive(), "Sale already started!");
        presaleActive = true;
    }

    function setPublicSaleActive() public onlyOwner {
        require(presaleActive, "Presale is not active! Run setPresaleActive() first!");
        publicSaleActive = true;
        presaleActive = false;
    }

    function revealTokens() public onlyOwner {
        require(!isRevealed, "Tokens already revealed!");
        require(bytes(ipfsBaseURI).length > 0, "BaseURI not set!");
        isRevealed = true;
    }

    function addToWhitelist(address[] memory _addresses) public onlyOwner {
        require(!publicSaleActive, "Presale already ended!");
        require(_addresses.length >= 1, "You need to send at least one address!");
        for(uint i = 0; i < _addresses.length; i++) {
            presaleWhitelist[address(_addresses[i])] = true;
        }
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        if(isRevealed) {
            require(_exists(tokenId), "URI query for nonexistent token");
            return string(abi.encodePacked("ipfs://", ipfsBaseURI, "/", uint2str(tokenId), ".json"));
        }
        return notRevealedJson;
    }

    function isSaleActive() public view returns(bool) {
        if(presaleActive || publicSaleActive) {
            return true;
        }
        return false;
    }

    function getPrice() public view returns(uint) {
        if(publicSaleActive) {
            if(tokenIds.current() > priceChangeThreshold) {
                return price;
            } else {
                return presalePrice;
            }            
        } else if(presaleActive) {
            return presalePrice;
        }
        return 0;
    }

    function currentSupply() public view returns(uint) {
        return tokenIds.current();
    }

    function withdrawBalance() public onlyOwner {
        (bool success, ) = payable(owner()).call{value:address(this).balance}("");
        require(success, "Withdrawal failed!");
    }

    receive() external payable {
        //Function to recieve Ether through normal transaction
    }

    function createCollectible(uint256 _amount) public payable {
        require(isSaleActive(), "Sale not started yet!");
        require(_amount + mintedPerWallet[msg.sender] <= maxTokensToMintPerAddress, string(abi.encodePacked("Not allowed to mint more than ", uint2str(maxTokensToMintPerAddress), " token(s) per wallet!")));
        require(msg.value >= getPrice() * _amount, string(abi.encodePacked("Not enough ETH! At least ", uint2str(getPrice()*_amount), " wei has to be sent!")));
        if(presaleActive) {
            require(mintedPerWallet[msg.sender] < maxTokensOnPresale, string(abi.encodePacked("You can't mint more than ", uint2str(maxTokensOnPresale), " token(s) on presale per wallet!")));
            require(presaleWhitelist[msg.sender], "You are not whitelisted to participate on presale!");
            require(_amount > 0 && _amount < maxTokensOnPresale + 1, string(abi.encodePacked("You can buy between 1 and ",  uint2str(maxTokensOnPresale), " tokens per transaction.")));
            require(maxPresaleTokens > _amount + tokenIds.current() + 1, "Not enough presale tokens left!");
        } else {
            require(_amount > 0 && _amount < maxTokensOnSale + 1, string(abi.encodePacked("You can buy between 1 and ",  uint2str(maxTokensOnSale), " tokens per transaction.")));
            require(totalSupply > _amount + tokenIds.current() + 1, "Not enough tokens left!");
        }

        for(uint256 i = 0; i < _amount; i++) {
            tokenIds.increment();
            uint256 newItemId = tokenIds.current();
            _safeMint(msg.sender, newItemId);
            mintedPerWallet[msg.sender]++;
        }
    }
    function uint2str(uint _i) internal pure returns (string memory _uintAsString) {
        if (_i == 0) {
            return "0";
        }
        uint j = _i;
        uint len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint k = len;
        while (_i != 0) {
            k = k-1;
            uint8 temp = (48 + uint8(_i - _i / 10 * 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            _i /= 10;
        }
        return string(bstr);
    }
}