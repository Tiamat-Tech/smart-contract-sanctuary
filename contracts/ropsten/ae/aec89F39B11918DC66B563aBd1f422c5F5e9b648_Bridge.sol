//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.10;
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
contract Bridge {
    
    using ECDSA for bytes32;

    // set in constructor
    address public owner;
    uint public immutable chainId;
    // signer => tokenAddress => isValid
    mapping(address => mapping(address => bool)) public trustedSigner;
    mapping(uint => bool) public orders;
    modifier onlyOwner() {
        require(msg.sender == owner, "caller must be owner");
        _;
    }

    event payInEvent(
        address indexed user,
        address indexed tokenAddress,
        uint256 indexed orderId,
        uint256 amount
    );

    event payOutEvent(
        address indexed user,
        address indexed tokenAddress,
        uint256 indexed orderId,
        uint256 amount
    );

    constructor(uint _chainId) {
        chainId = _chainId;
        owner = msg.sender;
    }

    function payIn(
        uint _orderId,
        uint _amount, 
        address _tokenAddress,
        bytes32 _msgForSign, 
        bytes calldata _signature
    ) external {
        require(trustedSigner[_msgForSign.recover(_signature)][_tokenAddress], "bad signer");
        require(!orders[_orderId], "used order id");
        require(keccak256(abi.encode(
            _orderId,
            msg.sender,
            _amount,
            0, // <- direction
            chainId, 
            _tokenAddress
            )).toEthSignedMessageHash() == _msgForSign, "bad data in msgForSign");
        orders[_orderId] = true;
        emit payInEvent(msg.sender, _tokenAddress, _orderId, _amount);
        IERC20(_tokenAddress).transferFrom(msg.sender, address(this), _amount);            
    }


    function payOut(
        uint _orderId,
        uint _amount,
        address _tokenAddress,
        bytes32 _msgForSign, 
        bytes calldata _signature
    ) external {
        require(trustedSigner[_msgForSign.recover(_signature)][_tokenAddress], "bad signer");
        require(!orders[_orderId], "used order id");
        require(keccak256(abi.encode(
            _orderId,
            msg.sender,
            _amount,
            1, // <-- direction
            chainId,
            _tokenAddress
            )).toEthSignedMessageHash() == _msgForSign, "bad data in msgForSign");
        orders[_orderId] = true;
        emit payOutEvent(msg.sender, _tokenAddress, _orderId, _amount);
        IERC20(_tokenAddress).transfer(msg.sender, _amount);
    }

    //////////////////////////////////////
    ////   Admin functions    ////////////
    //////////////////////////////////////

    function setSigner(address signer, address tokenAddress, bool isValid) external onlyOwner {
        trustedSigner[signer][tokenAddress] = isValid;
    }

    function changeOwner(address newOwner) external onlyOwner {
        require(newOwner != address(0), "zero address");
        owner = newOwner;
    }
}