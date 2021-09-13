// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";


interface  Common1155NFT{

    function mint(address account, uint256 id, uint256 amount, bytes memory data)external;

    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data)external;

    function setURI(string memory newuri) external;
}

contract BlindBoxExchange1155 is AccessControl, Pausable {
    using SafeMath for uint256;
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    string  public name = "BlindBoxExchange1155";
    address public nftContractAddress;
    address public owner;
    address public withdrawAddress;
    uint256[] internal nftTokenIds;
    uint256 public nowId;
    uint256 public maxId;
    uint256 internal price;

    struct castInfo{
        uint256 tokenId;
        uint256 musicTokenId;
        address musicAddress;
        uint256 backgroundTokenId;
        address backgroundAddress;
        address agentAddress;
    }

    event ETHReceived(address sender, uint256 value);
    event PurchaseSuccessful(address indexed buyer,uint256 indexed amount,uint256 indexed totalPrice, uint256[] nftTokenIds);

    constructor(address _nftContractAddress,uint256 _price){
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        nftContractAddress = _nftContractAddress;
        price = _price;
        owner = msg.sender;
        nowId = 1;
        maxId = 5001;
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

    function setWithdrawAddress(address _withdrawAddress)public whenNotPaused{
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender));
        withdrawAddress = _withdrawAddress;
    }

    function pause() public {
        require(hasRole(PAUSER_ROLE, msg.sender));
        _pause();
    }

    function unpause() public {
        require(hasRole(PAUSER_ROLE, msg.sender));
        _unpause();
    }

    function purchase(uint256 _amount) public payable whenNotPaused {
        uint256[] memory mintNftTokenIds;
        require(_amount > 0,"The purchase amount of NFT must be more than 0!");
        require(_amount <= 100,"The purchase amount of NFT must be less than 100!");
        if (maxId > 0){
            require(nowId + _amount <= maxId,"The purchase amount of NFT exceeds the stock!");

        }
        // require(nftTokenIds.length >= _amount,"The purchase amount of NFT exceeds the stock!");
        uint256 totalPrice = _amount.mul(price);
        require(msg.value >= totalPrice,"The ether of be sent must be more than the totalprice!");
        mintNftTokenIds = _getNftTokenIds(_amount);
        nowId = nowId+ _amount;
        require(_mintNft(mintNftTokenIds),"NFT mint failed");
        payable(address(this)).transfer(totalPrice);
        if (msg.value > totalPrice){
            payable(msg.sender).transfer(msg.value - totalPrice);
        }
        emit PurchaseSuccessful(msg.sender,_amount,totalPrice,mintNftTokenIds);
}
    //******END SET UP******/

    //Get sell price
    function getPrice()view public whenNotPaused returns(uint256){
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender));
        return price;
    }

    //Initial token ids
    function pushNftTokenIds(uint256[] memory _pushNftTokenIds ) public whenNotPaused{
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender));
        require(_pushNftTokenIds.length > 0,"The array to be pushed can't be empty!");
        for (uint256 i = 0; i < _pushNftTokenIds.length; i++) {
            nftTokenIds.push(_pushNftTokenIds[i]);
        }
    }


    function getNftTokenId(uint256 index)view public whenNotPaused returns(uint256){
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender));
        require(index >= 0 && index < nftTokenIds.length,"The index is illegal!");
        return nftTokenIds[index];
    }

    function getNftTokensNum()view public whenNotPaused returns(uint256){
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender));
        return nftTokenIds.length;
    }


    function _getNftTokenIds(uint256 _arrayLength) internal view whenNotPaused returns(uint256[] memory){
        
        uint256[] memory resultNftTokenIds = new uint256[](_arrayLength);
        for (uint256 i = 0; i < _arrayLength; i++) {
            resultNftTokenIds[i] = nowId + i;
        }
        return resultNftTokenIds;
    }

    function _mintNft(uint256[] memory mintNftTokenIds)internal whenNotPaused returns(bool) {
        uint256[] memory amountArray;
        Common1155NFT Common1155NFTContract = Common1155NFT(nftContractAddress);
        if (mintNftTokenIds.length == 1){
            Common1155NFTContract.mint(msg.sender,mintNftTokenIds[0],1,abi.encode(msg.sender));

        }else{
            amountArray = _generateAmountArray(mintNftTokenIds.length);
            Common1155NFTContract.mintBatch(msg.sender,mintNftTokenIds,amountArray,abi.encode(msg.sender));
        }
        return true;
    }

    function _removeNftTokenIds(uint256 _arrayLength) internal whenNotPaused{
        for (uint256 i = 0; i < _arrayLength; i++){
            nftTokenIds.pop();
        }
    }

    function _generateAmountArray(uint256 _arrayLength) internal  pure returns(uint256 [] memory){
        uint256[] memory amountArray = new uint256[](_arrayLength);
        for (uint256 i = 0; i < _arrayLength; i++) {
            amountArray[i] = 1;
        }
        return amountArray;
    }


    function withdraw() public whenNotPaused payable {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender));
        uint256 withdrawETH = address(this).balance -  0.01 ether;
        payable(owner).transfer(withdrawETH);
    }
}