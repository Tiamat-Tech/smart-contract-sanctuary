//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./IMetroVerseCitizen.sol";

contract MetroVerseCitizen is IMetroVerseCitizen, ERC721, Ownable {
    Version[] public versions;
    Metronion[] private _metronions;
    string private _uri;

    constructor(
        string memory baseURI,
        uint maxSupply,
        uint salePrice,
        uint startTime,
        uint revealTime,
        string memory provenance
    ) ERC721("MetroVerse Citizen", "METRONION") {
        _uri = baseURI;
        versions.push(Version(0, 0, maxSupply, salePrice, startTime, revealTime, provenance));
    }

    function setBaseURI(string memory baseURI) external onlyOwner {
        _uri = baseURI;
    }

    function mintMetronion(uint versionId, uint amount) external override payable {
        Version storage version = versions[versionId];

        require(amount > 0 && amount <= 50, "Metronion: amount out of range");
        require(block.timestamp >= version.startTime, "Metronion: sale not started");
        require(version.currentSupply + amount <= version.maxSupply, "Metronion: sold out");
        require(msg.value == version.salePrice * amount, "Metronion: incorrect value");

        for (uint i = 0; i < amount; i++) {
            uint metronionId = _createMetronion();
            _mint(msg.sender, metronionId);
        }

        version.currentSupply += amount;

        (bool isSuccess,) = owner().call{value: msg.value}("");
        require(isSuccess);
    }

    function addNewVersion(
        uint maxSupply,
        uint salePrice,
        uint startTime,
        uint revealTime,
        string memory provenance
    ) external onlyOwner {
        uint latestVersionId = getLatestVersion();
        Version memory latestVersion = versions[latestVersionId];

        require(latestVersion.currentSupply == latestVersion.maxSupply);

        versions.push(Version(0, 0, maxSupply, salePrice, startTime, revealTime, provenance));

        emit NewVersionAdded(latestVersionId + 1);
    }

    function finalizeStartingIndex(uint versionId) private {
        Version storage version = versions[versionId];

        require(version.startingIndex == 0);
        require(version.currentSupply == version.maxSupply || block.timestamp >= version.revealTime);

        uint startingIndex = uint(keccak256(abi.encodePacked(block.difficulty, block.timestamp))) % version.maxSupply;
        if (startingIndex == 0) startingIndex = startingIndex + 1;
        version.startingIndex = startingIndex;

        emit StartingIndexFinalized(versionId, startingIndex);
    }

    function getLatestVersion() public view returns (uint) {
        return versions.length - 1;
    }

    function totalSupply() external view returns (uint) {
        return _metronions.length;
    }

    function _baseURI() internal view override returns (string memory) {
        return _uri;
    }

    function _createMetronion() private returns (uint metronionId) {
        _metronions.push(Metronion("", 1));
        metronionId = _metronions.length - 1;
        emit MetronionCreated(metronionId);
    }
}