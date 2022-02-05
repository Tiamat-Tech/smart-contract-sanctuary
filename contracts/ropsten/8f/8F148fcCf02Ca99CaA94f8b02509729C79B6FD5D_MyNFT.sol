//Contract based on [https://docs.openzeppelin.com/contracts/3.x/erc721](https://docs.openzeppelin.com/contracts/3.x/erc721)
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract MyNFT is ERC721, Ownable {
    using Counters for Counters.Counter;
    using Strings for uint256;

    Counters.Counter private _tokenIds;
    string private _tokenURI;
    string private _contractURI;

    uint256 public maxSupply = 500;
    uint256 public tokenPrice = 0.5 ether;
    bool public saleStarted = false;
    bool public transfersEnabled = false;

    constructor() ERC721("MyNFT", "MYNFT") {}

    /**
     * @notice Function modifier that is used to determine if the caller is
     * the owner. If not, run additional checks before proceeding.
     */
    modifier nonOwner(address to) {
        if (msg.sender != owner()) {
            require(
                transfersEnabled,
                "Token transfers are currently disabled."
            );
            require(balanceOf(to) == 0, "User already holds a token.");
        }
        _;
    }

    /**
     * @notice Allows a user to mint a token for MYNFT.
     */
    function mint() public payable {
        uint256 tokenIndex = _tokenIds.current() + 1;

        require(tx.origin == msg.sender, "No contracts");
        require(saleStarted, "Sale not started");
        require(balanceOf(msg.sender) == 0, "Only one token per user");
        require(msg.value == tokenPrice, "Wrong ETH amount sent");
        require(
            tokenIndex <= maxSupply,
            "Minted token would exceed max supply"
        );

        _tokenIds.increment();

        _safeMint(msg.sender, tokenIndex);
    }

    /**
     * @notice Allows an owner to mint a free token to anyone, callable only by the owner.
     *
     * @param _receiver Address to send the token to.
     */
    function ownerMint(address _receiver) public onlyOwner {
        uint256 tokenIndex = _tokenIds.current() + 1;

        require(_receiver != address(0), "Cannot send NFT to zero address");
        require(
            tokenIndex <= maxSupply,
            "Minted token would exceed max supply"
        );

        if (msg.sender != _receiver) {
            require(balanceOf(_receiver) == 0, "Only one token per user");
        }

        _tokenIds.increment();

        _safeMint(msg.sender, tokenIndex);
    }

    /**
     * @notice Updates the price per token, callable only by the owner.
     *
     * @param _updatedPrice The new token price in units of wei.
     */
    function updateTokenPrice(uint256 _updatedPrice) external onlyOwner {
        require(tokenPrice != _updatedPrice, "Price is not changing");
        tokenPrice = _updatedPrice;
    }

    /**
     * @notice Gets the token URI for a specific token ID.
     *
     * @param _tokenId The token ID to fetch the token URI for.
     *
     * @return Returns a string value representing the token URI for the
     * specified token.
     */
    function tokenURI(uint256 _tokenId)
        public
        view
        override
        returns (string memory)
    {
        require(_exists(_tokenId), "Token does not exist.");
        return string(abi.encodePacked(_tokenURI, _tokenId.toString()));
    }

    /**
     * @notice Function that is used to update the token URI for the contract,
     * only callable by the owner.
     *
     * @param tokenURI_ A string value to replace the current '_tokenURI' value.
     */
    function setTokenURI(string calldata tokenURI_) external onlyOwner {
        _tokenURI = tokenURI_;
    }

    /**
     * @notice Function that is used to get the contract URI.
     *
     * @return Returns a string value representing the contract URI.
     */
    function contractURI() public view returns (string memory) {
        return _contractURI;
    }

    /**
     * @notice Function that is used to update the contract URI, only callable
     * by the owner.
     *
     * @param contractURI_ A string value to replace the current 'contractURI_'.
     */
    function setContractURI(string calldata contractURI_) external onlyOwner {
        _contractURI = contractURI_;
    }

    /**
     * @notice Function that is used to withdraw the balance of the contract,
     * only callable by the owner.
     */
    function withdrawBalance() public onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }

    /**
     * @notice Function that is used to flip the sale state of the contract,
     * only callable by the owner.
     */
    function toggleSale() public onlyOwner {
        saleStarted = !saleStarted;
    }

    /**
     * @notice Function that is used to flip the transfer state of the contract,
     * only callable by the owner.
     */
    function toggleTransfers() public onlyOwner {
        transfersEnabled = !transfersEnabled;
    }

    /**
     * @notice Function that is used to get the total tokens minted.
     *
     * @return Returns the total supply.
     */
    function totalSupply() public view returns (uint256) {
        return _tokenIds.current();
    }

    /**
     * @notice Function that is used to safely transfer a token from one owner to another,
     * this function has been overriden so that transfers can be disabled.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) public virtual override nonOwner(to) {
        require(
            _isApprovedOrOwner(_msgSender(), tokenId),
            "Transfer caller is not owner nor approved."
        );
        _safeTransfer(from, to, tokenId, _data);
    }

    /**
     * @notice Function that is used to transfer a token from one owner to another,
     * this function has been overriden so that transfers can be disabled.
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override nonOwner(to) {
        require(
            _isApprovedOrOwner(_msgSender(), tokenId),
            "Transfer caller is not owner nor approved."
        );
        _transfer(from, to, tokenId);
    }
}