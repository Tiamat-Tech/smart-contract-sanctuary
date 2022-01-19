// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.11;

import "./Ownable.sol";

contract Storage is Ownable {
    // ipfs peer address
    string public peerAddress;

    struct Metadata {
        string ciScore;
        string ipfsHash;
    }

    // user to year to farming input
    mapping(string => mapping(string => mapping(uint256 => Metadata))) farmerToProductToYearToMetadata;

    event PeerAddressUpdated(string peerAddress);
    event CIResultStored(
        string indexed farmer,
        string indexed product,
        uint256 indexed year,
        string ciScore,
        string fileHash
    );

    //add CIScore
    function addCIResult(
        string memory _farmer,
        string memory _product,
        uint256 _year,
        string memory _score,
        string memory _hash
    ) public onlyOwner {
        farmerToProductToYearToMetadata[_farmer][_product][_year] = Metadata(
            _score,
            _hash
        );
        emit CIResultStored(_farmer, _product, _year, _score, _hash);
    }

    function getCIResult(
        string memory _farmer,
        string memory _product,
        uint256 _year
    ) public view returns (Metadata memory) {
        return farmerToProductToYearToMetadata[_farmer][_product][_year];
    }

    function setPeerAddress(string memory _peerAddress) public onlyOwner {
        peerAddress = _peerAddress;
        emit PeerAddressUpdated(peerAddress);
    }
}