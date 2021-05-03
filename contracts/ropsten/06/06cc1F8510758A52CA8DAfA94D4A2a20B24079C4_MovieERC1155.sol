//SPDX-License-Identifier: Unlicense
pragma solidity ^0.6.2;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155Pausable.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MovieERC1155 is ERC1155Pausable, Ownable {
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
        string memory _baseUri
    ) public ERC1155(_tokenUri) {
        baseUri = _baseUri;
    }

    function setBaseUri(string memory _newBaseMetadataURI) public  onlyOwner {
        baseUri = _newBaseMetadataURI;
    }

    function uri(uint256 tokenId) external view override returns (string memory) {
        require(tokenId <= _tokenIds.current(), "Can't get uri of token id if does not exist");
        return string(abi.encodePacked(baseUri, tokenId.toString()));
    }

    function mint(
        address account,
        uint256 amount,
        bytes memory data,
        string memory tokenData,
        string memory mediaUri
    ) public {
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
        string memory tokenData,
        string memory mediaUri
    ) public {
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
            tokenData,
            mediaUri
        );
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }
}