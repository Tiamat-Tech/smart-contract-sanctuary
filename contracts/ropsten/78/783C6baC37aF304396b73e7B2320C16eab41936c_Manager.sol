// SPDX-License-Identifier: GPL

// NFT Labs -- https://highlight.so

pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import "./Factory.sol";
import "./CreatorPool.sol";
import "./State.sol";
import "./TestStablecoin.sol";
import "./Rarity.sol";

contract Manager {
 
    using EnumerableSet for EnumerableSet.UintSet;

    using State for State.Token;
    using State for State.Content;

    // ========== Protocol DAO and contracts ==========

    address public DAO;

    Factory public factory;
    CreatorPool public creatorPool;
    Rarity public rarity;
    TestStablecoin public stablecoin;
    
    // ========== State variables, mappings and events ==========

    uint public nextTokenID;
    uint public defaultPackPrice = 9 ether;

    // URI => unique ERC 1155 token ID associated with that URI
    mapping(string => uint) public URI_to_tokenID;
    // ERC 1155 token ID => total supply of that token
    mapping(uint => uint) public totalSupplyOfToken;

    // ERC 1155 token ID => unique mint number => whether the token is on sale or not
    mapping(uint => mapping(uint => bool)) public forSale;
    // ERC 1155 token ID => unique mint number => price of the token
    mapping(uint => mapping(uint => uint)) public tokenPrice;
    // Address => price of pack of that address' tokens
    mapping(address => uint) public packPrice;

    // ERC 1155 token ID => Content associated with that token ID
    mapping(uint => State.Content) public content;
    // Address => ERC 1155 token IDs owned
    mapping(address => EnumerableSet.UintSet) tokenIDsOwned;
    // Address => ERC 1155 token IDs created
    mapping(address => EnumerableSet.UintSet) tokenIDsCreated;

    event TokenUpload(uint indexed tokenID, address indexed creator);
    event TokenMinted(uint indexed tokenID, uint indexed mintNumber);
    event TokenTransfer(uint indexed tokenID, address indexed from, address indexed to, uint price);
    event PackSold(address indexed creator, address indexed to, uint price);

    // ========== Constructor and modifiers ==========

    constructor() {
        DAO = msg.sender;

        nextTokenID = 1;
    }

    /// @notice Check whether caller is token owner
    modifier OnlyTokenOwner(address _caller, uint _tokenID, uint _mintNumber) {
        require(_caller == content[_tokenID].token[_mintNumber].owner, "Only the owner can change the token's properties.");
        _;
    }

    /// @notice Checks whether the token exists
    modifier OnlyValidToken(uint _tokenID, uint _mintNumber) {
        require(_tokenID < nextTokenID, "This token ID is invalid. This token does not exist on the contract.");
        require(
            _mintNumber <= content[_tokenID].nextMintNumber, 
            "This mint number is invalid. Not enough tokens of this token have been minted."
        );
        _;
    }

    /// @notice Checks whether caller is DAO
    modifier OnlyDAO(address _caller) {
        require(_caller == DAO, "Only the protocol DAO can call this function.");
        _;
    }

    // ========== Config setter functions ==========

    /// @notice Sets address `_newDAO` as DAO address
    function setDAO(address _newDAO) public {
        require(DAO == msg.sender, "Only the factor manager can call the factory");
        DAO = _newDAO;
    }

    /// @notice Sets protocol DAO and contracts
    function setConfig(
        address _factory,
        address _creatorPool,
        address _rarity,
        address _testStablecoin
    ) external OnlyDAO(msg.sender) {

        factory = Factory(_factory);
        creatorPool = CreatorPool(_creatorPool);
        rarity = Rarity(_rarity);
        stablecoin = TestStablecoin(_testStablecoin);
    }

    /// @notice Sets the protocol default pack price
    function setDefaultPackPrice(uint _price) external OnlyDAO(msg.sender) {
        defaultPackPrice = _price;
    }

    // ========== State changing functions ==========

    /// @notice Mints a hundred stablecoin to the caller.
    function faucet(address _to) external {
        stablecoin.faucet(_to);
    }

    /// @notice A helper function that assigns a token ID to a newly minted token.
    function assignTokenID(string memory _URI) internal returns (uint id) {
        require(URI_to_tokenID[_URI] == 0, "Cannot double mint the same URI.");

        id = nextTokenID;
        URI_to_tokenID[_URI] = id;

        nextTokenID += 1;
    }

    /// @notice Mints a given amount of ERC 1155 tokens -- token tokens -- and updates state accordingly.
    function uploadToken(string calldata _URI) public returns (uint tokenID) {

        // Assign unique token ID
        tokenID = assignTokenID(_URI);
        
        // Update: 1) token store and 2) tokenIDsCreated
        EnumerableSet.add(tokenIDsCreated[msg.sender], tokenID);

        State.onTokenUpload(
            content[tokenID],
            tokenID,
            _URI,
            msg.sender
        );

        emit TokenUpload(tokenID, msg.sender);
    }

    /// @dev The number of token IDs in a pack is hard coded to equal three.
    /// @notice This function is pseudo-random; must be made truly random for production.
    function getRandomTokenIDs(address _creator) public view returns(uint[] memory tokenIDs) {

        uint len = EnumerableSet.length(tokenIDsCreated[_creator]);
        require(len > 0, "You need to upload at least one tokens to publish a pack.");

        tokenIDs = new uint[](3);
        uint index = 0;
        uint ref = len;

        while(index < 3) {
            uint id = EnumerableSet.at(
                tokenIDsCreated[_creator], 
                (block.number + block.timestamp) % ref
            );

            if(ref > 1) {
                ref -= 1;
            }

            tokenIDs[index] = id;
            index++;
        }
    }

    /// @notice Let's a collector buy a pack.
    function buyPack(
        address _creator,
        address _to
    ) external {

        uint price = packPrice[_creator] != 0 ? packPrice[_creator] : defaultPackPrice;        
        bool success = stablecoin.transferFrom(_to, address(creatorPool), price);
        require(success, "ERC20 transfer failed. Please approve the contract to transfer the price amount.");
        
        uint[] memory tokenIDs = getRandomTokenIDs(_creator);
        uint[] memory amounts = new uint[](tokenIDs.length);        

        // Update 1) tokenIDsOwned and 2) Token store
        for(uint i = 0; i < tokenIDs.length; i++) {

            amounts[i] = 1;

            // Update tokenIDsOwned
            EnumerableSet.add(tokenIDsOwned[_to], tokenIDs[i]);

            uint tokenRarity = rarity.getRandomRarity();

            // Update Token store
            uint mintNumber = State.onTokenMint(
                content[tokenIDs[i]],
                _creator,
                _to,
                tokenIDs[i],
                tokenRarity
            );

            // Update total supply of token
            totalSupplyOfToken[tokenIDs[i]] += 1;

            // Update block book in creator pool
            creatorPool.updateBlockBook(msg.sender, _creator, tokenIDs[i], mintNumber);

            emit TokenMinted(tokenIDs[i], mintNumber);
        }

        // Call factory to mint token tokens.
        factory.mintBatch(_to, tokenIDs, amounts, "");

        //Call creator pool
        creatorPool.onPackPurchase(price, _creator);
        emit PackSold(_creator, _to, price);
    }

    /// @notice Transfer a token from the current token owner to the collector who is buying the token.
    function transferToken(
        address _from,
        uint _tokenID, 
        uint _mintNumber
    ) external OnlyValidToken(_tokenID, _mintNumber) {

        require(forSale[_tokenID][_mintNumber], "Can only purchase a token that is on sale.");

        uint price = tokenPrice[_tokenID][_mintNumber];
        bool success = stablecoin.transferFrom(msg.sender, address(creatorPool), price);
        require(success, "ERC20 transfer failed. Please approve the contract to transfer the price amount.");

        // Update application state
        State.onTokenTransfer(
            content[_tokenID],
            _from,
            msg.sender,
            _mintNumber
        );
        forSale[_tokenID][_mintNumber] = false;

        // Call NFT Factory
        factory.safeTransferFrom(_from, msg.sender, _tokenID, 1, "");

        // Updating previous owners' token state
        if(factory.balanceOf(_from, _tokenID) == 0) {
            EnumerableSet.remove(tokenIDsOwned[_from], _tokenID);
        }

        // Updating new owners' token state
        if(factory.balanceOf(msg.sender, _tokenID) == 1) {
            EnumerableSet.add(tokenIDsOwned[msg.sender], _tokenID);
        }

        // Call creator pool
        creatorPool.onTokenTransfer(
            price, 
            content[_tokenID].creator, 
            _from
        );

        creatorPool.updateBlockBook(
            msg.sender, content[_tokenID].creator, _tokenID, _mintNumber
        );

        emit TokenTransfer(_tokenID, _from, msg.sender, price);
    }

    /// @notice Let's a token owner set token price and take it on and off sale.
    function setTokenStatus(
        uint  _tokenID,
        uint _mintNumber,
        uint _price, 
        bool _forSale
    ) external OnlyValidToken(_tokenID, _mintNumber) OnlyTokenOwner(msg.sender, _tokenID, _mintNumber) {

        forSale[_tokenID][_mintNumber] = _forSale;
        tokenPrice[_tokenID][_mintNumber] = _price;
    }

    /// @notice Let's a creator set their pack prie.
    function setPackPrice(uint _newPrice) external {
        packPrice[msg.sender] = _newPrice;
    }

    // ===== Getter / view functions =====

    function getTokenIDsOwned(address _holder) public view returns (uint[] memory tokenIDs) {
        
        uint len = EnumerableSet.length(tokenIDsOwned[_holder]);
        tokenIDs = new uint[](len);

        for(uint i = 0; i < len; i++) {
            tokenIDs[i] = EnumerableSet.at(tokenIDsOwned[_holder], i);
        }
    }

    function getMintNumbersOwned(address _holder, uint  _tokenID) public view returns (uint[] memory mintNumbers) {
        
        uint len = EnumerableSet.length(content[_tokenID].mintNumbersOwned[_holder]);
        mintNumbers = new uint[](len);

        for(uint i = 0; i < len; i++) {
            mintNumbers[i] = EnumerableSet.at(content[_tokenID].mintNumbersOwned[_holder], i);
        }
    }

    function getTokenIDsCreated(address _creator) public view returns (uint[] memory tokenIDs) {
        uint len = EnumerableSet.length(tokenIDsCreated[_creator]);
        tokenIDs = new uint[](len);
        for(uint i = 0; i < len; i++) {
            uint id = EnumerableSet.at(tokenIDsCreated[_creator], i);
            tokenIDs[i] = id;
        }
    }

    function getToken(uint _tokenID, uint _mintNumber) public view returns (State.Token memory token) {
        token = content[_tokenID].token[_mintNumber];
    }

    function isForSale(uint _tokenID, uint _mintNumber) public view returns (bool) {
        return forSale[_tokenID][_mintNumber];
    }

    function getTokenPrice(uint _tokenID, uint _mintNumber) public view returns (uint price) {
        price = tokenPrice[_tokenID][_mintNumber];
    }

    function getTokenURI(uint _tokenID) public view returns (string memory URI) {
        URI = content[_tokenID].URI;
    }

    function getTokenOwner(uint _tokenID, uint _mintNumber) public view returns (address owner) {
        owner = content[_tokenID].token[_mintNumber].owner;
    }

    function getTokenCreator(uint _tokenID) public view returns (address creator) {
        creator = content[_tokenID].creator;
    }

    function getTokenRarity(uint _tokenID, uint _mintNumber) public view returns(uint tokenRarity) {
        tokenRarity = content[_tokenID].token[_mintNumber].rarity;
    }

    function getAllTokensByCreator(address _creator) public view returns (State.Token[] memory tokens) {
        EnumerableSet.UintSet storage IDsCreated = tokenIDsCreated[_creator];

        uint len = EnumerableSet.length(IDsCreated);
        uint count = 0;

        for(uint i = 0; i < len; i++) {
            uint tokenID = EnumerableSet.at(IDsCreated, i);
            uint totalMinted = content[tokenID].nextMintNumber;

            count += totalMinted;
        }

        tokens = new State.Token[](count);
        uint index = 0;

        for(uint i = 0; i < len; i++) {
            uint tokenID = EnumerableSet.at(IDsCreated, i);
            uint totalMinted = content[tokenID].nextMintNumber;

            for(uint mintNumber = 1; mintNumber <= totalMinted; mintNumber++) {
                tokens[index] = getToken(tokenID, mintNumber);
                index++;
            }
        }
    }
}