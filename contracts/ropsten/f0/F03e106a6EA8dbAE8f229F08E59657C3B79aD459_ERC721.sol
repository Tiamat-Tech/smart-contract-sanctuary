// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/utils/Address.sol";

interface IERC721 {
    event Transfer(
        address indexed from,
        address indexed to,
        uint256 indexed tokenId
    );
    event Approval(
        address indexed owner,
        address indexed approved,
        uint256 indexed tokenId
    );
    event ApprovalForAll(
        address indexed owner,
        address indexed operator,
        bool approved
    );

    function balanceOf(address owner) external view returns (uint256 balance);

    function ownerOf(uint256 tokenId) external view returns (address owner);

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    function approve(address to, uint256 tokenId) external;

    function getApproved(uint256 tokenId)
        external
        view
        returns (address operator);

    function setApprovalForAll(address operator, bool _approved) external;

    function isApprovedForAll(address owner, address operator)
        external
        view
        returns (bool);

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes calldata data
    ) external;
}

contract ERC721 is IERC721 {
    using Address for address;
    
    string public _name;
    string public _symbol;

    mapping(uint256 => address) private _owners;

    mapping(address => uint256) private _balances;

    mapping(uint256 => address) private _tokenApprovals;

    mapping(address => mapping(address => bool)) private _operatorApprovals;

    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

       function balanceOf(address owner) public override view returns (uint256 balance) {
        require(owner != address(0), "ERC721 - balance query for the address(0)");
        return _balances[owner];
    }

       function ownerOf(uint256 tokenId) public override view returns (address owner) {
        owner = _owners[tokenId];
        require(owner != address(0), "ERC721 - owner query for token that does not exist");
    }

       function _exists(uint256 tokenId) private view returns (bool) {
        return _owners[tokenId] != address(0);
    }

       function approve(address to, uint256 tokenId) external override {
        address owner = ERC721.ownerOf(tokenId);
        require(to != owner, "ERC721 - giving token approval to owner");

        require(
            owner == msg.sender || isApprovedForAll(owner, msg.sender),
            "ERC721 - Sender is not owner or operator"
        );

        _approve(owner, to, tokenId);
    }

       function _approve(address owner, address to, uint256 tokenId) private {
        _tokenApprovals[tokenId] = to;
        emit Approval(owner, to, tokenId);
    }

       function getApproved(uint256 tokenId) public override view returns (address operator) {
        require(_exists(tokenId), "ERC721 - approved account query for token that does not exists");

        return _tokenApprovals[tokenId];
    }

       function setApprovalForAll(address operator, bool _approved) external override {
        require(operator != msg.sender, "ERC721 - operator is owner");
        _operatorApprovals[msg.sender][operator] = _approved;
        emit ApprovalForAll(msg.sender, operator, _approved);
    }

       function isApprovedForAll(address owner, address operator) public override view returns (bool) {
        return _operatorApprovals[owner][operator];
    }

       function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) private {
        address owner = ownerOf(tokenId);
        require(msg.sender == owner || isApprovedForAll(owner, msg.sender) ||
            getApproved(tokenId) == msg.sender, "ERC721 - sender is not owner, approved or operator");

        require(from == owner, "ERC721 - address of from is different from token owner");

        _approve(from, address(0), tokenId);

        _balances[from] -= 1;
        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(from, to, tokenId);
    }

       function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external override {
        _transfer(from, to, tokenId);
    }

       function safeTransferFrom(address from, address to, uint256 tokenId) public override {
        _transfer(from, to, tokenId);
        require(_checkOnERC721Received(from, to, tokenId, ""), "ERC721 - transfer to non ERC721Receiver implementer");
    }

       function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory _data) public override {
        _transfer(from, to, tokenId);
        require(_checkOnERC721Received(from, to, tokenId, _data), "ERC721 - transfer to non ERC721Receiver implementer");
    }

       function safeMint(address to, uint256 tokenId) public {
        safeMint(to, tokenId, "");
    }

       function safeMint(address to, uint256 tokenId, bytes memory _data) public {
        _mint(to, tokenId);
        require(
            _checkOnERC721Received(address(0), to, tokenId, _data),
            "ERC721 - transfer to non ERC721Receiver implementer"
        );
    }

       function _mint(address to, uint tokenId) internal {
        require(!_exists(tokenId), "ERC721 - tokenId already exists");
        require(to != address(0), "ERC721 - to is zero address");
        
        _balances[to] += 1;
        _owners[tokenId] = to;
        emit Transfer(address(0), to, tokenId);
    }
    
      function _burn(uint tokenId) public {
        address owner = ownerOf(tokenId);
        require(owner != address(0), "ERC721 - tokenId does not exist");
        _approve(owner, address(0), tokenId);
        _balances[owner] -= 1;
        delete _owners[tokenId];
        emit Transfer(owner, address(0), tokenId);
    }

      function _checkOnERC721Received(address from, address to, uint256 tokenId, bytes memory _data) 
       private returns (bool) {
        if (!to.isContract()) { 
            return true;
        }
            try IERC721Receiver(to).onERC721Received(msg.sender, from, tokenId, _data) 
            returns (bytes4 retval) {
                return retval == IERC721Receiver.onERC721Received.selector;
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert("ERC721: transfer to non ERC721Receiver implementer");
                } else {
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
        } 
    }
}