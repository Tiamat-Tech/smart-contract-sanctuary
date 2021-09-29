// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import './ERC721Burnable.sol';

/**
 * @title SeaFairy contract
 * @dev Extends ERC721 Non-Fungible Token Standard basic implementation
 */


contract SeaFairy is ERC721Burnable {
    using SafeMath for uint256;

    uint256 public mintPrice;
    uint256 public maxPublicToMint;
    uint256 public maxPresaleToMint;
    uint256 public maxNftSupply; 
    uint256 public maxPresaleSupply;
    uint256 public curTicketId;
    uint256 public currentMintCount;

    mapping(address => uint256) public presaleNumOfUser;
    mapping(address => uint256) public publicNumOfUser;
    mapping(address => uint256) public totalClaimed;

    address private wallet1;
    address private wallet2;

    bool public presaleAllowed;
    bool public publicSaleAllowed;    
    uint256 public presaleStartTimestamp;
    uint256 public publicSaleStartTimestamp;    

    mapping(address => bool) private presaleWhitelist;

    constructor() ERC721("Sea Fairy", "SFT") {
        maxNftSupply = 10000;
        maxPresaleSupply = 3333;
        mintPrice = 0.068 ether;
        maxPublicToMint = 15;
        maxPresaleToMint = 3;
        curTicketId = 0;

        presaleAllowed = false;
        publicSaleAllowed = false;

        presaleStartTimestamp = 0;
        publicSaleStartTimestamp = 0;        

        wallet1 = 0x2075252c9e00381FCDDdB0f0967B6Cb7892ca745;
        wallet2 = 0x2075252c9e00381FCDDdB0f0967B6Cb7892ca745;
    }

    function tokensOfOwner(address _owner) external view returns(uint256[] memory) {
        uint256 tokenCount = balanceOf(_owner);
        if (tokenCount == 0) {
            return new uint256[](0);
        } else {
            uint256[] memory result = new uint256[](tokenCount);
            for (uint256 index; index < tokenCount; index++) {
                result[index] = tokenOfOwnerByIndex(_owner, index);
            }
            return result;
        }
    }

    function exists(uint256 _tokenId) public view returns (bool) {
        return _exists(_tokenId);
    }

    function isPresaleLive() public view returns(bool) {
        uint256 curTimestamp = block.timestamp;
        if (presaleAllowed && presaleStartTimestamp <= curTimestamp && curTicketId < maxPresaleSupply) {
            return true;
        }
        return false;
    }

    function isPublicSaleLive() public view returns(bool) {
        uint256 curTimestamp = block.timestamp;
        if (publicSaleAllowed && publicSaleStartTimestamp <= curTimestamp) {
            return true;
        }
        return false;
    }


    function setMintPrice(uint256 _price) external onlyOwner {
        mintPrice = _price;
    }

    function setMaxNftSupply(uint256 _maxValue) external onlyOwner {
        maxNftSupply = _maxValue;
    }

    function setMaxPresaleSupply(uint256 _maxValue) external onlyOwner {
        maxPresaleSupply = _maxValue;
    }

    function setMaxPresaleToMint(uint256 _maxValue) external onlyOwner {
        maxPresaleToMint = _maxValue;
    }

    function setMaxPublicToMint(uint256 _maxValue) external onlyOwner {
        maxPublicToMint = _maxValue;
    }

    function reserveFairy(address _to, uint256 _numberOfTokens) external onlyOwner {
        require(_to != address(0), "Invalid address to reserve.");
        require(curTicketId.add(_numberOfTokens) <= maxNftSupply, "Reserve would exceed max supply");
        
        uint256 mintIndex = currentMintCount;

        currentMintCount = currentMintCount.add(_numberOfTokens);
        curTicketId = curTicketId.add(_numberOfTokens);
                
        for (uint256 i = 0; i < _numberOfTokens; i++) {
            _safeMint(_to, mintIndex + i);
        }
    }

    function setBaseURI(string memory baseURI) external onlyOwner {
        _setBaseURI(baseURI);
    }

    function updatePresaleState(bool newStatus, uint256 timestamp) external onlyOwner {
        presaleAllowed = newStatus;
        presaleStartTimestamp = timestamp;
    }

    function updatePublicSaleState(bool newStatus, uint256 timestamp) external onlyOwner {
        publicSaleAllowed = newStatus;
        publicSaleStartTimestamp = timestamp;
    }

    function addToPresale(address[] calldata addresses) external onlyOwner {
        for (uint256 i = 0; i < addresses.length; i++) {
            presaleWhitelist[addresses[i]] = true;
        }
    }

    function removeFromPresale(address[] calldata addresses) external onlyOwner {
        for (uint256 i = 0; i < addresses.length; i++) {
            presaleWhitelist[addresses[i]] = false;
        }
    }

    function isInWhitelist(address user) external view returns (bool) {
        return presaleWhitelist[user];
    }

    function doPresale(uint256 numberOfTokens) external payable {
        uint256 numOfUser = presaleNumOfUser[_msgSender()];

        require(isPresaleLive(), "Presale has not started yet");
        require(presaleWhitelist[_msgSender()], "You are not on white list");
        require(numberOfTokens.add(numOfUser) <= maxPresaleToMint, "Exceeds max presale allowed per user");
        require(curTicketId.add(numberOfTokens) <= maxPresaleSupply, "Exceeds max presale supply");
        require(numberOfTokens > 0, "Must mint at least one token");
        require(mintPrice.mul(numberOfTokens) <= msg.value, "Ether value sent is not correct");

        presaleNumOfUser[_msgSender()] = numberOfTokens.add(numOfUser);
        curTicketId = curTicketId.add(numberOfTokens);
    }

    function doPublic(uint256 numberOfTokens) external payable {
        uint256 numOfUser = publicNumOfUser[_msgSender()];
        require(isPublicSaleLive(), "Public sale has not started yet");
        require(numberOfTokens.add(numOfUser) <= maxPublicToMint, "Exceeds max public sale allowed per user");
        require(curTicketId.add(numberOfTokens) <= maxNftSupply, "Exceeds max supply");
        require(numberOfTokens > 0, "Must mint at least one token");
        require(mintPrice.mul(numberOfTokens) <= msg.value, "Ether value sent is not correct");

        publicNumOfUser[_msgSender()] = numberOfTokens.add(numOfUser);
        curTicketId = curTicketId.add(numberOfTokens);
    }

    function getUserClaimableTicketCount(address user) public view returns (uint256) {
        return presaleNumOfUser[user].add(publicNumOfUser[user]).sub(totalClaimed[user]);
    }

    function claimFairy() external {
        uint256 numbersOfTickets = getUserClaimableTicketCount(_msgSender());
        
        totalClaimed[_msgSender()] = numbersOfTickets.add(totalClaimed[_msgSender()]);

        uint256 mintIndex = currentMintCount;

        currentMintCount = currentMintCount.add(numbersOfTickets);

        for(uint256 i = 0; i < numbersOfTickets; i++) {
            _safeMint(_msgSender(), mintIndex + i);
        }
    }

    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        uint256 balance2 = balance.mul(15).div(100);
        payable(wallet2).transfer(balance2);   
        payable(wallet1).transfer(balance.sub(balance2));
    }
}