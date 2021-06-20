//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "./NewNFT.sol";
import "@openzeppelin/contracts/access/Ownable.sol"; //https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol

contract NFTFactory is Ownable {

    event TokenCreated(address indexed token, uint256);
    address[] newContracts;

    function createTokenSalted(
        string memory name,
        string memory symbol,
        string memory tokenURI,
        bytes32 salt
    ) public {
        address predictedAddress =
            address(
                uint160(
                    uint256(
                        keccak256(
                            abi.encodePacked(
                                bytes1(0xff),
                                address(this),
                                salt,
                                keccak256(
                                    abi.encodePacked(type(NewNFT).creationCode)
                                )
                            )
                        )
                    )
                )
            );

        NewNFT newToken = new NewNFT{salt: salt}(name, symbol, tokenURI);
        require(address(newToken) == predictedAddress);
        newContracts.push(predictedAddress);
        emit TokenCreated(predictedAddress, newContracts.length);
    }

    function howManyTokens() external view returns (uint256) {
        return newContracts.length;
    }

    function newTokenAddress() external view returns (string memory) {
        return toAsciiString(newContracts[newContracts.length - 1]);
    }

    function toAsciiString(address x) internal view returns (string memory) {
        bytes memory s = new bytes(40);
        for (uint256 i = 0; i < 20; i++) {
            bytes1 b = bytes1(uint8(uint256(uint160(x)) / (2**(8 * (19 - i)))));
            bytes1 hi = bytes1(uint8(b) / 16);
            bytes1 lo = bytes1(uint8(b) - 16 * uint8(hi));
            s[2 * i] = char(hi);
            s[2 * i + 1] = char(lo);
        }
        return string(s);
    }

    function char(bytes1 b) internal view returns (bytes1 c) {
        if (uint8(b) < 10) return bytes1(uint8(b) + 0x30);
        else return bytes1(uint8(b) + 0x57);
    }
}