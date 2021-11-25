// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./Utils.sol";


interface Common1155NFT {
    function mint(address account, uint256 id, uint256 amount, bool specifyCreator) external;
    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts, bool specifyCreator) external;
}

interface Common721NFT {
    function mint(address account, uint256 id) external;
}

contract Refill is AccessControl, Pausable, Utils {

    /* Variable */
    using SafeMath for uint256;
    address signerAddress;

    //Interface Signature ERC1155 and ERC721
    bytes4 constant private INTERFACE_SIGNATURE_ERC1155 = 0xd9b67a26;
    bytes4 constant private INTERFACE_SIGNATURE_ERC721 = 0x80ac58cd;

    constructor (){
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        signerAddress = msg.sender;
    }

    /* Event */
    event ETHReceived(address sender, uint256 value);
    event Recharge(uint256 indexed _ethAmount, uint256 indexed _ticketNumber, address indexed sender, string nonce);
    event WithdrawNFT(uint256 indexed _amount, address indexed _contractAddress, uint256 indexed _tokenId, address _fromAddress, address _toAddress,string nonce);
    event BatchWithdrawNFT(uint256[] _amountArray, address[] _contractAddress, uint256[] _tokenIdArray, address[] _fromAddress, address indexed _toAddress,string nonce);

    //Fallback function
    fallback() external payable {
        emit ETHReceived(msg.sender, msg.value);
    }

    //Receive function
    receive() external payable {
        // TODO implementation the receive function
    }

    function recharge(uint256 _ethAmount, uint256 _ticketNumber, bytes32 hash, bytes memory signature, string memory nonce) public payable whenNotPaused{
        //验证hash
        require(hashRechargeTransaction(_ethAmount, _ticketNumber, msg.sender, nonce) == hash, "Invalid hash!");
        //验证签名
        require(matchAddressSigner(hash, signature), "Invalid signature!");
        require(msg.value >= _ethAmount, "The ether of be sent must be more than the ethAmount!");
        payable(address(this)).transfer(_ethAmount);
        if (msg.value > _ethAmount) {
            payable(msg.sender).transfer(msg.value - _ethAmount);
        }
        emit Recharge(_ethAmount, _ticketNumber, msg.sender, nonce);
    }

    function setSignerAddress(address _signerAddress) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender));
        signerAddress = _signerAddress;
    }

    function withdraw(uint256 _amount,address _contractAddress, uint256 _tokenId, address _fromAddress,bool specifyCreator,bytes32 hash, bytes memory signature, string memory nonce) public whenNotPaused{
        //验证hash
        require(hashWithdrawTransaction(_amount,_tokenId,_contractAddress,_fromAddress,msg.sender, nonce) == hash, "Invalid hash!");
        //验证签名
        require(matchAddressSigner(hash, signature), "Invalid signature!");
        if (_fromAddress != address(0)){
            assert(_transferNFT(_amount,_contractAddress,_tokenId,_fromAddress));
        }else{
            assert(_mintNFT(_amount,_contractAddress, _tokenId, specifyCreator));
        }
        emit WithdrawNFT(_amount, _contractAddress, _tokenId, _fromAddress, msg.sender, nonce);
    }

    function batchWithdraw(uint256[] memory _amountArray,address[] memory _contractAddressArray, uint256[] memory _tokenIdArray, address[] memory _fromAddressArray,bool specifyCreator, bytes32 hash, bytes memory signature, string memory nonce) public whenNotPaused{
        //验证hash
        require(hasBatchWithdrawTransaction(_amountArray, _contractAddressArray, _tokenIdArray,_fromAddressArray,msg.sender,nonce) == hash, "Invalid hash!");
        //验证签名
        require(matchAddressSigner(hash, signature), "Invalid signature!");
        uint256 totalNum = 0;
        for (uint256 i = 0; i < _amountArray.length; i++) {
            if (_fromAddressArray[i] != address(0)){
                assert(_transferNFT(_amountArray[i],_contractAddressArray[i],_tokenIdArray[i],_fromAddressArray[i]));
                ++totalNum;
            }else{
                assert(_mintNFT(_amountArray[i],_contractAddressArray[i],_tokenIdArray[i],specifyCreator));
                ++totalNum;
            }
        }
        assert(totalNum == _amountArray.length);
        emit BatchWithdrawNFT(_amountArray, _contractAddressArray, _tokenIdArray, _fromAddressArray, msg.sender, nonce);
    }

    function _transferNFT(uint256 _amount, address _contractAddress, uint256 _tokenId, address _fromAddress)internal returns (bool){
        //转移NFT
        if (_checkProtocol(_contractAddress) == 1) {
            ERC1155 withdrawNFTContract = ERC1155(_contractAddress);
            withdrawNFTContract.safeTransferFrom(_fromAddress, msg.sender, _tokenId, _amount, abi.encode(_fromAddress));
            return true;
        }
        if (_checkProtocol(_contractAddress) == 2) {
            ERC721 withdrawNFTContract = ERC721(_contractAddress);
            withdrawNFTContract.safeTransferFrom(_fromAddress, msg.sender, _tokenId);
            return true;
        }
        return false;
    }

    function _mintNFT(uint256 _amount,address _contractAddress, uint256 _tokenId,bool specifyCreator) internal returns(bool){
        if (_checkProtocol(_contractAddress) == 1) {
            Common1155NFT withdrawNFTContract = Common1155NFT(_contractAddress);
            withdrawNFTContract.mint(msg.sender, _tokenId, _amount, specifyCreator);
            return true;
        }
        if (_checkProtocol(_contractAddress) == 2) {
            Common721NFT withdrawNFTContract = Common721NFT(_contractAddress);
            withdrawNFTContract.mint(msg.sender, _tokenId);
            return true;
        }
        return false;
    }

