//SPDX-License-Identifier: Unlicense
pragma solidity ^0.6.2;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155Pausable.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./matic/BasicMetaTransaction.sol";

contract MovieERC1155 is BasicMetaTransaction, ERC1155Pausable, Ownable {
    using Counters for Counters.Counter;
    using Strings for uint256;
    Counters.Counter private _tokenIds;

    string public baseUri;

    event TokenERC1155Mint(
        address account,
        uint256 id,
        uint256 amount,
        uint256 timestamp,
        bytes data,
        string tokenData,
        string mediaUri
    );
    event TokenERC1155MintBatch(
        address to,
        uint256[] ids,
        uint256[] amounts,
        uint256 timestamp,
        bytes data,
        string tokenData,
        string mediaUri
    );

    constructor(
        string memory _tokenUri,
        // https://myapi.com/?id={id}
        string memory _baseUri
    ) public ERC1155(_tokenUri) {
        baseUri = _baseUri;
    }

    function setBaseUri(string memory _newBaseMetadataURI) public onlyOwner {
        baseUri = _newBaseMetadataURI;
    }

    function setTokenUri(string memory _newTokenURI) public onlyOwner {
        _setURI(_newTokenURI);
    }

    function uri(uint256 tokenId)
        external
        view
        override
        returns (string memory)
    {
        require(
            tokenId <= _tokenIds.current(),
            "Can't get uri of token id if does not exist"
        );
        return string(abi.encodePacked(baseUri, tokenId.toString()));
    }

    function mint(
        address account,
        uint256 amount,
        bytes memory data,
        string memory tokenData,
        string memory mediaUri
    ) public onlyOwner {
        _tokenIds.increment();
        uint256 tokenId = _tokenIds.current();
        _mint(account, tokenId, amount, data);
        emit TokenERC1155Mint(
            account,
            tokenId,
            amount,
            block.timestamp,
            data,
            tokenData,
            mediaUri
        );
    }

    function mintBatch(
        address to,
        uint256[] memory amounts,
        bytes memory data,
        string memory tokenDatum,
        string memory mediaUris
    ) public onlyOwner {
        uint256[] memory tokenIds = new uint256[](amounts.length);
        for (uint256 j = 0; j < amounts.length; j++) {
            _tokenIds.increment();
            tokenIds[j] = _tokenIds.current();
        }
        _mintBatch(to, tokenIds, amounts, data);
        emit TokenERC1155MintBatch(
            to,
            tokenIds,
            amounts,
            block.timestamp,
            data,
            tokenDatum,
            mediaUris
        );
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function balanceOf(address account) public view returns (uint256) {
        uint256 balance;

        for (uint256 i; i < _tokenIds.current(); i++) {
            balance = balance.add(balanceOf(account, i));
        }
        return balance;
    }
}