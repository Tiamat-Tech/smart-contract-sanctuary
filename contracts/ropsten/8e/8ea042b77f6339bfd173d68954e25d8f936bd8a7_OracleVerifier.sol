// SPDX-License-Identifier: GPL-v3-or-later
pragma solidity =0.8.2;

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract OracleVerifier {
    address admin;

    // Set of currently valid signers. Initially, there are no valid signers.
    // The admin may call `setAuthorized` to update this set.
    mapping(address => bool) signers;

    modifier adminOnly {
        require(msg.sender == admin, "OracleVerifier: unauthorized");
        _;
    }

    constructor(address _admin) {
        admin = _admin;
    }

    function transferAdmin(address toWhom) external adminOnly {
        admin = toWhom;
    }

    function setAuthorized(address whom, bool authorized) external adminOnly {
        signers[whom] = authorized;
    }

    // Checks whether `signature` is a valid signature for `message`, written
    // by a signer that is currently authorized. Returns `true` if so or
    // `false` otherwise. Never reverts.
    function verify(bytes memory message, bytes memory signature)
        external
        view
        returns (bool)
    {
        bytes32 rawHash = keccak256(message);
        bytes32 ethMessageHash = ECDSA.toEthSignedMessageHash(rawHash);
        address actual = ECDSA.recover(ethMessageHash, signature);
        return signers[actual];
    }
}