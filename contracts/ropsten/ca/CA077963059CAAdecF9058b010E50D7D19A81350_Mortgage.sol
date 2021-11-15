// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./Utils.sol";


contract Mortgage is AccessControl, Pausable, Utils {

    /* Variable */
    using SafeMath for uint256;
    address[] mortgagedAddress;
    address mortgageNFTContractAddress;
    address signerAddress;
    address mortgageNFTReceiveAddress;
    uint256 totalMortgageNFTNumLimit = 500;
    uint256 singleMortgageNFTNumLimit = 5;
    mapping(address => uint256[]) internal mortgageMap;


    /* Event */
    event Mortgage(address indexed mortgageAddress, uint256[] mortgageTokenIds, string nonce);
    event Recaption(address indexed mortgageAddress, uint256[] mortgageTokenIds, string nonce);

    constructor (address _mortgageNFTContractAddress){
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        mortgageNFTContractAddress = _mortgageNFTContractAddress;
        signerAddress = msg.sender;
        mortgageNFTReceiveAddress = msg.sender;
    }

    function setMortgageNFTReceiveAddress(address _mortgageNFTReceiveAddress) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender));
        mortgageNFTReceiveAddress = _mortgageNFTReceiveAddress;
    }


    function setMortgageNFTContractAddress(address _mortgageNFTContractAddress) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender));
        mortgageNFTContractAddress = _mortgageNFTContractAddress;
    }

    /**
     * @dev  设置签名钱包地址
     * @param _signerAddress 新的签名钱包地址
     */
    function setSignerAddress(address _signerAddress) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender));
        signerAddress = _signerAddress;
    }

    function setTotalMortgageNFTNumLimit(uint256 _mortgageNFTNumLimit) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender));
        totalMortgageNFTNumLimit = _mortgageNFTNumLimit;
    }


    function setSingleMortgageNFTNumLimit(uint256 _singleMortgageNFTNumLimit) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender));
        singleMortgageNFTNumLimit = _singleMortgageNFTNumLimit;
    }

    /**
     * @dev  抵押NFT
     * @param mortgageTokenIds 要抵押的tokenIds
     * @param hash 交易hash
     * @param signature 账户签名
     * @param nonce 交易随机数
     */
    function mortgageNFT(uint256[] memory mortgageTokenIds, bytes32 hash, bytes memory signature, string memory nonce) public {
        //验证是否已经抵押
        require(mortgageMap[msg.sender].length == 0, "You have a mortgage!");
        //验证抵押的数量是否合法
        require(mortgageTokenIds.length >= singleMortgageNFTNumLimit, "You must mortgage NFT at least 5!");
        //验证hash
        require(hashMortgageTransaction(mortgageTokenIds, msg.sender, nonce) == hash, "Invalid hash!");
        //验证签名
        require(matchAddresSigner(hash, signature), "Invalid signature!");
        //进行转移
        ERC1155 mortgageNFTContract = ERC1155(mortgageNFTContractAddress);
        uint256[] memory _amounts = _generateAmountArray(mortgageTokenIds.length);
        mortgageNFTContract.safeBatchTransferFrom(msg.sender, mortgageNFTReceiveAddress, mortgageTokenIds, _amounts, abi.encode(msg.sender));
        //记录Map
        mortgageMap[msg.sender] = mortgageTokenIds;
        //记录mortgagedAddressArray
        mortgagedAddress.push(msg.sender);
        emit Mortgage(msg.sender, mortgageTokenIds, nonce);
    }


    /**
     * @dev  用户取回NFT
     * @param hash 交易hash
     * @param signature 账户签名
     * @param nonce 交易随机数
     */
    function recaptureNFT(bytes32 hash, bytes memory signature, string memory nonce) public {
        //验证是否已经抵押
        require(mortgageMap[msg.sender].length != 0, "You dont't have a mortgage!");
        //验证hash
        require(hashRecaptionTransaction(msg.sender, nonce) == hash, "Invalid hash!");
        uint256[] memory recaptureTokenIds = mortgageMap[msg.sender];
        //验证签名
        require(matchAddresSigner(hash, signature), "Invalid signature!");
        assert(_recapture(recaptureTokenIds, msg.sender));
        //删除mortgagedAddressArray
        removeByValue(mortgagedAddress, msg.sender);
        emit Recaption(msg.sender, recaptureTokenIds, nonce);

    }

    /**
     * @dev  全部取回用户NFT
     */
    function allRecaptureNFT() public {
        //鉴权
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender));
        //转移NFT
        for (uint256 i = 0; i < mortgagedAddress.length; i++) {
            address _mortgagedAddress = mortgagedAddress[i];
            uint256[] memory _tokenIds = mortgageMap[_mortgagedAddress];
            assert(_recapture(_tokenIds, _mortgagedAddress));
        }
        delete mortgagedAddress;
    }


    function _recapture(uint256[] memory recaptureTokenIds, address sender) private returns (bool){
        //进行转移
        ERC1155 mortgageNFTContract = ERC1155(mortgageNFTContractAddress);
        uint256[] memory _amounts = _generateAmountArray(recaptureTokenIds.length);
        mortgageNFTContract.safeBatchTransferFrom(mortgageNFTReceiveAddress, sender, recaptureTokenIds, _amounts, abi.encode(msg.sender));
        //删除Map
        delete mortgageMap[msg.sender];
        return true;
    }



    /**
     * @dev  生成批量铸造时铸造数量AmountArray
     * @param _arrayLength 要铸造的TokenId数量
     * @return 铸造数量AmountArray
     */
    function _generateAmountArray(uint256 _arrayLength) internal pure returns (uint256 [] memory){
        uint256[] memory amountArray = new uint256[](_arrayLength);
        for (uint256 i = 0; i < _arrayLength; i++) {
            amountArray[i] = 1;
        }
        return amountArray;
    }


    function getMortgageAddress() public view returns (address[] memory){
        return mortgagedAddress;
    }


    function getMortgageNFT(address _owner) public view returns (uint256[] memory){
        return (mortgageMap[_owner]);
    }


    /**
     * @dev 生成抵押NFT交易的hash值
     * @param _tokenIds 要被抵押的奖品tokenId数组
     * @param sender 交易触发者
     * @param nonce 交易随机数
     * @return 交易的hash值
     */
    function hashMortgageTransaction(uint256[] memory _tokenIds, address sender, string memory nonce) private pure returns (bytes32) {
        bytes32 hash = keccak256(
            abi.encodePacked(
                "\x19Ethereum Signed Message:\n32",
                keccak256(abi.encodePacked(_tokenIds, sender, nonce))
            )
        );
        return hash;
    }

    /**
     * @dev 生成要被取回的NFT交易的hash值
     * @param sender 交易触发者
     * @param nonce 交易随机数
     * @return 交易的hash值
     */
    function hashRecaptionTransaction(address sender, string memory nonce) private pure returns (bytes32) {
        bytes32 hash = keccak256(
            abi.encodePacked(
                "\x19Ethereum Signed Message:\n32",
                keccak256(abi.encodePacked(sender, nonce))
            )
        );
        return hash;
    }

    function matchAddresSigner(bytes32 hash, bytes memory signature) internal view returns (bool) {
        return signerAddress == recoverSigner(hash, signature);
    }
}