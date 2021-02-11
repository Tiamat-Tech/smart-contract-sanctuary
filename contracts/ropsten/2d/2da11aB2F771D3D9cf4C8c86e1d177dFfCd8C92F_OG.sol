// SPDX-License-Identifier: MIT

pragma solidity ^0.7.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/cryptography/ECDSA.sol";

contract OG is ERC721 {
    using ECDSA for bytes32;
    using SafeERC20 for IERC20;

    address private owner;
    
    constructor(string memory name, string memory symbol, string memory baseURI) ERC721(name, symbol) {
        owner = _msgSender();
        _setBaseURI(baseURI);
    }

    function mint(address to, bytes calldata signature) public payable {
        require(msg.value >= 1 ether, "Incorrect amount");

        address signer = keccak256(abi.encode(to))
            .toEthSignedMessageHash()
            .recover(signature);

        require(signer == owner, "Incorrect signature");

        string memory suffix = ".json";
        uint256 index = totalSupply();

        _mint(to, index);
        _setTokenURI(index, string(abi.encodePacked(to, suffix)));
    }

    function withdraw(IERC20 token, uint256 amount) public {
        require(owner == _msgSender(), "Not admin");
        token.safeTransfer(_msgSender(), amount);
    }

    function withdrawETH(uint256 amount) public {
        require(owner == _msgSender(), "Not admin");
        _msgSender().transfer(amount);
    }
}