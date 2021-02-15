// SPDX-License-Identifier: MIT

pragma solidity ^0.7.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/cryptography/ECDSA.sol";

contract OG is ERC721 {
    using ECDSA for bytes32;
    using SafeERC20 for IERC20;

    address public owner;
    address public authorizer;
    mapping (address => bool) public purchased;
    
    constructor(string memory name, string memory symbol, string memory baseURI, address _owner) ERC721(name, symbol) {
        owner = msg.sender;
        authorizer = _owner;
        _setBaseURI(baseURI);
    }

    function mint(address to, bytes calldata signature) public payable {
        require(msg.value >= 1 ether, "invalid_amount");

        address signer = keccak256(abi.encodePacked(to))
            .toEthSignedMessageHash()
            .recover(signature);

        require(signer == authorizer, "invalid_signature");
        require(!purchased[to], "duplicate");

        string memory suffix = ".json";
        uint256 index = totalSupply();

        purchased[to] = true;
        _mint(to, index);
        _setTokenURI(index, string(abi.encodePacked(to, suffix)));
    }

    function withdraw(IERC20 token, uint256 amount) public {
        require(owner == msg.sender, "unauthorized");
        token.safeTransfer(msg.sender, amount);
    }

    function withdrawETH(uint256 amount) public {
        require(owner == msg.sender, "unauthorized");
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "transfer_failed");
    }
}