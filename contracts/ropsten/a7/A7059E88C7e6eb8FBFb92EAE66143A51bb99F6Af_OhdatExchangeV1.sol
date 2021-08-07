// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

/* how much has owner (in wei, or UINT256_MAX if ERC-721) */

interface  OhdatNFT{

    /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding
     * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[EIP section]
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30 000 gas.
     */
    function mint(address account, uint256 id, uint256 amount, bytes memory data)external;

    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data)external;

    function setURI(string memory newuri) external;
}

contract OhdatExchangeV1 is AccessControl, Pausable {
    using SafeMath for uint256;
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    string  public name = "OhdatExchangeV1";
    uint256 internal price;
    address public nftContractAddress;
    address public owner;
    uint256[] internal nftTokenIds;
    address public withdrawAddress;

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
        require(nftTokenIds.length >= _amount,"The purchase amount of NFT exceeds the stock!");
        uint256 totalPrice = _amount.mul(price);
        //TODO add tip.
        require(msg.value >= totalPrice);
        mintNftTokenIds = _getNftTokenIds(_amount);
        require(_mintNft(mintNftTokenIds),"NFT mint failed");
        //        payable(address(owner)).transfer(totalPrice);
        payable(address(this)).transfer(totalPrice);
        if (msg.value > totalPrice){
            payable(msg.sender).transfer(msg.value - totalPrice);
        }
        _removeNftTokenIds(_amount);
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
        for (uint256 i = nftTokenIds.length - 1; i >= (nftTokenIds.length - _arrayLength); i--){
            resultNftTokenIds[(nftTokenIds.length - 1 - i)] = nftTokenIds[i];
        }
        return resultNftTokenIds;
    }

    function _mintNft(uint256[] memory mintNftTokenIds)internal whenNotPaused returns(bool) {
        uint256[] memory amountArray;
        OhdatNFT OhdatNftContract = OhdatNFT(nftContractAddress);
        if (mintNftTokenIds.length == 1){
            OhdatNftContract.mint(msg.sender,mintNftTokenIds[0],1,abi.encode(msg.sender));

        }else{
            amountArray = _generateAmountArray(mintNftTokenIds.length);
            OhdatNftContract.mintBatch(msg.sender,mintNftTokenIds,amountArray,abi.encode(msg.sender));
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
        uint256 withdrawETH = address(this).balance -  20000 gwei;
        payable(owner).transfer(withdrawETH);
    }
}