// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./ERC721Mintable.sol";
import "./layer0/interfaces/ILayerZeroReceiver.sol";
import "./layer0/interfaces/ILayerZeroEndpoint.sol";
import "./SystemContext.sol";


contract LayerZeroBridge is ILayerZeroReceiver {
    using Address for address;

    // keep track of how many messages have been received from other chains
    uint256 public messageCounter;
    // required: the LayerZero endpoint which is passed in the constructor
    ILayerZeroEndpoint public endpoint;

    SystemContext public systemContext;
    uint256 public apiVersion;

    // required: the LayerZero endpoint
    constructor(ILayerZeroEndpoint endpoint_, SystemContext systemContext_) {
        endpoint = endpoint_;
        apiVersion = 0;
        systemContext = SystemContext(systemContext_);
    }

    modifier onlyRole(bytes32 role_) {
        systemContext.getAccessControlList().checkRole(role_, msg.sender);
        _;
    }

    function setEndpoint(address endpoint_) external onlyRole(systemContext.getAccessControlList().BRIDGE_DEFAULT_ADMIN_ROLE()) {
        endpoint = ILayerZeroEndpoint(endpoint_);
    }

    enum Operation {
        CALL,
        DEPLOY
    }

    struct Data {
        Operation operation;
        uint256 apiVersion;
        bytes rawData;
    }

    struct CallData {
        address destinationContract;
        bytes packedData;
    }

    struct DeployData {
        bytes bytecode;
        bytes ctorParams;
    }

    event ReceiveEvent(uint16 chainId, Operation operation, uint64 nonce);
    event CallSuccess(address calledContract, bytes returnData);
    event CallFailed(address calledContract);
    event ContractDeployed(address newContract);
    event ContractNotDeployed();
    event UndefinedCall(Operation operation, uint256 apiVersion, bytes rawData);

    function handleCall(CallData memory callData) internal returns (bytes memory) {
        address target = callData.destinationContract;
        (bool success, bytes memory returnData) = target.call(callData.packedData);
        if (success) {
            emit CallSuccess(target, returnData);
        } else {
            emit CallFailed(target);
        }
        return returnData;
    }

    /**
     * @dev Returns True if provided address is a contract
     * @param account Prospective contract address
     * @return True if there is a contract behind the provided address
     */
    function isContract(address account) private view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }


    function handleDeploy(DeployData memory deployData) internal returns (address) {
        bytes memory creationBytecode = abi.encodePacked(deployData.bytecode, deployData.ctorParams);

        address addr;
        assembly {
            addr := create(0, add(creationBytecode, 0x20), mload(creationBytecode))
        }

        if (isContract(addr)) {
            emit ContractDeployed(addr);
        } else {
            emit ContractNotDeployed();
        }

        return addr;
    }

    function handleUndefined(Data memory data) internal {
        // some handler that error happened
        emit UndefinedCall(data.operation, data.apiVersion, data.rawData);
    }

    function packedBytesToAddr(bytes calldata _b) public pure returns (address) {
        address addr;
        assembly {
            let ptr := mload(0x40)
            calldatacopy(ptr, sub(_b.offset, 2 ), add(_b.length, 2))
            addr := mload(sub(ptr,10))
        }
        return addr;
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

        if (data.operation == Operation.CALL) {
            CallData memory callData = abi.decode(data.rawData, (CallData));
            handleCall(callData);
        } else if (data.operation == Operation.DEPLOY) {
            DeployData memory deployData = abi.decode(data.rawData, (DeployData));
            handleDeploy(deployData);
        } else {
            handleUndefined(data);
        }
        emit ReceiveEvent(_srcChainId, data.operation, _nonce);
    }

    function mintOnSecondChain(
        uint16 chainId_,
        bytes calldata bridge_,
        bytes calldata contractAddress_,
        address refundAddress_,
        address owner_,
        uint256 mintId_
    ) public payable onlyRole(systemContext.getAccessControlList().BRIDGE_CALLER_ROLE()) {
        address destContract = packedBytesToAddr(contractAddress_);
        bytes memory buffer = abi.encode(
            Data({
                operation: Operation.CALL,
                apiVersion: apiVersion,
                rawData: abi.encode(CallData({
                    destinationContract: destContract,
                    packedData: abi.encodeWithSignature("mintTo(address,uint256)", owner_, mintId_)
                }))
            })
        );

        endpoint.send{value: msg.value}(
            chainId_,
            bridge_,
            buffer,
            payable(refundAddress_),
            address(this),
            bytes("")
        );
    }

    function burnOnSecondChain(
        uint16 chainId_,
        bytes calldata bridge_,
        bytes calldata contractAddress_,
        address refundAddress_,
        uint256 burnId_
    ) public payable onlyRole(systemContext.getAccessControlList().BRIDGE_CALLER_ROLE()) {
        address destContract = packedBytesToAddr(contractAddress_);
        bytes memory buffer = abi.encode(
            Data({
                operation: Operation.CALL,
                apiVersion: apiVersion,
                rawData: abi.encode(CallData({
                    destinationContract: destContract,
                    packedData: abi.encodeWithSignature("burn(uint256)", burnId_)
                }))
            })
        );

        endpoint.send{value: msg.value}(
            chainId_,
            bridge_,
            buffer,
            payable(refundAddress_),
            address(this),
            bytes("")
        );
    }

    function callOnSecondChain(
        uint16 chainId_,
        bytes calldata dest_contract_,
        address destinationContract_,
        address refundAddress_,
        bytes calldata calldata_
    ) public payable onlyRole(systemContext.getAccessControlList().BRIDGE_CALLER_ROLE()) {
        bytes memory buffer = abi.encode(
            Data({
                operation: Operation.CALL,
                apiVersion: apiVersion,
                rawData: abi.encode(CallData({destinationContract: destinationContract_, packedData: calldata_}))
            })
        );

        endpoint.send{value: msg.value}(
            chainId_,
            dest_contract_,
            buffer,
            payable(refundAddress_),
            address(this),
            bytes("")
        );
    }

    function deployMultipleContracts(
        uint16[] calldata chainIds_,
        bytes calldata dest_contract_,
        address refundAddress_,
        bytes calldata bytecode_,
        bytes calldata params_
    ) public payable onlyRole(systemContext.getAccessControlList().BRIDGE_CALLER_ROLE()) {
        for (uint256 i = 0; i < chainIds_.length; i++) {
            bytes memory buffer = abi.encode(
                Data({
                    operation: Operation.DEPLOY,
                    apiVersion: apiVersion,
                    rawData: abi.encode(DeployData({bytecode: bytecode_, ctorParams: params_}))
                })
            );

            endpoint.send{value: msg.value / chainIds_.length}(
                chainIds_[i],
                dest_contract_,
                buffer,
                payable(refundAddress_),
                address(this),
                bytes("")
            );
        }
    }
}