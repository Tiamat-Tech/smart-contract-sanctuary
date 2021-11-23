// SPDX-License-Identifier: Apache-2.0
// Copyright 2021 Enjinstarter
pragma solidity ^0.7.6;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/drafts/EIP712.sol";
import "./interfaces/ILaunchpadWhitelistFactory.sol";

/**
 * @title LaunchpadWhitelistFactory
 * @author Enjinstarter
 */
contract LaunchpadWhitelistFactory is EIP712, ILaunchpadWhitelistFactory {
    using Address for address;
    using Clones for address;
    using ECDSA for bytes32;

    address private _governanceAccount;
    address private _adminAccount;
    address private _signerAccount;

    constructor(string memory name, string memory version)
        EIP712(name, version)
    {
        _governanceAccount = msg.sender;
        _adminAccount = msg.sender;
        _signerAccount = msg.sender;
    }

    modifier onlyBy(address account) {
        require(
            msg.sender == account,
            "LaunchpadWhitelistFactory: sender unauthorized"
        );
        _;
    }

    function deployWithTypedSignature(
        address implementation,
        string memory uuid,
        string memory name,
        bytes memory signature
    ) external override onlyBy(_adminAccount) {
        _deploy(implementation, uuid, name, signature);
    }

    function setGovernanceAccount(address account)
        external
        onlyBy(_governanceAccount)
    {
        require(
            account != address(0),
            "LaunchpadWhitelistFactory: zero account"
        );

        _governanceAccount = account;
    }

    function setAdminAccount(address account)
        external
        onlyBy(_governanceAccount)
    {
        require(
            account != address(0),
            "LaunchpadWhitelistFactory: zero account"
        );

        _adminAccount = account;
    }

    function setSignerAccount(address account)
        external
        onlyBy(_governanceAccount)
    {
        require(
            account != address(0),
            "LaunchpadWhitelistFactory: zero account"
        );

        _signerAccount = account;
    }

    function verifyTypedSignature(
        address implementation,
        string memory uuid,
        string memory name,
        bytes memory signature
    ) public view override returns (bool isValid) {
        bytes32 digest = _hashTypedDataV4(
            keccak256(
                abi.encode(
                    keccak256(
                        "LaunchpadWhitelist(address implementation,string uuid,string name)"
                    ),
                    implementation,
                    keccak256(bytes(uuid)),
                    keccak256(bytes(name))
                )
            )
        );
        address recovered = digest.recover(signature);

        isValid = (_signerAccount == recovered);
    }

    function governanceAccount()
        external
        view
        returns (address goveranceAccount_)
    {
        goveranceAccount_ = _governanceAccount;
    }

    function adminAccount() external view returns (address adminAccount_) {
        adminAccount_ = _adminAccount;
    }

    function signerAccount() external view returns (address signerAccount_) {
        signerAccount_ = _signerAccount;
    }

    function _deploy(
        address implementation,
        string memory uuid,
        string memory name,
        bytes memory signature
    ) internal virtual {
        require(
            verifyTypedSignature(implementation, uuid, name, signature),
            "LaunchpadWhitelistFactory: invalid signature"
        );

        bytes memory saltdata = _encodeSaltData(_signerAccount, uuid, name);
        bytes32 salt = keccak256(abi.encodePacked(saltdata, _signerAccount));
        address deployedContract = implementation.cloneDeterministic(salt);

        bytes memory initializeData = _encodeInitializeData();
        deployedContract.functionCall(initializeData);

        emit Deployed(
            implementation,
            deployedContract,
            uuid,
            name,
            _signerAccount
        );
    }

    function _encodeSaltData(
        address signer,
        string memory uuid,
        string memory name
    ) internal pure virtual returns (bytes memory encodedData) {
        encodedData = abi.encodeWithSignature(
            "salt(address,string,string)",
            signer,
            uuid,
            name
        );
    }

    function _encodeInitializeData()
        internal
        pure
        virtual
        returns (bytes memory encodedData)
    {
        encodedData = abi.encodeWithSignature("initialize()");
    }
}