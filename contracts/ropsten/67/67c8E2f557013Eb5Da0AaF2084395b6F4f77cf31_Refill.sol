// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./Utils.sol";


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
    event BatchWithdrawNFT(uint256[] _amountArray, address indexed _contractAddress, uint256[] _tokenIdArray, address indexed _fromAddress, address indexed _toAddress,string nonce);

    //Fallback function
    fallback() external payable {
        emit ETHReceived(msg.sender, msg.value);
    }

    //Receive function
    receive() external payable {
        // TODO implementation the receive function
    }

    function recharge(uint256 _ethAmount, uint256 _ticketNumber, bytes32 hash, bytes memory signature, string memory nonce) public whenNotPaused{
        //验证hash
        require(hashRechargeTransaction(_ethAmount, _ticketNumber, msg.sender, nonce) == hash, "Invalid hash!");
        //验证签名
        require(matchAddressSigner(hash, signature), "Invalid signature!");
        emit Recharge(_ethAmount, _ticketNumber, msg.sender, nonce);
    }

    function setSignerAddress(address _signerAddress) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender));
        signerAddress = _signerAddress;
    }


    function withdraw(uint256 _amount, address _contractAddress, uint256 _tokenId, address _fromAddress, bytes32 hash, bytes memory signature, string memory nonce) public whenNotPaused{
        //验证hash
        require(hashWithdrawTransaction(_amount, _tokenId,_contractAddress,_fromAddress,msg.sender, nonce) == hash, "Invalid hash!");
        //验证签名
        require(matchAddressSigner(hash, signature), "Invalid signature!");
        assert(_transferNFT(_amount,_contractAddress,_tokenId,_fromAddress));
        emit WithdrawNFT(_amount, _contractAddress, _tokenId, _fromAddress, msg.sender, nonce);
    }


    function batchWithdraw(uint256[] memory _amountArray, address _contractAddress, uint256[] memory  _tokenIdArray, address _fromAddress, bytes32 hash, bytes memory signature, string memory nonce) public whenNotPaused{
        //验证hash
        require(hasBatchWithdrawTransaction(_amountArray, _contractAddress, _tokenIdArray,_fromAddress,msg.sender, nonce) == hash, "Invalid hash!");
        //验证签名
        require(matchAddressSigner(hash, signature), "Invalid signature!");
        assert(_batchTransferNFT(_amountArray,_contractAddress,_tokenIdArray,_fromAddress));
        emit BatchWithdrawNFT(_amountArray, _contractAddress, _tokenIdArray, _fromAddress, msg.sender, nonce);
    }

    function _transferNFT(uint256 _amount, address _contractAddress, uint256 _tokenId, address _fromAddress)internal  returns (bool){
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

    function _batchTransferNFT(uint256[] memory _amountArray, address _contractAddress, uint256[] memory _tokenIdArray, address _fromAddress)internal  returns (bool){
        //转移NFT
        if (_checkProtocol(_contractAddress) == 1) {
            ERC1155 withdrawNFTContract = ERC1155(_contractAddress);
            withdrawNFTContract.safeBatchTransferFrom(_fromAddress, msg.sender, _tokenIdArray, _amountArray, abi.encode(msg.sender));
            return true;
        }
        return false;
    }


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
                keccak256(abi.encodePacked(_ethAmount, _ticketNumber, sender, nonce, "Recharge"))
            )
        );
        return hash;
    }

    function hashWithdrawTransaction(uint256 _amount, uint256 _tokenId, address _contractAddress, address _fromAddress,address _toAddress, string memory nonce) private pure returns (bytes32) {
        bytes32 hash = keccak256(
            abi.encodePacked(
                "\x19Ethereum Signed Message:\n32",
                keccak256(abi.encodePacked(_amount, _tokenId, _contractAddress, _fromAddress,_toAddress,nonce,"Withdraw"))
            )
        );
        return hash;
    }

    function hasBatchWithdrawTransaction(uint256[] memory _amountArray,address _contractAddress, uint256[] memory _tokenIdArray,  address _fromAddress,address _toAddress, string memory nonce) private pure returns (bytes32) {
        bytes32 hash = keccak256(
            abi.encodePacked(
                "\x19Ethereum Signed Message:\n32",
                keccak256(abi.encodePacked(_amountArray, _contractAddress,_tokenIdArray, _fromAddress,_toAddress,nonce,"Withdraw"))
            )
        );
        return hash;
    }

    function matchAddressSigner(bytes32 hash, bytes memory signature) internal view returns (bool) {
        return signerAddress == recoverSigner(hash, signature);
    }

    /**
     * @dev  提现eth
     */
    function withdrawETH() public payable {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender));
        uint256 withdrawETH = address(this).balance - 0.001 ether;
        payable(msg.sender).transfer(withdrawETH);
    }
}