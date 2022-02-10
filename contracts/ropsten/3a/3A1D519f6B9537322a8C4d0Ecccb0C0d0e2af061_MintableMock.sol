// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@imtbl/imx-contracts/contracts/IMintable.sol";
import "@imtbl/imx-contracts/contracts/utils/Minting.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MintableMock is Ownable, IMintable {

    address public imx;
    mapping(uint256 => bytes) public blueprints;
    mapping(uint256 => bytes) public mintingBlobs;

    event AssetMinted(address to, uint256 id, bytes blueprint);
    event MintingBlob(address to, uint256 id, bytes mintingBlob);

    modifier onlyOwnerOrIMX() {
        require(msg.sender == imx || msg.sender == owner(), "Function can only be called by owner or IMX");
        _;
    }

    constructor(address _imx) {
        imx = _imx;
        require(msg.sender != address(0), "Owner must not be empty");
    }

    function mintFor(
        address user,
        uint256 quantity,
        bytes calldata mintingBlob
    ) external override onlyOwnerOrIMX {
        require(quantity == 1, "Mintable: invalid quantity");
        (uint256 id, bytes memory blueprint) = Minting.split(mintingBlob);
        mintingBlobs[id] = mintingBlob;
        emit MintingBlob(user, id, mintingBlob);
        blueprints[id] = blueprint;
        emit AssetMinted(user, id, blueprint);
    }
}