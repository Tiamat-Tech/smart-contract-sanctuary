// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {Base64} from "./Base64.sol";
import {Hex} from "./Hex.sol";

contract BountyBox is ERC721, ERC721Enumerable, Ownable, ReentrancyGuard {

    bytes private constant cipher = hex"00112233";
    uint256 public constant price = 0.001 ether;
    uint256 public constant bounty = 0.002 ether;
    address public solver = address(0);
    address public constant guardian = 0x8D951a48f5674083C66aD23901541959f62E29ec;

    constructor() ERC721("BountyBox Token", "BBT") Ownable() {}

    function _maxTokens() private pure returns(uint) {
        return cipher.length;
    }

    function mint(address _to, uint _count) external payable nonReentrant {
        require(_count > 0, "at least one token must be minted");
        require(totalSupply() < _maxTokens(), "sale end");
        require(totalSupply() + _count <= _maxTokens(), "not enough tokens remaining");
        require(owner() == msg.sender || msg.value >= _count * price, "value below price");

        for (uint i = 0; i < _count; i++) {
            uint tokenId = totalSupply();
            _safeMint(_to, tokenId);
        }
    }

    function solve(address payable _solver) external nonReentrant {
        require(msg.sender == guardian, "can only be called by guardian");
        require(totalSupply() >= _maxTokens(), "not all tokens have been minted");
        require(!_isBountyClaimed(), "bounty has already been claimed");
        require(balanceOf(_solver) > 0, "solver has no tokens");

        solver = _solver;
        Address.sendValue(_solver, Math.min(address(this).balance, bounty));
    }

    function withdraw(uint256 _amount) external onlyOwner {
        require(address(this).balance >= _amount, "insufficient funds");
        uint256 remainingIncome = (_maxTokens() - totalSupply()) * price;
        require(_isBountyClaimed() || (address(this).balance + remainingIncome) -_amount >= bounty, "bounty may not be withdrawn");
        Address.sendValue(payable(msg.sender), _amount);
    }

    function _isBountyClaimed() private view returns(bool) {
        return solver != address(0);
    }

    function tokenURI(uint256 tokenId) override public pure returns (string memory) {
        require(tokenId < _maxTokens(), "invalid token ID");

        string memory codeText = string(
            abi.encodePacked(
                '<text x="50%" y="50%" dy="40" fill="white" font-size="120" style="font-family:Helvetica,sans-serif" dominant-baseline="middle" text-anchor="middle">',
                Hex.encode(cipher[tokenId]),
                '</text>'
            )
        );

        bytes memory image = abi.encodePacked(
            '<svg width="1000" height="1000" viewBox="0 0 1000 1000" fill="none" xmlns="http://www.w3.org/2000/svg"><path fill="#000" d="M0 0h1000v1000H0z"/>',
            codeText,
            '<path d="M322 241.5H677C722.011 241.5 758.5 277.989 758.5 323V678C758.5 723.011 722.011 759.5 677 759.5H322C276.989 759.5 240.5 723.011 240.5 678V323C240.5 277.989 276.989 241.5 322 241.5Z" stroke="url(#paint0_linear)" stroke-width="15"/><defs><linearGradient id="paint0_linear" x1="337" y1="294" x2="638" y2="706" gradientUnits="userSpaceOnUse"><stop stop-color="#5BB1FA"/><stop offset="0.20" stop-color="#FCB3EB"/><stop offset="0.35" stop-color="#DAE9C4"/><stop offset="0.54" stop-color="#08F8F9"/><stop offset="0.67" stop-color="#6C9BFF"/><stop offset="0.77" stop-color="#D470EB"/><stop offset="0.87" stop-color="#CB75EB"/><stop offset="1" stop-color="#1DDBE7"/></linearGradient></defs></svg>'
        );

        return string(
            abi.encodePacked(
                'data:application/json;base64,',
                Base64.encode(
                    bytes(
                        abi.encodePacked(
                                '{"name":"',
                                string(abi.encodePacked("BountyBox #", Strings.toString(tokenId))),
                                '", "description":"',
                                "BountyBox is tricky.",
                                '", "image": "',
                                'data:image/svg+xml;base64,',
                                Base64.encode(image),
                                '"}'
                        )
                    )
                )
            )
        );
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721Enumerable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}