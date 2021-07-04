// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


/**
 * @title DeIDManager
 * @version 1.0.0
 * @author Francesco Sullo <[email protected]>
 * @dev Manages identities
 */

// import "hardhat/console.sol";

import "./ClaimerCaller.sol";
import "./StoreCaller.sol";
import "./interfaces/IDeIDManager.sol";

interface ITXValidatorMinimal {

    function getChainId() external view returns (uint256);

    function isValidForGroupId(uint groupId_, uint timestamp_) external view returns (bool);

    function isSignedByValidator(uint groupId_, bytes32 hash_, bytes memory signature_) external view returns (address);
}

contract DeIDManager is ClaimerCaller, StoreCaller, IDeIDManager {

    ITXValidatorMinimal public validator;
    uint private _currentTweedentityId;

    function _getNextTweedentityId()
    private view
    returns (uint)
    {
        return _currentTweedentityId + 1;
    }

    function _incrementTokenTypeId()
    private
    {
        _currentTweedentityId++;
    }

    modifier onlySignedByValidator(
        uint appId_,
        uint id_,
        uint timestamp_,
        bytes memory signature_
    ) {
        require(
            validator.isSignedByValidator(
                appId_,
                encodeForSignature(
                    msg.sender,
                    appId_,
                    id_,
                    timestamp_
                ),
                signature_
            ) != address(0),
            "Invalid signature"
        );
        _;
    }

    constructor(
        address store_,
        address claimer_,
        address validator_
    )
    StoreCaller(store_)
    ClaimerCaller(claimer_)
    {
        validator = ITXValidatorMinimal(validator_);
    }

    function setMyIdentity() external override
    onlyIfStoreSet
    {
        store.setAddressAndIdByAppId(0, msg.sender, 0);
    }

    function setIdentity(
        uint appId_,
        uint id_,
        uint timestamp_,
        bytes memory signature_
    ) external override
    onlyIfStoreSet
    onlySignedByValidator(appId_, id_, timestamp_, signature_)
    {
        validator.isValidForGroupId(appId_, timestamp_);
        store.setAddressAndIdByAppId(appId_, msg.sender, id_);
    }


    function setMultipleIdentities(
        uint[] memory appIds_,
        uint[] memory ids_,
        uint timestamp_,
        bytes[] memory signatures_
    ) external override
    onlyIfStoreSet
    {
        for (uint i = 0; i < appIds_.length; i++) {
            if (appIds_[i] > 0) {
                validator.isValidForGroupId(appIds_[i], timestamp_);
                require(
                    validator.isSignedByValidator(
                        appIds_[i],
                        encodeForSignature(
                            msg.sender,
                            appIds_[i],
                            ids_[i],
                            timestamp_
                        ),
                        signatures_[i]
                    ) != address(0),
                    "Invalid signature"
                );
            }
        }
        require(
            appIds_.length == ids_.length,
            "AppIds and ids are inconsistent"
        );
        for (uint i = 0; i < appIds_.length; i++) {
            store.setAddressAndIdByAppId(appIds_[i], msg.sender, ids_[i]);
        }
    }


    function updateIdentity(
        uint appId_,
        address newAddress_
    ) external override
    onlyIfStoreSet
    {
        store.updateAddressByAppId(appId_, msg.sender, newAddress_);
    }


    function claimIdentity(
        uint appId_,
        uint id_,
        uint timestamp_,
        bytes memory signature_
    ) external override
    onlyIfClaimerSet
    onlySignedByValidator(appId_, id_, timestamp_, signature_)
    {
        validator.isValidForGroupId(appId_, timestamp_);
        claimer.setClaim(appId_, id_, msg.sender);
    }


    function updateClaimedIdentity(
        uint appId_,
        uint id_,
        uint timestamp_,
        bytes memory signature_
    ) external override
    onlyIfClaimerSet
    onlySignedByValidator(appId_, id_, timestamp_, signature_)
    {
        validator.isValidForGroupId(appId_, timestamp_);
        claimer.setClaimedIdentity(appId_, id_, msg.sender);
    }

    function encodeForSignature(
        address address_,
        uint groupId_,
        uint id_,
        uint timestamp_
    ) public view override
    returns (bytes32)
    {
        return keccak256(
            abi.encodePacked(
                "\x19\x00",
                address_,
                validator.getChainId(),
                groupId_,
                id_,
                timestamp_
            )
        );
    }

}