// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/presets/ERC721PresetMinterPauserAutoId.sol";

contract RentableERC721 is ERC721PresetMinterPauserAutoId {
    mapping(uint256 => address) operators;
    mapping(uint256 => uint256) rentedUntil;
    mapping(address => uint256) operatorsBalance;
    mapping(uint256 => address) tokenApproveSettingOperator;

    constructor(
        string memory _name,
        string memory _symbol,
        string memory _baseTokenURI
    ) ERC721PresetMinterPauserAutoId(_name, _symbol, _baseTokenURI) {}

    function approveSettingOperator(address to, uint256 tokenId) external {
        require(
            _isApprovedOrOwner(msg.sender, tokenId),
            "Rentable-ERC721: Setting operator can be approved only by owner or approved"
        );
        tokenApproveSettingOperator[tokenId] = to;
    }

    function isApprovedSettingOperator(uint256 tokenId, address addr)
        external
        view
        returns (bool)
    {
        return tokenApproveSettingOperator[tokenId] == addr;
    }

    function setOperator(
        address _operatorAddress,
        uint256 _tokenId,
        uint256 _numberOfBlocks
    ) external {
        require(
            ownerOf(_tokenId) == msg.sender ||
                tokenApproveSettingOperator[_tokenId] == msg.sender,
            "Rentable-ERC721: set operator caller is not owner nor approved"
        );

        require(
            operators[_tokenId] == address(0),
            "Rentable-ERC721: token is already rented"
        );

        operators[_tokenId] = _operatorAddress;
        rentedUntil[_tokenId] = block.number + _numberOfBlocks;
        operatorsBalance[_operatorAddress]++;
    }

    function removeOperator(uint256 _tokenId) external {
        require(
            ownerOf(_tokenId) == msg.sender ||
                tokenApproveSettingOperator[_tokenId] == msg.sender,
            "Rentable-ERC721: remove operator caller is not owner nor approved"
        );

        require(
            operators[_tokenId] != address(0),
            "Rentable-ERC721: token is not rented"
        );

        require(
            rentedUntil[_tokenId] < block.number,
            "Rentable-ERC721: cannot remove operator before the rent agreement expires"
        );

        operatorsBalance[operators[_tokenId]]--;
        operators[_tokenId] = address(0);
    }

    function balanceOfOperator(address _operatorAddress)
        external
        view
        returns (uint256)
    {
        return operatorsBalance[_operatorAddress];
    }

    function operatorOf(uint256 _tokenId) external view returns (address) {
        return operators[_tokenId];
    }
}