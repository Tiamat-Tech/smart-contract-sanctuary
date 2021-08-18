//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ERC1155Permit.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

import "hardhat/console.sol";

contract GlobalRockstarToken is AccessControl, ERC1155Permit {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    uint256 private immutable _supplyLimitForSingleToken;

    // token id -> supply
    mapping(uint256 => uint256) private _tokensSupply;

    constructor(string memory _baseURI, address _minterAddress) ERC1155Permit(_baseURI) {
        _supplyLimitForSingleToken = 1000;
        _setupRole(MINTER_ROLE, _minterAddress);
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    function mintBatch(
        uint256 id,
        address[] memory addresses,
        uint256[] memory amounts
    ) public {
        require(addresses.length == amounts.length,"ERC1155: addresses and amounts length mismatch");

        for(uint256 i = 0; i < addresses.length; i++) {
            mint(addresses[i], id, amounts[i]);
        }
    }

    function mint(
        address _to,
        uint256 _id,
        uint256 _amount
    ) public {
        require(hasRole(MINTER_ROLE, _msgSender()), "ERC1155: must have minter role to mint");
        uint256 currentTokenSupply = _tokensSupply[_id];
        uint256 newTokenSupply = currentTokenSupply + _amount;
        require(newTokenSupply <= _supplyLimitForSingleToken, "ERC1155: cannot mint more than the set cap");
        _tokensSupply[_id] = newTokenSupply; 

        _mint(_to, _id, _amount, "");
    }

    function transfer(
        address from,
        address to,
        uint256 id,
        uint256 amount
    ) public {
        require(
            from == _msgSender() || isApprovedForAll(from, _msgSender()),
            "ERC1155: caller is not owner nor approved"
        );
        _safeTransferFrom(from, to, id, amount, "");
    }

    // function setPermitForAll(
    //     address spender,
    //     address operator,
    //     bool approved,
    //     uint8 v,
    //     bytes32 r,
    //     bytes32 s
    // ) public override {
    //     super.setPermitForAll(spender, operator, approved, v, r, s);
    // }

    function nonces(address owner) public view override returns (uint256) {
        return super.nonces(owner);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(AccessControl, ERC1155)
        returns (bool)
    {
        return AccessControl.supportsInterface(interfaceId) || ERC1155.supportsInterface(interfaceId);
    }
}