// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "erc721a/contracts/ERC721A.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Context.sol";

contract ERC721ATest is Context, Ownable, ERC721A {

    // Mapping for nft token trusted minters
    mapping(address => bool) private _trustedMinterList;

    // Emitted when `minterAddress` added to trusted minter list.
    event AddToTrustedMinterList(address minterAddress);
    // Emitted when `minterAddress` removed from trusted minter list.
    event RemoveFromTrustedMinterList(address minterAddress);

    constructor(string memory name_, string memory symbol_) ERC721A(name_, symbol_) {
    }

//    function mint(uint256 quantity) external payable {
//        // _safeMint's second argument now takes in a quantity, not a tokenId.
//        _safeMint(msg.sender, quantity);
//    }


    function addToTrustedMinterList(address minterAddress_) external virtual onlyOwner {
        require(minterAddress_ != address(0), "ERC721A: invalid minter address");
        _trustedMinterList[minterAddress_] = true;
        emit AddToTrustedMinterList(minterAddress_);
    }

    function removeFromTrustedMinterList(address minterAddress_) external virtual onlyOwner {
        require(minterAddress_ != address(0), "ERC721A: invalid minter address");
        _trustedMinterList[minterAddress_] = false;
        emit RemoveFromTrustedMinterList(minterAddress_);
    }


    modifier onlyTrustedMinter(address minterAddress_) {
        require(_trustedMinterList[minterAddress_], "ERC721A: caller is not trust minter");
        _;
    }

    function mintToken(address recipient_, uint256 amount_) external virtual onlyTrustedMinter(_msgSender()) {
        _mintToken(recipient_, amount_);
    }

    function _mintToken(address recipient_, uint256 amount_) internal virtual {
        require(recipient_ != address(0), "ERC721A: invalid recipient address");
        require(amount_ > 0, "ERC721A: invalid amount");
        _safeMint(recipient_, amount_);
    }
}