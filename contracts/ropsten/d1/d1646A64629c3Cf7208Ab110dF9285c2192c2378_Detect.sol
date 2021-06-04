// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract Detect {

    enum TokenType { ERC20, ERC721, Invalid }

    // getting these ERC165 id's from https://github.com/ethereum/EIPs/blob/master/EIPS/eip-721.md#specification
    bytes4 private constant _ERC721_EIP165ID = 0x80ac58cd;
    bytes4 private constant _ERC721_TOKENRECEIVER_EIP165ID = 0x150b7a02;
    bytes4 private constant _ERC721_METADATA_EIP165ID = 0x5b5e139f;
    bytes4 private constant _ERC721_ENUMERABLE_EIP165ID = 0x780e9d63;

    function isERC20(address contractAddress) public view returns (bool) {
        (bool success, ) = contractAddress.staticcall(abi.encodeWithSignature("decimals()"));
        return success;
    }

    function isERC721(address contractAddress) public view returns (bool) {
        (bool success_erc721, ) = contractAddress.staticcall(abi.encodeWithSignature("supportsInterface(bytes4)", _ERC721_EIP165ID));
        (bool success_erc721tokenreceiver, ) = contractAddress.staticcall(abi.encodeWithSignature("supportsInterface(bytes4)", _ERC721_TOKENRECEIVER_EIP165ID));
        (bool success_erc721metadata, ) = contractAddress.staticcall(abi.encodeWithSignature("supportsInterface(bytes4)", _ERC721_METADATA_EIP165ID));
        (bool success_erc721enumerable, ) = contractAddress.staticcall(abi.encodeWithSignature("supportsInterface(bytes4)", _ERC721_ENUMERABLE_EIP165ID));

        if (success_erc721 || success_erc721tokenreceiver || success_erc721metadata || success_erc721enumerable) {
            return true;
        }
        return false;
    }

    function detectTokenType(address contractAddress) public view returns (TokenType) {
        if (isERC20(contractAddress)) {
            return TokenType.ERC20;
        }  
        if (isERC721(contractAddress)) {
            return TokenType.ERC721;
        }
        return TokenType.Invalid;
    }
}