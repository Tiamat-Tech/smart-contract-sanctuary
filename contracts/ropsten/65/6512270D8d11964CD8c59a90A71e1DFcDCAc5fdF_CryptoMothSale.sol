// SPDX-License-Identifier: MIT
pragma solidity 0.7.3;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./ICryptoMoth.sol";

interface PaymentSplitter {
    function pay(uint id) external payable;
}

contract CryptoMothSale is AccessControl {
    using SafeMath for uint;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    uint public constant MAX_MOTHS = 10000;
    uint public constant LIFESPAN_BLOCKS = 300;

    uint public initialPrice;
    uint public decrementalPrice;
    bool public hasSaleStarted = false;
    mapping(uint256 => uint256) public blockNumberToMothNumber;
    mapping(uint256 => uint256) public mothNumberToBlockNumber;

    PaymentSplitter _paymentSplitter;
    ICryptoMoth cryptoMoth;
    address _cOwner;
    uint _splitterId;

    modifier onlyAdmin() {
        require(hasRole(ADMIN_ROLE, msg.sender), "Restricted to admins.");
        _;
    }

    constructor(address _cryptoMoth) {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(ADMIN_ROLE, msg.sender);
        cryptoMoth = ICryptoMoth(_cryptoMoth);
        _cOwner = msg.sender;
        _paymentSplitter = PaymentSplitter(0xAFde32E520222C8163e9ed162167759bAE585122);
        initialPrice = 1 ether;
        decrementalPrice = 0.0033 ether;
    }

    function dnaForBlockNumber(uint256 _blockNumber) external pure returns (bytes32) {
        return keccak256(abi.encodePacked(_blockNumber));
    }

    function canMint(uint256 _blockNumber) public view returns (bool) {
        (bool _, uint256 subResult) = block.number.trySub(LIFESPAN_BLOCKS);
        if (_blockNumber > block.number || _blockNumber < subResult) {
            return false;
        }
        return blockNumberToMothNumber[_blockNumber] == 0;
    }

    function priceForMoth(uint256 _blockNumber) public view returns (uint256) {
        require(canMint(_blockNumber), "block not allowed");
        return initialPrice - decrementalPrice * (block.number - _blockNumber);
    }
    
    function mint(uint _blockNumber) public payable {
        require(hasSaleStarted || hasRole(ADMIN_ROLE, msg.sender), "sale hasn't started");
        require(totalSupply() < MAX_MOTHS, "sold out");
        require(canMint(_blockNumber), "block number not allowed or already minted");
        require(msg.value >= priceForMoth(_blockNumber) || hasRole(ADMIN_ROLE, msg.sender), "ether value sent is below the price");
        
        cryptoMoth.mint(_blockNumber, msg.sender);
    }
    
    function tokensOfOwner(address _owner) public view returns(uint[] memory) {
        uint tokenCount = cryptoMoth.balanceOf(_owner);
        if (tokenCount == 0) {
            return new uint[](0);
        } else {
            uint[] memory result = new uint[](tokenCount);
            uint index;
            for (index = 0; index < tokenCount; index++) {
                result[index] = cryptoMoth.tokenOfOwnerByIndex(_owner, index);
            }
            return result;
        }
    }

    function setPrices(uint256 _initialPrice, uint256 _decrementalPrice) public onlyAdmin {
        initialPrice = _initialPrice;
        decrementalPrice = _decrementalPrice;
    }

    function startSale() public onlyAdmin {
        hasSaleStarted = true;
    }

    function pauseSale() public onlyAdmin {
        hasSaleStarted = false;
    }

    function totalSupply() public view returns (uint256) {
        return cryptoMoth.totalSupply();
    }

    function setSplitterId(uint __splitterId) public onlyAdmin {
        _splitterId = __splitterId;
    }

    function withdrawAll() public payable onlyAdmin {
        _paymentSplitter.pay{value: address(this).balance}(_splitterId);
    }
}