// SPDX-License-Identifier: MIT
// Creator: The Systango Team

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/MerkleProofUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";

import './ERC721AUpgradeable.sol';
import './BlackListUpgradeable.sol';
import './IUtilToken.sol';

contract UtilToken is ERC721AUpgradeable, BlackListUpgradeable,  PausableUpgradeable, OwnableUpgradeable, ReentrancyGuardUpgradeable, IUtilToken{

    using SafeMathUpgradeable for uint256;

    // Zero Address
    address constant ZERO_ADDRESS = address(0);

    // Sale active status variable
    bool public isSaleActive;

    // Minting price for NFT
    uint256 private mintPrice;

    // Base URI string
    string private _baseURIPrefix;

    uint256 private _totalBatchCount;

    mapping(uint256 => mapping(address => bool)) public whitelistClaimed;

    struct Batch { 
        uint256 startTime;
        uint256 endTime;
        bytes32 merkleHash;
        bool publicMint;
    }

    Batch[] public previousBatch;

    Batch public currentBatch;

    mapping(uint256 => bool) public airDroppedTokens;

    function initialize(
        string memory _tokenName, 
        string memory _tokenSymbol, 
        string memory _uri
    ) initializer public {
        __ERC721A_init(_tokenName, _tokenSymbol);
        __Pausable_init();
        __Ownable_init();

        isSaleActive = true;
        _baseURIPrefix = _uri;
        mintPrice = 0.1 ether;
    }

    /// @dev This is the token mint function. This would mint a token NFT and would except coins to buy the NFT

    function mint(bytes32[] calldata _merkleProof) external payable override whenNotBlackListedUser(_msgSender()) nonReentrant whenNotPaused {
        address callerAddress = _msgSender();
        mintSanityCheck(callerAddress, _merkleProof);
        uint256 initialTotalSupply = totalSupply();
        _safeMint(callerAddress, 1);
        emit NewNFT(initialTotalSupply);
    }

    /// @dev This is the token mint sanity check function. This would check for all the requirements before the NFT minting

    function mintSanityCheck(address callerAddress, bytes32[] calldata _merkleProof) internal {
        require(isSaleActive, "Sale must be active to mint NFT");
        require(getMintPrice() <= msg.value, "Insufficient balance");
        if(block.timestamp < currentBatch.endTime && block.timestamp > currentBatch.startTime){
            if(!currentBatch.publicMint){
                bytes32 leaf = keccak256(abi.encodePacked(callerAddress));
                require(
                    MerkleProofUpgradeable.verify(_merkleProof, currentBatch.merkleHash, leaf),
                    "MerkleDistributor: Invalid proof."
                );
                require(!whitelistClaimed[previousBatchCount()][msg.sender], "Whitelisted user already minted for current batch");
                whitelistClaimed[previousBatchCount()][msg.sender] = true;
            }
        }
    }

    /// @dev This is the airDrop function. It is used by the owner to airdrop `quantity` number of random tokens to the `assigned` address respectively.
    /// @dev Only the owner can call this function
    /// @param assigned The address to be air dropped
    /// @param quantity The amount of random tokens to be air dropped

    function airDrop(address[] memory assigned, uint256[] memory quantity) public override onlyOwner whenNotPaused {
        require(isSaleActive, "Sale must be active to mint NFT");
        require(assigned.length == quantity.length, "Incorrect parameter length");
        uint256 initialTotalSupply = totalSupply();
        for (uint256 index = 0; index < assigned.length; index++) {
            if(!_isBlackListUser(assigned[index])){
                _safeMint(assigned[index], quantity[index]);
                for (uint256 i = 0; i < quantity[index]; i++){
                    airDroppedTokens[initialTotalSupply.add(i)] = true;
                    emit NewNFT(initialTotalSupply.add(i));
                }
                initialTotalSupply.add(quantity[index]);
            }
        }
    }

    function addBatch(uint256 _startTime, uint256 _endTime, bytes32 _merkleHash, bool _publicMint) public onlyOwner whenNotPaused {
        if(currentBatch.endTime < block.timestamp && currentBatch.endTime > 0){
            updateCurrentBatch(_endTime, _merkleHash);
        }
        else{
            if(_totalBatchCount > 0){
                Batch memory tempBatch = Batch(currentBatch.startTime, currentBatch.endTime, currentBatch.merkleHash, currentBatch.publicMint);
                previousBatch.push(tempBatch);
            }
            currentBatch = Batch(_startTime, _endTime, _merkleHash, _publicMint);
            _totalBatchCount = _totalBatchCount.add(1);
        }
    }

    function updateCurrentBatch(uint256 _endTime, bytes32 _merkleHash) public onlyOwner whenNotPaused {
        currentBatch.endTime = _endTime;
        currentBatch.merkleHash = _merkleHash;
    }

    function totalBatchCount() external view returns(uint256){
        return _totalBatchCount;
    }

    function previousBatchCount() public view returns(uint256){
        return previousBatch.length;
    }

    /// @dev This is the function to withdraw the amount saved from the contract
    /// @dev Only the owner can call this function

    function withdraw() external override onlyOwner nonReentrant whenNotPaused{
        uint256 contractBalance = address(this).balance;
        payable(owner()).transfer(contractBalance);
    }

    /// @dev This is the function to alter the sale active status
    /// @dev Only the owner can call this function
    /// @param isActive The sale status to be set

    function alterSaleActiveStatus(bool isActive) external override onlyOwner whenNotPaused{
        require(isSaleActive != isActive, "Sale status is already equal to supplied value");
        isSaleActive = isActive;
    }

    /// @dev This is the function to set the mint amount to new mint amount
    /// @dev Only the owner can call this function
    /// @param newAmount The new mint amount

    function setMintPrice (uint256 newAmount) external override onlyOwner whenNotPaused{
        mintPrice = newAmount;
    }

    /// @dev This is the function to get the mint amount

    function getMintPrice() public view override returns (uint256) {
        return mintPrice;
    }

    /// @dev The internal function for getting the Base URI string

    function _baseURI() internal view override returns (string memory) {
        return _baseURIPrefix;
    }

    /// @dev The external function for getting the Base URI string

    function baseURI() external view override returns (string memory) {
        return _baseURI();
    }

    /// @dev This is the function to set the Base URI to new Base URI
    /// @dev Only the owner can call this function
    /// @param newUri The new Base URI

    function setBaseURI(string memory newUri) external override onlyOwner whenNotPaused {
        require(
            keccak256(bytes(newUri)) != keccak256(bytes(_baseURIPrefix)),
            "New URI cannot be same as old URI"
        );
        _baseURIPrefix = newUri;
        emit SetBaseURI(newUri);
    }

    /// @dev This function would add an address to the blacklist mapping
    /// @dev Only the owner can call this function
    /// @param _user The account to be added to blacklist

    function addToBlackList(address _user) public override onlyOwner whenNotPaused returns (bool) {
        require(
            _user != ZERO_ADDRESS,
            "account is the zero address"
        );
        _addToBlackList(_user);
        return true;
    }

    /// @dev This function would remove an address from the blacklist mapping
    /// @dev Only the owner can call this function
    /// @param _user The account to be removed from blacklist

    function removeFromBlackList(address _user) public override onlyOwner whenNotPaused returns (bool) {
        require(
            _user != ZERO_ADDRESS,
            "account is the zero address"
        );
        _removeFromBlackList(_user);
        return true;
    }

    /// @dev This function would pause the contract
    /// @dev Only the owner can call this function

    function pause() external override onlyOwner {
        _pause();
    }

    /// @dev This function would unpause the contract
    /// @dev Only the owner can call this function

    function unpause() external override onlyOwner {
        _unpause();
    }

    /// @dev Overridden function called before every token transfer

    function _beforeTokenTransfers(
        address from,
        address to,
        uint256 startTokenId,
        uint256 quantity

    ) internal virtual whenNotPaused airDropCheck(startTokenId, quantity) override (ERC721AUpgradeable) {
        super._beforeTokenTransfers(from, to, startTokenId, quantity);
    }

    modifier airDropCheck(uint256 startTokenId, uint256 quantity) {
        for (uint256 i = 0; i < quantity; i++) {
            require(
                !airDroppedTokens[startTokenId.add(i)],
                "The token is airdropped and cannot be transferred"
            );
        }
        _;
    }

}