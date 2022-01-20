// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

import "./Permit721.sol";
import "./Permit1155.sol";

contract PermitVault is Permit721, Permit1155 {
    using Address for address payable;

    event TransferETH(address, uint256, address, uint256);

    constructor(string memory name, string memory version) EIP712(name, version) {}

    function transfer721WithFees(
        IERC721 registry,
        uint256 tokenId,
        address to,
        uint256 platformFee,
        uint256 ownerFee,
        address receiverFee,
        uint256 nonce,
        uint256 deadline,
        address relayer,
        bytes memory signature
    ) external payable {
        require(platformFee + ownerFee == msg.value, "The ETH amount sended is wrong");
        this.transfer721WithSign(registry, tokenId, to, platformFee, ownerFee, nonce, deadline, relayer, signature);
        if (ownerFee > 0) {
            payable(receiverFee).sendValue(ownerFee);
        }
        if (platformFee > 0) {
            payable(owner()).sendValue(platformFee);
        }
        if (ownerFee > 0 || platformFee > 0) {
            emit TransferETH(receiverFee, ownerFee, owner(), platformFee);
        }
    }
}