// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.7.6;
pragma abicoder v2;

import {SafeMath} from "@openzeppelin/contracts/math/SafeMath.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/EnumerableSet.sol";

import {IInstanceRegistry} from "./factory/InstanceRegistry.sol";
import {ProxyFactory} from "./factory/ProxyFactory.sol";

import {IVault} from "./interfaces/IVault.sol";

/// @title MavrikNFTFactory
contract MavrikNFTFactory is Ownable, IInstanceRegistry, ERC721 {
    using SafeMath for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;

    bytes32[] public names;
    mapping(bytes32=>address) public templates;
    mapping(address=>EnumerableSet.AddressSet) private _ownerVaults;
    
    event TemplateAdded(bytes32 indexed name, address indexed template);

    constructor() ERC721("MavrikNFT", "MAVNFT") {
        ERC721._setBaseURI("https://api.mavrik.co/nft/");
    }

    function addTemplate(bytes32 name, address template) public onlyOwner {
        require(templates[name] == address(0), "Template already exists");
        templates[name] = template;
        names.push(name);
        emit TemplateAdded(name, template);
    }

    /* registry functions */

    function isInstance(address instance) external view override returns (bool validity) {
        return ERC721._exists(uint256(instance));
    }

    function instanceCount() external view override returns (uint256 count) {
        return ERC721.totalSupply();
    }

    function instanceAt(uint256 index) external view override returns (address instance) {
        return address(ERC721.tokenByIndex(index));
    }

    /* factory functions */

    function mint(bytes32 name) public returns (address vault) {
        require(templates[name] != address(0), "template not found");
        // create clone and initialize
        vault = ProxyFactory._create(
            templates[name],
            abi.encodeWithSelector(IVault.initialize.selector)
        );

        _create(vault);
    }

    function mintWithSalt(bytes32 name, bytes32 salt) public returns (address vault) {
        require(templates[name] != address(0), "template not found");
        // create clone and initialize
        vault = ProxyFactory._create2(
            templates[name],
            abi.encodeWithSelector(IVault.initialize.selector),
            salt
        );

        _create(vault);
    }

    function _create(address vault) private {
        // mint nft to caller
        uint256 tokenId = uint256(vault);
        ERC721._safeMint(msg.sender, tokenId);
        // add vault to owner's vaults
        _ownerVaults[msg.sender].add(vault);

        // emit event
        emit InstanceAdded(vault);
    }

    /* overrides */
    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal virtual override {
        super._beforeTokenTransfer(from, to, tokenId);
        address vault = address(tokenId);
        _ownerVaults[from].remove(vault);
        _ownerVaults[to].add(vault);
    }

    /* getter functions */

    function nameCount() public view returns(uint256) {
        return names.length;
    }

    function vaultCount(address owner) public view returns(uint256) {
        return _ownerVaults[owner].length();
    }

    function getVaultAt(address owner, uint256 index) public view returns (address) {
        return _ownerVaults[owner].at(index);
    }

    function isOwner(address owner, address vault) public view returns (bool) {
        return _ownerVaults[owner].contains(vault);
    }

    function getVaultAddressOfNFT(uint256 nftId) public pure returns (address) {
        return address(nftId);
    }

    function getNFTIdOfVault(address vault) public pure returns (uint256) {
        return uint256(vault);
    }

}