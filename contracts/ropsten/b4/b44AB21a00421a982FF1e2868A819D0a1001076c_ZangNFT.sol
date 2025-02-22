// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import {Base64} from "./MetadataUtils.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./ERC1155OnChain.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/IERC1155MetadataURI.sol";
import "./ERC2981PerTokenRoyalties.sol";

contract ZangNFT is
    ERC1155OnChain,
    IERC1155MetadataURI,
    ERC2981PerTokenRoyalties
{
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    mapping(uint256 => string) private _textURIs;

    mapping(uint256 => string) private _names;

    mapping(uint256 => string) private _descriptions;

    mapping(uint256 => address) private _authors;

    constructor() ERC1155OnChain("ZangNFT", "ZNG") {}

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC1155OnChain, ERC2981PerTokenRoyalties, IERC165)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function lastTokenId() public view returns (uint256) {
        return _tokenIds.current();
    }

    function _exists(uint256 _tokenId) internal view returns (bool) {
        return lastTokenId() >= _tokenId;
    }

    function uri(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "ZangNFT: uri query for nonexistent token");
        string memory json = Base64.encode(
            bytes(
                string(
                    abi.encodePacked(
                        '{ "name": "',
                        _names[tokenId],
                        '", ',
                        '"description" : ',
                        '"',
                        _descriptions[tokenId],
                        '", ',
                        //'"image": "data:image/svg+xml;base64,', Base64.encode(bytes(output)), '", '
                        '"textURI" : ',
                        '"',
                        textURI(tokenId),
                        '"',
                        "}"
                    )
                )
            )
        );
        string memory output = string(
            abi.encodePacked("data:application/json;base64,", json)
        );

        return output;
    }

    function authorOf(uint256 _tokenId) public view returns (address) {
        address author = _authors[_tokenId];
        require(
            author != address(0),
            "ZangNFT: author query for nonexistent token"
        );
        return author;
    }

    function mint(
        string memory textURI_,
        string memory name_,
        string memory description_,
        uint256 amount_,
        uint256 royaltyPercentage_, //NB: two decimals, so 10% is 1000
        address royaltyRecipient_,
        bytes memory data_
    ) public returns (uint256) {
        _tokenIds.increment();

        uint256 newTokenId = _tokenIds.current();
        _mint(msg.sender, newTokenId, amount_, data_);
        _setTextURI(newTokenId, textURI_);
        _names[newTokenId] = name_;
        _descriptions[newTokenId] = description_;
        _authors[newTokenId] = msg.sender;
        _setTokenRoyalty(newTokenId, royaltyRecipient_, royaltyPercentage_);

        return newTokenId;
    }

    function _setTextURI(uint256 _tokenId, string memory _textURI) internal {
        _textURIs[_tokenId] = _textURI;
    }

    function textURI(uint256 tokenId)
        public
        view
        virtual
        returns (string memory)
    {
        require(
            _exists(tokenId),
            "ZangNFT: textURI query for nonexistent token"
        );
        return _textURIs[tokenId];
    }
}