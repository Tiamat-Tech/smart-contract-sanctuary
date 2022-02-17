// SPDX-License-Identifier: MIT
// @unsupported: ovm
pragma solidity >0.5.0 <0.8.0;
pragma experimental ABIEncoderV2;

/* Interface Imports */
import { iNVM_L1CrossDomainMessenger } from
    "../../../iNVM/bridge/messaging/iNVM_L1CrossDomainMessenger.sol";
import { iNVM_L1MultiMessageRelayer } from
    "../../../iNVM/bridge/messaging/iNVM_L1MultiMessageRelayer.sol";

/* Library Imports */
import { Lib_AddressResolver } from "../../../libraries/resolver/Lib_AddressResolver.sol";

/**
 * @title NVM_L1MultiMessageRelayer
 * @dev The L1 Multi-Message Relayer contract is a gas efficiency optimization which enables the
 * relayer to submit multiple messages in a single transaction to be relayed by the L1 Cross Domain
 * Message Sender.
 *
 * Compiler used: solc
 * Runtime target: EVM
 */
contract NVM_L1MultiMessageRelayer is iNVM_L1MultiMessageRelayer, Lib_AddressResolver {

    /***************
     * Constructor *
     ***************/

    /**
     * @param _libAddressManager Address of the Address Manager.
     */
    constructor(
        address _libAddressManager
    )
        Lib_AddressResolver(_libAddressManager)
    {}


    /**********************
     * Function Modifiers *
     **********************/

    modifier onlyBatchRelayer() {
        require(
            msg.sender == resolve("NVM_L2BatchMessageRelayer"),
            // solhint-disable-next-line max-line-length
            "NVM_L1MultiMessageRelayer: Function can only be called by the NVM_L2BatchMessageRelayer"
        );
        _;
    }


    /********************
     * Public Functions *
     ********************/

    /**
     * @notice Forwards multiple cross domain messages to the L1 Cross Domain Messenger for relaying
     * @param _messages An array of L2 to L1 messages
     */
    function batchRelayMessages(
        L2ToL1Message[] calldata _messages
    )
        override
        external
        onlyBatchRelayer
    {
        iNVM_L1CrossDomainMessenger messenger = iNVM_L1CrossDomainMessenger(
            resolve("Proxy__NVM_L1CrossDomainMessenger")
        );

        for (uint256 i = 0; i < _messages.length; i++) {
            L2ToL1Message memory message = _messages[i];
            messenger.relayMessage(
                message.target,
                message.sender,
                message.message,
                message.messageNonce,
                message.ovmTransaction,
                message.receipt,
                message.proof
            );
        }
    }
}