//    function _batchMintNFT(uint256[] memory _amountArray,address[] memory _contractAddressArray, uint256[] memory _tokenIdArray,bool specifyCreator){
//        uint256 totalNum = 0;
//        for (uint256 i = 0; i < _amountArray.length; i++) {
//            assert(_mintNFT(_amountArray[i],_contractAddressArray[i],_tokenIdArray[i],specifyCreator));
//            ++totalNum;
//        }
//        if (totalNum == _amountArray.length){
//            return true;
//        }else{
//            return false;
//        }
//    }
//
//    function _batchTransferNFT(uint256[] memory _amountArray, address[] memory _contractAddressArray, uint256[] memory _tokenIdArray, address[] memory _fromAddressArray)internal  returns (bool){
//        //转移NFT
//        uint256 totalNum = 0;
//        for (uint256 i = 0; i < _amountArray.length; i++) {
//            assert(_transferNFT(_amountArray[i],_contractAddressArray[i],_tokenIdArray[i],_fromAddressArray[i]));
//            ++totalNum;
//        }
//        if (totalNum == _amountArray.length){
//            return true;
//        }else{
//            return false;
//        }
//    }

    function _checkProtocol(address _contractAddress) internal view returns (uint256){
        IERC165 Contract = IERC165(_contractAddress);
        if (Contract.supportsInterface(INTERFACE_SIGNATURE_ERC1155)) {
            //1---ERC1155
            return 1;
        }
        if (Contract.supportsInterface(INTERFACE_SIGNATURE_ERC721)) {
            //2---ERC721
            return 2;
        }
        revert("Invalid contract protocol!");
    }

    function hashRechargeTransaction(uint256 _ethAmount, uint256 _ticketNumber, address sender, string memory nonce) private pure returns (bytes32) {
        bytes32 hash = keccak256(
            abi.encodePacked(
                "\x19Ethereum Signed Message:\n32",
                keccak256(abi.encodePacked(_ethAmount, _ticketNumber, sender, nonce, "ichiban_recharge"))
            )
        );
        return hash;
    }

    function hashWithdrawTransaction(uint256 _amount, uint256 _tokenId, address _contractAddress, address _fromAddress,address _toAddress, string memory nonce) private pure returns (bytes32) {
        bytes32 hash = keccak256(
            abi.encodePacked(
                "\x19Ethereum Signed Message:\n32",
                keccak256(abi.encodePacked(_amount, _tokenId, _contractAddress, _fromAddress,_toAddress,nonce,"ichiban_withdraw"))
            )
        );
        return hash;
    }

    function hasBatchWithdrawTransaction(uint256[] memory _amountArray,address[] memory _contractAddressArray, uint256[] memory _tokenIdArray,  address[] memory _fromAddressArray,address _toAddress, string memory nonce) private pure returns (bytes32) {
        bytes32 hash = keccak256(
            abi.encodePacked(
                "\x19Ethereum Signed Message:\n32",
                keccak256(abi.encodePacked(_amountArray,_tokenIdArray,_contractAddressArray, _fromAddressArray,_toAddress,nonce,"ichiban_withdraw"))
            )
        );
        return hash;
    }

    function matchAddressSigner(bytes32 hash, bytes memory signature) internal view returns (bool) {
        return signerAddress == recoverSigner(hash, signature);
    }

    function withdrawETH() public payable {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender));
        uint256 withdrawETH = address(this).balance - 0.01 ether;
        payable(msg.sender).transfer(withdrawETH);
    }
}