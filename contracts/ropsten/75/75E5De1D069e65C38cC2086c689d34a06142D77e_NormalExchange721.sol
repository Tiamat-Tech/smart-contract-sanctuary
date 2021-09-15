// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";


interface Common721NFT{
    function mint(address account, uint256 id)external;
    function exists(uint256 tokenId) external view returns (bool);
}


contract NormalExchange721 is AccessControl, Pausable {

    using SafeMath for uint256;

    /* Variable */
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    string  public name = "NormalExchange721";
    address public nftContractAddress;
    address public owner;
    address public withdrawAddress;
    uint256 internal price;
    uint256 public minId;
    uint256 public maxId;

    /* Event */
    event ETHReceived(address sender, uint256 value);
    event PurchaseSuccessful(address indexed buyer,uint256 indexed amount,uint256 indexed price, uint256 nftTokenId);


    /* Constructor */
    constructor(address _nftContractAddress,uint256 _price){
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        nftContractAddress = _nftContractAddress;
        price = _price;
        owner = msg.sender;
        minId = 1;
        maxId = 50001;
    }

    //Fallback function
    fallback() external payable {
        emit ETHReceived(msg.sender, msg.value);
    }

    //Receive function
    receive() external payable {
        // TODO implementation the receive function
    }

    //******SET UP******
    function setNftContractAddress(address _nftContractAddress) public whenNotPaused{
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender));
        nftContractAddress = _nftContractAddress;
    }

    function setupPrice(uint256 _price) public whenNotPaused{
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender));
        require(_price > 0,"the price must be more than 0!");
        price = _price;
    }

    function setupOwner(address _owner)public whenNotPaused{
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender));
        owner = _owner;
    }

    function setupWithdrawAddress(address _withdrawAddress)public whenNotPaused{
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender));
        withdrawAddress = _withdrawAddress;
    }

    function setupTokenIdRange(uint256 _minId,uint256 _maxId)public  whenNotPaused{
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender));
        minId = _minId;
        maxId = _maxId;
    }

    function pause() public{
        require(hasRole(PAUSER_ROLE, msg.sender));
        _pause();
    }

    function unpause() public{
        require(hasRole(PAUSER_ROLE, msg.sender));
        _unpause();
    }

    function purchase(uint256 _nftId) public payable whenNotPaused {
        require((minId <= _nftId) && (_nftId <= maxId),"The purchase of NFT exceeds the stock!");
        require(msg.value >= price,"The ether of be sent must be more than the price!");
        require(_validateNftMintable(_nftId,nftContractAddress),"The nft already be mint!");
        require(_mintNft(_nftId),"NFT mint failed");
        payable(address(this)).transfer(price);
        if (msg.value > price){
            payable(msg.sender).transfer(msg.value - price);
        }
        emit PurchaseSuccessful(msg.sender,1,price,_nftId);
    }
    //******END SET UP******/

    //Get sell price
    function getPrice()view public whenNotPaused returns(uint256){
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender));
        return price;
    }


    function _mintNft(uint256 _mintNftTokenId)internal whenNotPaused returns(bool) {
        Common721NFT Common721NFTContract = Common721NFT(nftContractAddress);
        Common721NFTContract.mint(msg.sender,_mintNftTokenId);
        return true;
    }


    //Check NFT mintable
    function _validateNftMintable(uint256 _contractTokenId,address _contractAddress)internal whenNotPaused view returns(bool){
        Common721NFT Common721NFTContract = Common721NFT(_contractAddress);
        if (Common721NFTContract.exists(_contractTokenId)){
            return false;
        }else{
            return true;
        }
    }


    function withdraw() public whenNotPaused payable {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender));
        uint256 withdrawETH = address(this).balance -  0.01 ether;
        payable(owner).transfer(withdrawETH);
    }
}