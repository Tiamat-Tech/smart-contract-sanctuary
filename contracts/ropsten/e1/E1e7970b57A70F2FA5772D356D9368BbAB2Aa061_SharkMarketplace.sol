// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface ISharkNFT {
    function getShark(uint256 _sharkId)
        external
        view
        returns (uint256 /* _genes */, uint256 /* _bornAt */);

    function bornShark(
        uint256 _sharkId,
        uint256 _genes,
        address _owner
    ) external;

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;
}