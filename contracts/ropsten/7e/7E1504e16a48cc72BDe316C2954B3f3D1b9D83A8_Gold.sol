// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "./interfaces/IZeroExExchange.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

/// @title Fundraising contract with a twist
contract Gold is Ownable, ERC721Holder {
    address immutable ERC721Proxy;
    address immutable rewardNFT;
    address immutable zeroExExchange;

    event Claimed(address indexed winner);

    error FailedToSendEther();

    constructor(
        address _ERC721Proxy,
        address _rewardNFT,
        address _zeroExExchange
    ) {
        ERC721Proxy = _ERC721Proxy;
        rewardNFT = _rewardNFT;
        zeroExExchange = _zeroExExchange;
    }

    function claim(
        IZeroExExchange.Order calldata _order,
        uint256 _tokenId,
        bytes memory _signature
    ) external payable {
        IERC721(rewardNFT).approve(ERC721Proxy, _tokenId);
        IZeroExExchange.FillResults memory results = IZeroExExchange(zeroExExchange).fillOrder{value: msg.value}(
            _order,
            _order.takerAssetAmount,
            _signature
        );
        (bool success, ) = _order.takerAddress.call{value: msg.value - results.protocolFeePaid}("");
        if (!success) revert FailedToSendEther();
        emit Claimed(_order.makerAddress);
    }

    receive() external payable {}
}