// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./NFT.sol";

contract ERC721Factory is Ownable {
    address[] public deployedContracts;
    address public lastDeployedContractAddress;

    event LogContractDeployed(
        string tokenName,
        string tokenSymbol,
        address contractAddress,
        address owner,
        uint256 time
    );

    constructor() {}

    function deployERC721(string memory tokenName, string memory tokenSymbol)
        external
        returns (address erc721Contract)
    {
        NFT deployedContract = new NFT(tokenName, tokenSymbol);

        deployedContract.transferOwnership(msg.sender);
        address deployedContractAddress = address(deployedContract);
        deployedContracts.push(deployedContractAddress);
        lastDeployedContractAddress = deployedContractAddress;

        emit LogContractDeployed(
            tokenName,
            tokenSymbol,
            deployedContractAddress,
            msg.sender,
            block.timestamp
        );

        return deployedContractAddress;
    }

    function getDeployedContractsCount() external view returns (uint256 count) {
        return deployedContracts.length;
    }
}