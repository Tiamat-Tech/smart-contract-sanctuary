// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./ERC721A.sol";

contract waoo is ERC721A, Ownable, ReentrancyGuard {
    uint256 public immutable amountForDrop;
    uint256 public immutable amountForTeam;
    uint256 public immutable totalMintable;

    uint256 public startTime;
    uint256 public endTime;

    bool public isDropped = false;
    bool public isTeamMinted = false;

    uint64 public immutable unitPrice = 0.025 ether;

    string private _baseTokenURI;

    modifier isCallerAUser() {
        require(tx.origin == msg.sender, "The caller is another contract");
        _;
    }

    modifier isPublicMint() {
        assert(block.timestamp >= startTime && block.timestamp < endTime);
        _;
    }

    constructor(
        uint256 maxBatchSize_,
        uint256 collectionSize_,
        uint256 amountForDrop_,
        uint256 amountForTeam_
    ) ERC721A("waoo", "waoo", maxBatchSize_, collectionSize_) {
        totalMintable = collectionSize_;
        amountForDrop = amountForDrop_;
        amountForTeam = amountForTeam_;
    }

    function setPublicMintTime(uint256 _startTime, uint256 _endTime)
        external
        onlyOwner
    {
        startTime = _startTime;
        endTime = _endTime;
    }

    function publicMint(uint256 quantity)
        external
        payable
        isCallerAUser
        isPublicMint
    {
        require(
            totalSupply() + quantity <= totalMintable,
            "All tokens are minted."
        );
        require(msg.value >= unitPrice * quantity, "Need to send more ETH.");
        _safeMint(msg.sender, quantity);
    }

    function numberMinted(address owner) public view returns (uint256) {
        return _numberMinted(owner);
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }

    // owners only

    function airdrop(address[] memory addresses) external onlyOwner {
        require(
            totalSupply() + addresses.length <= totalMintable,
            "All tokens are minted."
        );

        require(
            addresses.length <= amountForDrop,
            "Quantity to drop is too high."
        );

        for (uint256 i = 0; i < addresses.length; i++) {
            _safeMint(addresses[i], 1);
        }
    }

    function teamMint(address[] memory addresses, uint256[] memory amount)
        external
        onlyOwner
    {
        require(isTeamMinted == false, "Already minted for team.");

        require(
            addresses.length == amount.length,
            "addresses does not match amount length"
        );

        require(
            totalSupply() + addresses.length <= totalMintable,
            "All tokens are minted."
        );

        uint256 totalToMint = 0;
        for (uint256 i = 0; i < amount.length; i++) {
            totalToMint += amount[i];
        }

        require(totalToMint <= amountForTeam, "Quantity to mint is too high.");

        for (uint256 i = 0; i < addresses.length; i++) {
            _safeMint(addresses[i], amount[i]);
        }

        isTeamMinted = true;
    }

    function setBaseURI(string calldata baseURI) external onlyOwner {
        _baseTokenURI = baseURI;
    }

    function setOwnersExplicit(uint256 quantity)
        external
        onlyOwner
        nonReentrant
    {
        _setOwnersExplicit(quantity);
    }

    function withdrawMoney() external onlyOwner nonReentrant {
        (bool success, ) = msg.sender.call{value: address(this).balance}("");
        require(success, "Transfer failed.");
    }
}