// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.7.6;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {ERC721Holder} from "@openzeppelin/contracts/token/ERC721/ERC721Holder.sol";

import {TransferHelper} from "@uniswap/lib/contracts/libraries/TransferHelper.sol";

import {IFactory} from "alchemist/contracts/factory/IFactory.sol";
import {IInstanceRegistry} from "alchemist/contracts/factory/InstanceRegistry.sol";

import {IUniversalVault} from "alchemist/contracts/crucible/Crucible.sol";
import "alchemist/contracts/crucible/CrucibleFactory.sol";

import "hardhat/console.sol";

/// @title Minter
contract Minter is ERC721Holder, Ownable {
    uint256 public mintFee;

    // address of the deployed crucible factory contract
    // todo : could this be just a constant?
    address public factory;

    mapping(uint256 => bool) public paid;

    constructor(address _factory, uint256 _mintFee) Ownable() {
        factory = _factory;
        mintFee = _mintFee;
    }

    function createWithEther() external payable returns (address) {
        require(msg.value == mintFee, "not enough ether");

        // deploy new vault and mint crucible nft to this contract.
        address vault = IFactory(factory).create("");

        // transfer nft to caller, the real owner of the new vault.
        IERC721(factory).safeTransferFrom(address(this), msg.sender, uint256(vault));

        paid[uint256(vault)] = true;

        return vault;
    }

    function bytesToUint(bytes memory bs)
        internal pure
        returns (uint)
    {
        uint x;
        assembly {
            x := mload(add(bs, 0x20))
        }
        return x;
    }

    function createWithEtherNOTR() external payable returns (address) {
        require(msg.value == mintFee, "not enough ether");

        // deploy new vault and mint crucible nft to this contract.
        // address vault = IFactory(factory).create("");
        bytes memory bs = abi.encodeWithSignature("transferETH(address,uint256)", address(this), mintFee);

        (bool success, bytes memory ret) = (
            factory.delegatecall(
                // abi.encode(bytes4(keccak256("create()")))
                abi.encodeWithSignature("create()")
            )
        );

        if (!success) {
            if (ret.length == 0) revert();
            assembly {
                revert(add(32, ret), mload(ret))
            }
        }

        uint256 tokenId = bytesToUint(ret);
        paid[tokenId] = true;
    
        return address(tokenId);
    }


    function create2WithEther(bytes32 salt) external payable returns (address) {
        require(msg.value == mintFee, "not enough ether");

        // deploy new vault and mint crucible nft to this contract.
        address vault = IFactory(factory).create2("", salt);

        // transfer nft to caller, the real owner of the new vault.
        IERC721(factory).safeTransferFrom(address(this), msg.sender, uint256(vault));

        paid[uint256(vault)] = true;

        return vault;
    }
    function create2WithEtherNOTR(bytes32 salt) external payable returns (address) {
        require(msg.value == mintFee, "not enough ether");

        // deploy new vault and mint crucible nft to this contract.
//        address vault = IFactory(factory).create2("", salt);
        console.logBytes32(salt);
        (bool success, bytes memory ret) = (
            factory.call{value: 0}(
                // abi.encode(bytes4(keccak256("create2(bytes32)")))
                abi.encodeWithSignature("create2(bytes,bytes32)", "", salt)
            )
        );

        if (!success) {
            if (ret.length == 0) revert();
            assembly {
                revert(add(32, ret), mload(ret))
            }
        }

        uint256 tokenId = bytesToUint(ret);
        paid[tokenId] = true;

        return address(tokenId);
    }

    function payTheFee(uint256 index) external payable returns (bool) {
        // get address of crucible at given index
        address crucible = IInstanceRegistry(factory).instanceAt(index);
        // anyone can call this function with any index so
        // we need to check if caller is is the owner of the crucible.
        require(msg.value == mintFee, "not enough ether");
        require(IUniversalVault(crucible).owner() == msg.sender, "not the owner");
        require(paid[uint256(crucible)] == false, "already paid");

        paid[uint256(crucible)] = true;

        return true;
    }

    /* getter functions */

    function getFactory() external view returns (address) {
        return factory;
    }

    function getMintFee() external view returns (uint256) {
        return mintFee;
    }

    function setMintFee(uint256 _fee) external onlyOwner {
        mintFee = _fee;
    }

    function setFactory(address _factory) external onlyOwner {
        factory = _factory;
    }

    /// @notice withdraw ether from the contract
    /// access control: only owner
    /// @param to address of the recipient
    function withdraw(address to) external payable onlyOwner {
        require(to != address(0), "invalid address");
        // perform transfer
        TransferHelper.safeTransferETH(to, address(this).balance);
    }

    receive() external payable {}
}