// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

import "./NftExample.sol";

contract Market is ERC721Holder, Ownable {
	struct Ask {
		uint256 price;
		uint256 nftId;
		uint256 index;
		address owner;
		uint256 listTime;
		uint256 soldTime;
	}

	NftExample public nft;
	IERC20 public usdc;
	bytes32[] public indexer;
	uint256 public indexerLength;
	mapping(bytes32 => Ask) public listings;

	event PlaceAsk(bytes32 askId);

	constructor(address _usdcAddress, NftExample _nft) {
		usdc = IERC20(_usdcAddress);
		nft = _nft;
	}

	modifier ownerOnly(uint256 nftId) {
		require(nft.ownerOf(nftId) == _msgSender(), "you must be the owner of the nft");
		_;
	}

	function getIndexLength() public view virtual returns (uint256) {
		return indexerLength;
	}

	function getIndexer() public view virtual returns (bytes32[] memory) {
		return indexer;
	}

	function getFullMarket() public view returns (Ask[] memory) {
		Ask[] memory asks = new Ask[](indexerLength);
		for (uint256 i = 0; i < indexerLength; i++) {
			asks[i] = listings[indexer[i]];
		}
		return asks;
	}

	function getAsk(bytes32 askId) public view virtual returns (Ask memory) {
		return listings[askId];
	}

	function marketOperable(bytes32 askId) internal virtual {
		require(listings[askId].soldTime == 0, "nft product already sold");
	}

	function getAskId(uint256 nftId, address user) public pure returns (bytes32 askId) {
		askId = keccak256(abi.encodePacked(nftId, user));
	}

	function popFromIndexer(bytes32 askId) internal virtual {
		uint256 index = listings[askId].index;
		indexer[index] = indexer[indexerLength - 1];
		listings[indexer[index]].index = index;
		delete indexer[indexerLength - 1];
		indexerLength--;
	}

	function placeAsk(uint256 nftId, uint256 price) external virtual ownerOnly(nftId) returns (bytes32 askId) {
		bytes32 askId = getAskId(nftId, _msgSender());
		marketOperable(askId);

		if (listings[askId].listTime == 0) {
			listings[askId] = Ask(price, nftId, indexerLength, _msgSender(), block.timestamp, 0);

			if (indexerLength == indexer.length) {
				indexer.push(askId);
			} else {
				indexer[indexerLength] = askId;
			}

			indexerLength++;
			nft.safeTransferFrom(_msgSender(), address(this), nftId);
		}
		listings[askId].price = price;

		emit PlaceAsk(askId);

		return askId;
	}

	function revokeAsk(uint256 nftId) external virtual {
		bytes32 askId = getAskId(nftId, _msgSender());
		marketOperable(askId);

		require(listings[askId].listTime != 0, "cannot revoke ask for unlisted nft product");
		nft.safeTransferFrom(address(this), _msgSender(), listings[askId].nftId);

		popFromIndexer(askId);
		delete listings[askId];
	}

	function buy(bytes32 askId) external virtual {
		uint256 nftId = listings[askId].nftId;
		uint256 price = listings[askId].price;

		usdc.transferFrom(_msgSender(), listings[askId].owner, price);
		nft.safeTransferFrom(address(this), _msgSender(), nftId);

		popFromIndexer(askId);
		listings[askId].soldTime = block.timestamp;
	}
}