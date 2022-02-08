//SPDX-License-Identifier: MIT
/// @title NFT minting for artists
/// @author NFThing.co
/// @notice Use this contract for minting of art. It is gas optimized
/// @dev All function calls are currently implemented without side effects

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract NFThing is ERC721, Ownable {
    // =============================================================================
    //              Contract variables start here
    // =============================================================================
    using Strings for uint256; // uint256 variable can call up functions in the Strings library.e.g. value.toString()
    using Counters for Counters.Counter;

    Counters.Counter private _supply;

    string public uriPrefix = "";
    string public uriSuffix = ".json";

    uint256 public cost = 0.002 ether; // cost of minting
    uint256 public presaleCost = 0.001 ether; // presale offer cost
    uint256 public maxSupply = 100; // 10K NFT
    uint256 public maxMintAmountPerTx = 20; // max allowed to mint per transaction
    bool public paused = false; // pauses the minting functionality if needed
    mapping(address => bool) public whitelisted; // if you are whitelisted, you dont have to pay gas for minting
    mapping(address => bool) public presaleWallets; // for presale use presale cost for minting

    constructor(
        string memory _name,
        string memory _symbol,
        string memory _initBaseURI
    ) ERC721(_name, _symbol) {
        setUriPrefix(_initBaseURI);
        mint(20);
    }

    // =============================================================================
    //              Public functions start here
    // =============================================================================

    /// @notice modifier to check compliance
    /// @param _mintAmount the amount to be

    modifier mintCompliance(uint256 _mintAmount) {
        require(
            _mintAmount > 0 && _mintAmount <= maxMintAmountPerTx,
            "Invalid mint amount!"
        );
        require(
            _supply.current() + _mintAmount <= maxSupply,
            "Max supply exceeded!"
        );
        _; // resume with function execution
    }

    /// @notice gets the total supply of tokens
    /// @return total token supply

    function totalSupply() public view returns (uint256) {
        return _supply.current();
    }

    /// @notice regular mint function. Anyone can perform minting, need not be owner. It
    ///         does not make sense to mint for a receiver address if you are not the owner
    /// @param _mintAmount is the quantity of mint

    function mint(uint256 _mintAmount)
        public
        payable
        mintCompliance(_mintAmount)
    {
        require(!paused, "The contract is paused!");

        if (msg.sender != owner()) {
            if (whitelisted[msg.sender] != true) {
                if (presaleWallets[msg.sender] != true) {
                    //general public
                    require(
                        msg.value >= cost * _mintAmount,
                        "Insufficient funds!"
                    );
                } else {
                    //presale offer
                    require(
                        msg.value >= presaleCost * _mintAmount,
                        "Insufficient funds!"
                    );
                }
            }
        }
        _mintLoop(msg.sender, _mintAmount);
    }

    /// @notice mint tokens for a given address. You must be the owner to perform this
    /// @param _mintAmount is the quantity of mint
    /// @param _to is the address of the receiver for which minting must be done

    function mintForAddress(uint256 _mintAmount, address _to)
        public
        mintCompliance(_mintAmount)
        onlyOwner
    {
        _mintLoop(_to, _mintAmount);
    }

    /// @notice gets the token id's for an address
    /// @param _owner token ids for this address must be returned
    /// @return ownedTokenIds array of token ids for the given address

    function walletOfOwner(address _owner)
        public
        view
        returns (uint256[] memory)
    {
        uint256 ownerTokenCount = balanceOf(_owner);
        uint256[] memory ownedTokenIds = new uint256[](ownerTokenCount);
        uint256 currentTokenId = 1;
        uint256 ownedTokenIndex = 0;

        while (
            ownedTokenIndex < ownerTokenCount && currentTokenId <= maxSupply
        ) {
            address currentTokenOwner = ownerOf(currentTokenId);

            if (currentTokenOwner == _owner) {
                ownedTokenIds[ownedTokenIndex] = currentTokenId;
                ownedTokenIndex++;
            }

            currentTokenId++;
        }

        return ownedTokenIds;
    }

    /// @notice Returns the URI(set using setUriPrefix) for a given token ID.
    ///         May return an empty string.Reverts if the token ID does not exist.
    ///         This function is called by market places such as OpenSea, Rarible etc to
    ///         get the metadata associated with each token ID during display
    /// @param _tokenId token ids for this address must be returned
    /// @return string

    function tokenURI(uint256 _tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        require(
            _exists(_tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );

        string memory currentBaseURI = _baseURI();
        //  abi.encodePacked() does not use padding, uses minimal space
        // and used to serialize things
        return
            bytes(currentBaseURI).length > 0
                ? string(
                    abi.encodePacked(
                        currentBaseURI,
                        _tokenId.toString(),
                        uriSuffix
                    )
                )
                : "";
    }

    /// @notice function to set cost for minting.Need to be owner.
    /// @param _cost new cost for minting

    function setCost(uint256 _cost) public onlyOwner {
        cost = _cost;
    }

    /// @notice function to set presale cost for minting.Need to be owner.
    /// @param _newCost new presale cost for minting

    function setPresaleCost(uint256 _newCost) public onlyOwner {
        presaleCost = _newCost;
    }

    /// @notice function to set maxMintAmoutPerTx.Need to be owner.
    /// @param _maxMintAmountPerTx max mint amount per transaction

    function setMaxMintAmountPerTx(uint256 _maxMintAmountPerTx)
        public
        onlyOwner
    {
        maxMintAmountPerTx = _maxMintAmountPerTx;
    }

    /// @notice function to set URI prefix.Need to be owner.
    /// @param _uriPrefix new uri prefix

    function setUriPrefix(string memory _uriPrefix) public onlyOwner {
        uriPrefix = _uriPrefix;
    }

    /// @notice function to set URI suffix.Need to be owner.
    /// @param _uriSuffix new uri suffix

    function setUriSuffix(string memory _uriSuffix) public onlyOwner {
        uriSuffix = _uriSuffix;
    }

    /// @notice function to set pause.Need to be owner.
    /// @param _state set new pause state (true or false)

    function setPaused(bool _state) public onlyOwner {
        paused = _state;
    }

    /// @notice function to whitelist a user.Need to be owner.
    /// @param _user user address to add to the whitelist

    function whitelistUser(address _user) public onlyOwner {
        whitelisted[_user] = true;
    }

    /// @notice function to remove user from whitelist.Need to be owner.
    /// @param _user user address to remove from the whitelist

    function removeWhitelistUser(address _user) public onlyOwner {
        whitelisted[_user] = false;
    }

    /// @notice function to add user to presale wallet.Need to be owner.
    /// @param _user user address to add to the presaleWallet

    function addPresaleUser(address _user) public onlyOwner {
        presaleWallets[_user] = true;
    }

    /// @notice function to remove user from presale wallet.Need to be owner.
    /// @param _user user address to remove from the presale wallet

    function removePresaleUser(address _user) public onlyOwner {
        presaleWallets[_user] = false;
    }

    /// @notice  This will transfer the contract balance to the owner.Need to be owner.
    ///          Do not remove this otherwise you will not be able to withdraw the funds.

    function withdraw() public onlyOwner {
        (bool os, ) = payable(owner()).call{value: address(this).balance}("");
        require(os, "Failed to withdraw amount!");
    }

    // =============================================================================
    //              Internal functions start here
    // =============================================================================

    /// @notice Does the actual minting using ERC721's safe mint.
    ///         Minting starts from token id = 1,2,3...10K
    /// @param _mintAmount is the quantity of mint.
    /// @param _receiver address for minting.

    function _mintLoop(address _receiver, uint256 _mintAmount) internal {
        for (uint256 i = 0; i < _mintAmount; i++) {
            _supply.increment();
            _safeMint(_receiver, _supply.current());
        }
    }

    /// @notice returns the base uri
    /// @return base uri
    function _baseURI() internal view virtual override returns (string memory) {
        return uriPrefix;
    }
}