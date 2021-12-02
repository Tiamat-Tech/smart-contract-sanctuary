// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title NFT
 * @dev Extends ERC721 Non-Fungible Token Standard basic implementation
 */
contract NFT is ERC721Enumerable, Ownable, ReentrancyGuard {
    using SafeMath for uint256;

    string private baseURI;

    bool private reveal;

    // Default token metrics
    uint256 private presalePrice = 0.07 ether;
    uint256 private publicPrice = 0.09 ether;
    uint256 private maxPurchase = 12;
    uint256 private MAX = 9999;
    uint256 private presaleAmount = 2997;

    //reservations for team and giveaway
    uint256 private numReservationsLeft = 500;
    
    // list for withdraw wallets.
    address[] private withdrawWallets;

    bool private presaleStatus;
    bool private publicStatus;

    // Mapping to store addresses allowed for presale, and how
    // many NFTs remain that they can purchase during presale.
    mapping (address => uint256) private presaleVouchers;

    constructor(string memory name, string memory symbol)
      ERC721(name, symbol) {}

    /**
     * @param newPrice The new price for an individual NFT.
     * @dev Sets a new price for an individual NFT.
     * @dev Can only be called by owner.
     */
    function setPresalePrice(uint256 newPrice) public onlyOwner {
        presalePrice = newPrice;
    }

    function getPresalePrice() public view returns(uint256) {
        return presalePrice;
    }

    function setPublicPrice(uint256 newPrice) public onlyOwner {
        publicPrice = newPrice;
    }

    function getPublicPrice() public view returns(uint256) {
        return publicPrice;
    }

    function walletOfOwner(address _owner) public view returns(uint256[] memory) {
        uint256 tokenCount = balanceOf(_owner);

        uint256[] memory tokensId = new uint256[](tokenCount);
        for(uint256 i; i < tokenCount; i++){
            tokensId[i] = tokenOfOwnerByIndex(_owner, i);
        }
        return tokensId;
    }

    /**
     * @param newmaxPurchase The new maximum number of NFT that can be minted per transaction.
     * @dev Sets the new maximum number of NFT purchases per transaction.
     * @dev Can only be called by owner.
     */
    function setmaxPurchase(uint256 newmaxPurchase) public onlyOwner {
        maxPurchase = newmaxPurchase;
    }

    /**
     * @param numNFT The number of NFT to reserve.
     * @dev Reserves NFT for giveaways.
     * @dev Will not allow reservations above maximum reserve threshold.
     * @dev Can only be called by owner.
     */
    function reserveNFT(uint256 numNFT) public onlyOwner {
        require(numNFT <= numReservationsLeft, "NFT: Reservations would exceed max reservation threshold of 500.");
        require(totalSupply().add(numNFT) <= MAX, "NFT: Reservations would exceed max supply of NFT.");
        
        for (uint256 i = 0; i < numNFT; i++) {
            _safeMint(msg.sender, totalSupply() + 1);

            // Reduce num reservations left
            numReservationsLeft = numReservationsLeft.sub(1);
        }
    }

    function getReservedAmount() public view returns(uint256) {
        return numReservationsLeft;
    }

    /**
     * @param newPresaleAddresses Addresses to be added to the list of verified presale addresses.
     * @param voucherAmount Amount of presale NFT to give per address.
     * @dev Can only be called by owner.
     */
    function addPresaleAddresses(address[] memory newPresaleAddresses, uint256 voucherAmount) public onlyOwner {
        for (uint256 i = 0; i < newPresaleAddresses.length; i++) {
            address presaleAddress = newPresaleAddresses[i];
            require(presaleAddress != address(0), "NFT: Cannot add burn address to the presale.");
            require(voucherAmount <= 3, "NFT: Max voucher per presale address is 3 vouchers.");
            presaleVouchers[presaleAddress] = voucherAmount;
        }
    }

    function checkPresaleAddress(address _entry) public view returns(uint256) {
        return presaleVouchers[_entry];
    }

    function checkPresaleAmount() public view returns(uint256) {
        return presaleAmount;
    }

    /**
     * @param URI The base URI for the contract's NFTs.
     * @dev Can only be called by owner.
     */
     
    function setBaseURI(string memory URI) public onlyOwner {
        baseURI = URI;
    }

    function _baseURI() internal view virtual override returns(string memory) {
        return baseURI;
    }

    function revealMetadata() public onlyOwner {
        reveal = !reveal;
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        if (!reveal) {
            string memory _tokenURI = "https://simg.nicepng.com/png/small/865-8652013_question-mark-bigger-question-mark-pixel-art.png";
            return _tokenURI;
        }
        return super.tokenURI(tokenId);
    }

    
    function setPresaleState() public onlyOwner {
        presaleStatus = !presaleStatus;
    }

    function setPublicState() public onlyOwner {
        publicStatus = !publicStatus;
    }

    function getSaleState() public view returns(string memory) {
        string memory saleStates;
        if (presaleStatus && publicStatus) {
            saleStates = "Public Sale is live";
        }
        else if (presaleStatus && !publicStatus) {
            saleStates = "Presale is Live";
        }
        else {
            saleStates = "Sale is not started";
        }
        return saleStates;
    }

    /**
     * @param numberOfTokens The number of tokens to be minted.
     * @dev Non-reentrant, minting entry point.
     */
    function mintNFT(uint256 numberOfTokens) public payable nonReentrant {
        require(presaleStatus || publicStatus, "NFT: Sale must be active or in presale mint NFT.");
        require(numberOfTokens <= maxPurchase, "NFT: Please try to mint a lower amount of NFTs");

        if (presaleStatus && presaleVouchers[msg.sender] != 0) {
            require(presaleVouchers[msg.sender] >= numberOfTokens, "NFT: You don't not have enough presale vouchers to mint that many NFT.");
            require(presalePrice.mul(numberOfTokens) <= msg.value, "NFT: Ether value sent is not correct.");
            require(totalSupply().add(numberOfTokens) <= MAX, "NFT: Purchase would exceed max supply of NFTs.");
            
            for (uint256 i = 0; i < numberOfTokens; i++) {
                presaleAmount -= 1;
                presaleVouchers[msg.sender] -= 1;
                _safeMint(msg.sender, totalSupply() + 1);
            }
        }
        else {
            require(publicPrice.mul(numberOfTokens) <= msg.value, "NFT: Ether value sent is not correct.");
            require(totalSupply().add(numberOfTokens) <= MAX.sub(presaleAmount), "NFT: Purchase would exceed max supply of NFTs.");
            for (uint256 i = 0; i < numberOfTokens; i++) {
                _safeMint(msg.sender, totalSupply() + 1);
            }
        }
    }

    function setWallets(address[] memory _listWallets) public onlyOwner {
        for (uint256 i; i < _listWallets.length; i++) {
            address _wallet = _listWallets[i];
            withdrawWallets.push(_wallet);
        }
    }

    /**
     * @dev Withdraws all contract funds and distributes across treasury wallets.
     * @dev Can only be called by owner.
     */
     
    function checkBalance() public view onlyOwner returns(uint256) {
        return address(this).balance;
    }

    function withdrawAll() public onlyOwner {
        uint256 balance = address(this).balance;
        uint256 split = balance/withdrawWallets.length;
        for (uint256 i = 0; i < withdrawWallets.length; i++) {
            address _withdrawWallet = withdrawWallets[i];
            payable(_withdrawWallet).transfer(split);
        }
    }

    function deleteContract() public onlyOwner {
        address payable owner = payable(msg.sender);
        selfdestruct(owner);
    }
}