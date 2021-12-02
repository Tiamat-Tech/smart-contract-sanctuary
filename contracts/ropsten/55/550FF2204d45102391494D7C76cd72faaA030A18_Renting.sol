// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./rentable-ERC721.sol";

contract Renting {
    event NewContract(uint256 contractId, address indexed contractAddress);

    mapping(address => uint256) addressIds;
    RentableERC721[] contracts;

    mapping(uint256 => mapping(uint256 => uint256)) nftRentPrice;
    mapping(uint256 => mapping(uint256 => uint256)) nftMaximumNumberOfBlocksPerRent;
    mapping(address => uint256) balance;

    constructor() {}

    function addContract(address contractAddress) external {
        require(
            addressIds[contractAddress] == 0,
            string(
                abi.encodePacked(
                    "Renting: Contract already added with Id",
                    addressIds[contractAddress]
                )
            )
        );

        contracts.push(RentableERC721(contractAddress));

        uint256 contractId = contracts.length - 1;

        addressIds[contractAddress] = contractId;
        emit NewContract(contractId, contractAddress);
    }

    function listTokenForRent(
        uint256 contractId,
        uint256 tokenId,
        uint256 pricePerBlock
    ) public {
        require(pricePerBlock > 0, "Renting: Rent cannot be free");

        require(
            contracts[contractId].isApprovedSettingOperator(
                tokenId,
                address(this)
            ),
            "Renting: Contract is not approved for setting operator for given token"
        );

        require(contracts[contractId].ownerOf(tokenId) == msg.sender);

        nftRentPrice[contractId][tokenId] = pricePerBlock;
    }

    function listTokenForRent(
        uint256 contractId,
        uint256 tokenId,
        uint256 pricePerBlock,
        uint256 maximumNumberOfBlocks
    ) external {
        listTokenForRent(contractId, tokenId, pricePerBlock);

        nftMaximumNumberOfBlocksPerRent[contractId][
            tokenId
        ] = maximumNumberOfBlocks;
    }

    function rentToken(
        uint256 contractId,
        uint256 tokenId,
        uint256 numberOfBlocks
    ) external payable {
        require(
            nftRentPrice[contractId][tokenId] > 0,
            "Renting: Token is not listed for rent"
        );

        require(
            nftMaximumNumberOfBlocksPerRent[contractId][tokenId] == 0 ||
                nftMaximumNumberOfBlocksPerRent[contractId][tokenId] >=
                numberOfBlocks,
            string(
                abi.encodePacked(
                    "Renting: You can rent the nft for maximum",
                    numberOfBlocks
                )
            )
        );

        require(
            msg.value >= nftRentPrice[contractId][tokenId] * numberOfBlocks,
            string(
                abi.encodePacked(
                    "Renting: You should pay at least ",
                    nftRentPrice[contractId][tokenId],
                    " per block"
                )
            )
        );

        contracts[contractId].setOperator(msg.sender, tokenId, numberOfBlocks);
        balance[contracts[contractId].ownerOf(tokenId)] += msg.value;
    }

    function removeRenterFromBeingOperator(uint256 contractId, uint256 tokenId)
        external
    {
        contracts[contractId].removeOperator(tokenId);
    }

    function collectRent() external {
        uint256 sum = balance[msg.sender];
        balance[msg.sender] = 0;
        (bool success, ) = msg.sender.call{value: sum}("");
        require(success, "Renting: Transfer failed");
    }
}