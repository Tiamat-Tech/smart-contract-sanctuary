// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./ERC721Mintable.sol";
import "./layer0/interfaces/ILayerZeroReceiver.sol";
import "./layer0/interfaces/ILayerZeroEndpoint.sol";

// Findings https://github.com/pouladzade/Seriality

import "hardhat/console.sol";

contract LayerZeroBridge is ILayerZeroReceiver, AccessControl {
    using Address for address;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    bytes32 public constant CALLER_ROLE = keccak256("CALLER_ROLE");

    // keep track of how many messages have been received from other chains
    uint256 public messageCounter;
    // required: the LayerZero endpoint which is passed in the constructor
    ILayerZeroEndpoint public endpoint;
    ERC721Mintable public mintableToken;
    uint256 public apiVersion;

    // required: the LayerZero endpoint
    constructor(address _endpoint, address _mintableToken) {
        endpoint = ILayerZeroEndpoint(_endpoint);
        mintableToken = ERC721Mintable(_mintableToken);
        apiVersion = 0;

        _setupRole(MINTER_ROLE, msg.sender);
        _setupRole(BURNER_ROLE, msg.sender);
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    enum Operation {
        MINT,
        BURN,
        CALL
    }

    struct Data {
        Operation operation;
        uint256 apiVersion;
        bytes rawData;
    }

    struct MintData {
        address to;
        uint256 mintId;
    }

    struct BurnData {
        uint256 burnId;
    }

    struct EditData {
        uint256 editId;
    }

    struct CallData {
        address destinationContract; // TODO not used yet.
        bytes packedData;
    }

    event ReceiveEvent(uint16 chainId, Operation operation, uint64 nonce);

    function handleMint(MintData memory mintData) internal {
        mintableToken.mintTo(mintData.to, mintData.mintId);
    }

    function handleBurn(BurnData memory burnData) internal {
        mintableToken.burn(burnData.burnId);
    }

    function handleCall(CallData memory callData) internal returns (bytes memory) {
        return address(mintableToken).functionCall(callData.packedData);
    }

    function handleUndefined() internal {
        // some handler that error happened
    }

    // overrides lzReceive function in ILayerZeroReceiver.
    // automatically invoked on the receiving chain after the source chain calls endpoint.send(...)
    function lzReceive(
        uint16 _srcChainId,
        bytes memory _fromAddress,
        uint64 _nonce,
        bytes memory _payload
    ) external override {
        require(msg.sender == address(endpoint));

        messageCounter += 1;

        Data memory data = abi.decode(_payload, (Data));

        if (data.operation == Operation.MINT) {
            MintData memory mintData = abi.decode(data.rawData, (MintData));
            handleMint(mintData);
        } else if (data.operation == Operation.BURN) {
            BurnData memory burnData = abi.decode(data.rawData, (BurnData));
            handleBurn(burnData);
        } else if (data.operation == Operation.CALL) {
            CallData memory callData = abi.decode(data.rawData, (CallData));
            handleCall(callData);
        } else {
            handleUndefined();
        }
        emit ReceiveEvent(_srcChainId, data.operation, _nonce);
    }

    function mintOnSecondChain(
        uint16 chainId_,
        bytes calldata endpoint_,
        uint256 mintId_
    ) public payable onlyRole(MINTER_ROLE) {
        bytes memory buffer = abi.encode(
            Data({
                operation: Operation.MINT,
                apiVersion: apiVersion,
                rawData: abi.encode(MintData({to: msg.sender, mintId: mintId_}))
            })
        );

        endpoint.send{value: msg.value}(
            chainId_,
            endpoint_,
            buffer,
            payable(msg.sender),
            address(this),
            bytes("")
        );
    }

    function burnOnSecondChain(
        uint16 chainId_,
        bytes calldata endpoint_,
        uint256 burnId_
    ) public payable onlyRole(BURNER_ROLE) {
        bytes memory buffer = abi.encode(
            Data({
                operation: Operation.BURN,
                apiVersion: apiVersion,
                rawData: abi.encode(BurnData({burnId: burnId_}))
            })
        );

        endpoint.send{value: msg.value}(
            chainId_,
            endpoint_,
            buffer,
            payable(msg.sender),
            address(this),
            bytes("")
        );
    }

    function callOnSecondChain(
        uint16 chainId_,
        bytes calldata endpoint_,
        address destinationContract_,
        bytes calldata calldata_
    ) public payable onlyRole(CALLER_ROLE) {
        bytes memory buffer = abi.encode(
            Data({
                operation: Operation.CALL,
                apiVersion: apiVersion,
                rawData: abi.encode(CallData({destinationContract: destinationContract_, packedData: calldata_}))
            })
        );

        endpoint.send{value: msg.value}(
            chainId_,
            endpoint_,
            buffer,
            payable(msg.sender),
            address(this),
            bytes("")
        );
    }
}