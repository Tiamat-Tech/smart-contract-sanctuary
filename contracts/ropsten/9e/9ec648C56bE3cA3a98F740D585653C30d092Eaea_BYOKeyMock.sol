// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

import "./BYOKeyInterface.sol";
import "./TokenInterface.sol";

contract BYOKeyMock is BYOKeyInterface {

    using SafeMath for uint256;
    using Counters for Counters.Counter;

    struct BYOKey {
        bool isCollectingOpen;                                                       
        uint256 mintPrice;                              
        uint256 maxPerTx;                               
        string uriHash;                                 
        address redeemableAddress;                      
        bytes32 merkle;                                 
        bool isWhitelistBased;                          
        bool enforceBalance;                            
        address linkedAsset;                            
    }

    mapping(uint256 => BYOKey) public byoKeys;
    Counters.Counter private keyCounter; 
    
    constructor(string memory _name,
        string memory _symbol) ERC1155("") {
        m_Name = _name;
        m_Symbol = _symbol;
    }

    function createBYOKey(
        bytes32 _merkle,
        bool _isWhitelistBased,
        bool _enforceBalance,
        uint256  _mintPrice, 
        uint256 _maxPerTx,
        string memory _uriHash,
        address _redeemableAddress,
        address _linkedAsset
    ) external onlyOwner {
        BYOKey storage byoKey = byoKeys[keyCounter.current()];
        byoKey.merkle = _merkle;
        byoKey.isCollectingOpen = false;
        byoKey.isWhitelistBased = _isWhitelistBased;
        byoKey.enforceBalance = _enforceBalance;
        byoKey.mintPrice = _mintPrice;
        byoKey.maxPerTx = _maxPerTx;
        byoKey.uriHash = _uriHash;
        byoKey.redeemableAddress = _redeemableAddress;
        byoKey.linkedAsset = _linkedAsset;
        keyCounter.increment();
    }

    function editBYOKey(
        bytes32 _merkle,
        bool _isWhitelistBased,
        bool _enforceBalance,
        uint256  _mintPrice, 
        uint256 _maxPerTx,
        string memory _uriHash,
        address _redeemableAddress,
        address _linkedAsset,
        uint256 _keyIdx
    ) external onlyOwner {
        byoKeys[_keyIdx].merkle = _merkle;
        byoKeys[_keyIdx].isWhitelistBased = _isWhitelistBased;
        byoKeys[_keyIdx].enforceBalance = _enforceBalance;
        byoKeys[_keyIdx].mintPrice = _mintPrice; 
        byoKeys[_keyIdx].maxPerTx = _maxPerTx;    
        byoKeys[_keyIdx].uriHash = _uriHash;    
        byoKeys[_keyIdx].redeemableAddress = _redeemableAddress;  
        byoKeys[_keyIdx].linkedAsset = _linkedAsset;
    }   

    function ownerCollect (uint256 _numPasses, uint256 _keyIdx) external onlyOwner {
        _mint(msg.sender, _keyIdx, _numPasses, "");
    }

    function ownerMintTo (address to, uint256 _numPasses, uint256 _keyIdx) external onlyOwner {
        _mint(to, _keyIdx, _numPasses, "");
    }

    function burnFromRedeem(
        address _account, 
        uint256 _keyIdx, 
        uint256 _amount
    ) external {
        require(byoKeys[_keyIdx].redeemableAddress == msg.sender, "Redeemable address only.");
        _burn(_account, _keyIdx, _amount);
    }  

    function uri(uint256 _id) public view override returns (string memory) {
        require(totalSupply(_id) > 0, "No token supply yet.");    
        return string(abi.encodePacked(super.uri(_id), byoKeys[_id].uriHash));
    }   

    function withdrawAmount(address payable _to, uint256 _amount) public onlyOwner
    {
        _to.transfer(_amount);
    }

}