// SPDX-License-Identifier: MIT

/// @dev SWC-103 (Floating pragma)
// you need ^ in the version for remix
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./Mintable.sol";

/// @title A contract that mints NFT tokens
/// @author kyle reynolds
contract BitBirds is ERC721Enumerable, Ownable, Mintable {
    /// @notice storage variables
    using Strings for uint256;
    /// @dev baseURI for example: https://bitbirds.herokuapp.com/metadata/
    string public baseURI;
    /// @dev set baseExtension to .json
    /// @dev you need this since ipfs is adding it when ipfs is hosting the NFT json
    /// @dev https://gateway.pinata.cloud/ipfs/QmYrVgtkHnXDw9KURzgSbmejgzpEcje6FV5AofEmBx98kz/1.json
    string public baseExtension = ".json";
    /// @dev cost for each nft
    uint256 public cost = 0.01 ether;
    /// @dev max supply of NFT tokens
    uint256 public maxSupply = 1000;
    /// @dev max amount a wallet can mint
    uint256 public maxMintAmount = 3;
    /// @dev paused boolean for pausing the smart contract
    bool public paused = false;

    /// @notice events
    /// @notice emit when a new token id is minted
    /// @param _newTokenId is the new token id
    event printNewTokenId(uint256 _newTokenId);

    /// @notice modifiers placeholder

    /// @notice constructor
    /// @dev SWC-118 (Incorrect Constructor Name)
    /// @dev Initializes the contract setting the name, symbol and baseURI. Also mints 5 NFTs to the contract owner.
    /// @param _name is the name of the NFT collection
    /// @param _symbol is the symbol of the NFT collection
    /// @param _initBaseURI is the baseURI of the NFT collection
    constructor(
        address _owner,
        string memory _name,
        string memory _symbol,
        address _imx,
        string memory _initBaseURI
    ) ERC721(_name, _symbol) Mintable(_owner, _imx) {
        setBaseURI(_initBaseURI);
    }

    function _mintFor(
        address user,
        uint256 id,
        bytes memory
    ) internal override {
        _safeMint(user, id);
    }

    /// @notice internal functions
    /// @dev returns baseURI and overrides built in function
    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }

    /// @notice public functions
    /// @dev mints X number of NFTs by passing mintAmount
    /// @param _mintAmount is the number of NFTs the user wants to mint
    function mint(uint256 _mintAmount) public payable {
        uint256 supply = totalSupply();
        /// @dev contract cannot be paused
        require(!paused, "Contract cannot be paused.");
        /// @dev mint amount greater then 0
        require(_mintAmount > 0, "Mint amount has to be greater then 0.");
        /// @dev current supply + mintAmount has to be less then maxSupply
        require(supply + _mintAmount <= maxSupply, "The current supply plus your mint amount has to be less then or equal to the max supply.");

        /// @dev if msg.sender is not the owner
        if (msg.sender != owner()) {
            /// @dev the balance of the sender plus the amount they want to mint has to be less then the max mint amount
            require(balanceOf(msg.sender) + _mintAmount <= maxMintAmount, "You can only purchase 3 tokens");
            /// @dev charge them
            /// @dev SWC-105 Unprotected Ether Withdrawal vector attack protection
            require(msg.value >= cost * _mintAmount);
        }

        /// @dev supply starts at 0 and goes up by 1 each time
        /// @dev i starts at 1 for each minting round
        /// @dev for example, if the first buyer only bought 1, it would be supply(0) + i(1) = 1 --> 1 for the token tokenId
        /// @dev next round, the buyer buys 2, it would be supply(1) + i(1) && supply(1) + i(2) --> 2 and 3 for the tokenIds
        for (uint256 i = 1; i <= _mintAmount; i++) {
            uint256 newTokenId = supply + i;
            _safeMint(msg.sender, newTokenId);
            emit printNewTokenId(newTokenId);
        }
    }

    /// @notice passes in the wallet address and returns what token ids that wallet owns
    /// @param _owner is the wallet address the function takes in
    function walletOfOwner(address _owner) public view returns (uint256[] memory) {
        uint256 ownerTokenCount = balanceOf(_owner);
        uint256[] memory tokenIds = new uint256[](ownerTokenCount);
        for (uint256 i; i < ownerTokenCount; i++) {
            tokenIds[i] = tokenOfOwnerByIndex(_owner, i);
        }
        return tokenIds;
    }

    /// @notice pass in the tokenId and return the baseURI for that token
    /// @param tokenId you want to get the baseURI for
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

        string memory currentBaseURI = _baseURI();
        return bytes(currentBaseURI).length > 0 ? string(abi.encodePacked(currentBaseURI, tokenId.toString(), baseExtension)) : "";
    }

    /// @notice override renounce ownership so you don't accidently call it
    /// @dev if this is called, the contract does not have an owner anymore
    function renounceOwnership() public pure override {
        revert("Can't renounce ownership here");
    }

    /// @notice only owner functions
    /// @dev set new cost function
    /// @param _newCost is the new cost for one NFT
    function setCost(uint256 _newCost) public onlyOwner {
        cost = _newCost;
    }

    /// @notice set max mint amount function
    /// @param _newMaxMintAmount the new max mint amount per user
    function setmaxMintAmount(uint256 _newMaxMintAmount) public onlyOwner {
        maxMintAmount = _newMaxMintAmount;
    }

    /// @notice set base uri function
    /// @param _newBaseURI the new base URI for the tokens
    function setBaseURI(string memory _newBaseURI) public onlyOwner {
        baseURI = _newBaseURI;
    }

    /// @notice set base extension function
    /// @param _newBaseExtension the new base extension instead of .json
    function setBaseExtension(string memory _newBaseExtension) public onlyOwner {
        baseExtension = _newBaseExtension;
    }

    /// @notice update pause state
    /// @param _state the pause state, can be true or false
    function pause(bool _state) public onlyOwner {
        paused = _state;
    }

    /// @notice get balance of contract
    function getBalance() public view onlyOwner returns (uint256) {
        return address(this).balance;
    }

    /// @notice withdraw to owner
    /// @dev SWC-105 (Unprotected Ether Withdrawal)
    function withdraw() public payable onlyOwner {
        payable(owner()).transfer(getBalance());
    }
}