// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./ERC721A.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/finance/PaymentSplitter.sol";

contract TMTERC721A is Ownable, ERC721A, ReentrancyGuard, PaymentSplitter {
    //To concatenate the URL of an NFT
    using Strings for uint256;

    //Size of collection just for displaying it in the front
    uint public MAX_SUPPLY;

    //Max allowed to mint by address 
    uint256 public immutable maxPerAddressDuringMint;

    //To check the addresses in the whitelist
    bytes32 public merkleRoot;

    //The different stages of selling the collection
    enum Steps {
        Before,
        Presale,
        Sale,
        SoldOut,
        Reveal
    }
    Steps public sellingStep;

    //URI of the NFTs when revealed
    string public baseURI;
    //URI of the NFTs when not revealed
    string public notRevealedURI;
    //The extension of the file containing the Metadatas of the NFTs
    string public baseExtension = ".json";

    //Are the NFTs revealed yet ?
    bool public revealed = false;

    //Is the contract paused ?
    bool public paused = false;

     //Owner of the smart contract
    address private _owner;

    //Price of one NFT in presale
    uint public pricePresale = 0.00025 ether;
    //Price of one NFT in sale
    uint public priceSale = 0.0003 ether;

    //Addresses of all the members of the team
    address[] private _team = [
        0x5B38Da6a701c568545dCfcB03FcB875f56beddC4,
        0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2,
        0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db
    ];

    //Shares of all the members of the team
    uint[] private _teamShares = [
        70,
        20, 
        10
    ];

    constructor(
        uint256 maxBatchSize_,
        uint256 collectionSize_,
        bytes32 _merkleRoot,
        string memory _theBaseURI, 
        string memory _notRevealedUri
    ) ERC721A("The Meta Tribes", "TMT", maxBatchSize_, collectionSize_) PaymentSplitter(_team, _teamShares) {
        maxPerAddressDuringMint = maxBatchSize_;
        merkleRoot = _merkleRoot;
        baseURI = _theBaseURI;
        notRevealedURI = _notRevealedUri;
        MAX_SUPPLY = collectionSize_;
    }

    modifier callerIsUser() {
        require(tx.origin == msg.sender, "The caller is another contract");
        _;
    }

    /**
    * @notice Allows to mint one NFT if whitelisted
    *
    * @param _account The account of the user minting the NFT
    * @param _proof The Merkle Proof
    **/
    function presaleMint(address _account, bytes32[] calldata _proof) external payable callerIsUser {
        //Are we in Presale ?
        require(sellingStep == Steps.Presale, "Presale has not started yet.");
        //Did this account already mint an NFT ?
        require(numberMinted(_account) < 1, "You can only get 1 NFT on the Presale");
        //Is this user on the whitelist ?
        require(isWhiteListed(_account, _proof), "Not on the whitelist");

        require(totalSupply() + 1 <= collectionSize, "Limit excedeed");
        //Get the price of one NFT during the Presale
        uint price = pricePresale;
        //Did the user send enought Ethers ?
        require(msg.value >= price, "Not enought funds.");
        if(totalSupply() + 1 == collectionSize) {
            sellingStep = Steps.SoldOut;   
        }
        //Mint the user NFT
        _safeMint(_account, 1);
    }

    function saleMint(uint256 _ammount) external payable callerIsUser {
        //Get the price of one NFT in Sale
        uint price = priceSale;
        //If everything has been bought
        require(sellingStep != Steps.SoldOut, "Sorry, no NFTs left.");
        //If Sale didn't start yet
        require(sellingStep == Steps.Sale, "Sorry, sale has not started yet.");
        //Did the user then enought Ethers to buy ammount NFTs ?
        require(msg.value >= price * _ammount, "Not enought funds.");
        //The user can only mint max 3 NFTs
        require(numberMinted(msg.sender) + _ammount <= maxPerAddressDuringMint, "You cannot mint this many");
        //If the user try to mint any non-existent token
        require(totalSupply() + _ammount <= collectionSize, "Sale is almost done and we don't have enought NFTs left.");
        if(totalSupply() + _ammount == collectionSize) {
            sellingStep = Steps.SoldOut;   
        }
        _safeMint(msg.sender, _ammount);
    }


    function numberMinted(address owner) public view returns (uint256) {
        return _numberMinted(owner);
    }
    /**
    * @notice Return true or false if the account is whitelisted or not
    *
    * @param account The account of the user
    * @param proof The Merkle Proof
    *
    * @return true or false if the account is whitelisted or not
    **/
    function isWhiteListed(address account, bytes32[] calldata proof) internal view returns(bool) {
        return _verify(_leaf(account), proof);
    }

    /**
    * @notice Return the account hashed
    *
    * @param account The account to hash
    *
    * @return The account hashed
    **/
    function _leaf(address account) internal pure returns(bytes32) {
        return keccak256(abi.encodePacked(account));
    }

    /** 
    * @notice Returns true if a leaf can be proved to be a part of a Merkle tree defined by root
    *
    * @param leaf The leaf
    * @param proof The Merkle Proof
    *
    * @return True if a leaf can be provded to be a part of a Merkle tree defined by root
    **/
    function _verify(bytes32 leaf, bytes32[] memory proof) internal view returns(bool) {
        return MerkleProof.verify(proof, merkleRoot, leaf);
    }

    /** 
    * @notice Allows to change the sellinStep to Presale
    **/
    function setUpPresale() external onlyOwner {
        sellingStep = Steps.Presale;
    }

    /** 
    * @notice Allows to change the sellinStep to Sale
    **/
    function setUpSale() external onlyOwner {
        require(sellingStep == Steps.Presale, "First the presale, then the sale.");
        sellingStep = Steps.Sale;
    }

    /**
    * @notice Edit the Merkle Root 
    *
    * @param _newMerkleRoot The new Merkle Root
    **/
    function changeMerkleRoot(bytes32 _newMerkleRoot) external onlyOwner {
        merkleRoot = _newMerkleRoot;
    }

    /** 
    * @notice Set pause to true or false
    *
    * @param _paused True or false if you want the contract to be paused or not
    **/
    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
    }

    /**
    * @notice Change the price of one NFT for the presale
    *
    * @param _pricePresale The new price of one NFT for the presale
    **/
    function changePricePresale(uint _pricePresale) external onlyOwner {
        pricePresale = _pricePresale;
    }

    /**
    * @notice Change the price of one NFT for the sale
    *
    * @param _priceSale The new price of one NFT for the sale
    **/
    function changePriceSale(uint _priceSale) external onlyOwner {
        priceSale = _priceSale;
    }

    /**
    * @notice Change the base URI
    *
    * @param _newBaseURI The new base URI
    **/
    function setBaseUri(string memory _newBaseURI) external onlyOwner {
        baseURI = _newBaseURI;
    }

    /**
    * @notice Change the not revealed URI
    *
    * @param _notRevealedURI The new not revealed URI
    **/
    function setNotRevealURI(string memory _notRevealedURI) external onlyOwner {
        notRevealedURI = _notRevealedURI;
    }

    /**
    * @notice Allows to set the revealed variable to true
    **/
    function reveal() external onlyOwner {
        sellingStep = Steps.Reveal;  
        revealed = true;
    }

     /**
    * @notice Return URI of the NFTs when revealed
    *
    * @return The URI of the NFTs when revealed
    **/
    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }

    function tokenURI(uint _nftId) public view override(ERC721A) returns (string memory) {
        require(_exists(_nftId), "This NFT doesn't exist.");
        if(revealed == false) {
            return notRevealedURI;
        }
        
        string memory currentBaseURI = _baseURI();
        return 
            bytes(currentBaseURI).length > 0 
            ? string(abi.encodePacked(currentBaseURI, _nftId.toString(), baseExtension))
            : "";
    }
}