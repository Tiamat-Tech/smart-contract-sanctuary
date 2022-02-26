// PDX-License-Identifier: UNLICENSED"

pragma solidity >=0.4.22 <=0.8.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "./UpdateMsgVerifier.sol";
import "./DeviceRegister.sol";

contract Radoa is DeviceRegister, UpdateMsgVerifier {
    using SafeMath for uint256;
    using SafeMath for uint32;
    using SafeMath for uint64;

    event InitRadoa(address indexed owner);
    event InitDevice(bytes32 indexed deviceId, uint64 indexed timestamp, uint32 indexed index, bytes publicKey);
    event AddUpdateMsg(bytes32 indexed deviceId, uint32 indexed index, bytes32 indexed stateHash);
    event ConfirmUpdateMsg(bytes32 indexed deviceId, uint32 indexed index);

    mapping (bytes32=>bool) isInitializedOfDeviceId;
    mapping (bytes32=>UpdateMsgVerifier.UpdateMsg) lastMsgOfDeviceId;
    mapping (bytes32=>mapping(bytes4=>bytes32)) addedMsgHashAtIndexOfDeviceId;
    mapping (bytes32=>mapping(bytes4=>bytes32[MAX_VDF_NODE_NUMBER])) authorizedRootsAtIndexOfDeviceId;
    mapping (bytes32=>uint32) lastConfirmedIndexOfDeviceId;
    mapping (bytes32=>mapping(bytes32=>bool)) isConfirmedRootForMsgHash;
    address owner;
    bool isDev = false;

    modifier onlyInitializedDevice(bytes32 _deviceId) {
        require(_deviceId!=bytes32(0), "invalid device id");
        require(isInitializedOfDeviceId[_deviceId],"not initialized device");
        _;
    }

    constructor(address _timer, bool _isDev) UpdateMsgVerifier(_timer) public {
        owner = msg.sender;
        isDev = _isDev;
        emit InitRadoa(owner);
    }

    function getLastIndex(bytes32 _deviceId) public view onlyInitializedDevice(_deviceId) returns (bytes4) {
        return lastMsgOfDeviceId[_deviceId].index;
    }

    function getStateHash(bytes32 _deviceId) public view onlyInitializedDevice(_deviceId) returns (bytes32) {
        return lastMsgOfDeviceId[_deviceId].stateHash;
    }
    
    function getTimestamp(bytes32 _deviceId) public view onlyInitializedDevice(_deviceId) returns (bytes8) {
        return lastMsgOfDeviceId[_deviceId].timestamp;
    }

    function isHealthDeviceNow(bytes32 _deviceId) public view returns (bool) {
        return isHealthDeviceAtIndex(_deviceId, timer.getLastClosedIndex());
    }

    function isHealthDeviceAtIndex(bytes32 _deviceId, uint64 _index) public view onlyInitializedDevice(_deviceId) returns (bool) {
        uint64 confirmedIndex = lastConfirmedIndexOfDeviceId[_deviceId];
        return confirmedIndex >= _index;
    }

    function getLastClosedIndex() public view returns (uint32) {
        return timer.getLastClosedIndex();
    }

    function getCloseTime(bytes4 _index) public view returns (uint64) {
        return timer.getCloseTime(_index);
    }

    function isOpenedIndex(uint32 _index) public view returns (bool) {
        return timer.isOpenedIndex(_index);
    }

    function computeOpenTime(uint32 _index) public view returns (uint64) {
        return timer.computeOpenTime(_index);
    }

    function computeOpenedIndex(uint64 _timestamp) public view returns (uint32) {
        return timer.computeOpenedIndex(_timestamp);
    }

    function computetLastOpenedIndex() public view returns (uint32) {
        return timer.computetLastOpenedIndex();
    }

    function initDevice(bytes8 _timestamp) public {
        bytes32 deviceId  = getDeviceIdOfAddress(msg.sender);
        require(deviceId!=bytes32(0), "invalid device id");
        isInitializedOfDeviceId[deviceId] = true;
        lastMsgOfDeviceId[deviceId].deviceId = deviceId;
        lastMsgOfDeviceId[deviceId].previousHash = bytes32(0);
        lastMsgOfDeviceId[deviceId].stateHash = bytes32(0);
        lastMsgOfDeviceId[deviceId].index = bytes4(timer.computeOpenedIndex(uint64(_timestamp)));
        lastMsgOfDeviceId[deviceId].timestamp = _timestamp;
        lastMsgOfDeviceId[deviceId].publicKey = getInitKeyOfDeviceId(deviceId);
        emit InitDevice(deviceId, uint64(_timestamp),uint32(lastMsgOfDeviceId[deviceId].index), lastMsgOfDeviceId[deviceId].publicKey);
    }

    function addUpdateMsg(
        bytes32 _newStateHash, 
        bytes8 _newTimestamp, 
        bytes memory _newPublicKey, 
        bytes memory _signature,
        bytes32[MAX_VDF_NODE_NUMBER] calldata _authorizedRoots
    ) public onlyInitializedDevice(getDeviceIdOfAddress(msg.sender)) {
        bytes32 deviceId = getDeviceIdOfAddress(msg.sender);
        require(deviceId!=bytes32(0),"code 0 in registerDevice");
        require(isInitializedOfDeviceId[deviceId],"code 1 in registerDevice");
        //require(isHealthDeviceNow(deviceId),"code 2 in addUpdateMsg");
        UpdateMsgVerifier.UpdateMsg memory lastMsg = lastMsgOfDeviceId[deviceId];
        bytes4 oldIndex = lastMsg.index;
        uint32 newIndex = uint32(uint32(oldIndex).add(1));
        uint limitTime = uint256(timer.computeOpenTime(uint32(newIndex))).add(timer.submissionPeriod());
        require(block.timestamp<=limitTime,"code 2 in addUpdateMsg");
        UpdateMsg memory newMsg;
        newMsg.deviceId = lastMsg.deviceId;
        newMsg.previousHash = hasher(lastMsg);
        newMsg.index = bytes4(newIndex);
        newMsg.stateHash = _newStateHash;
        newMsg.timestamp = _newTimestamp;
        newMsg.publicKey = _newPublicKey;
        newMsg.authorizedRoots = _authorizedRoots;
        Signature memory updateSignature = SignatureVerifier.decodeSignature(_signature);
        attestMsgValidity(lastMsg, newMsg, updateSignature);
        lastMsgOfDeviceId[deviceId].deviceId = newMsg.deviceId;
        lastMsgOfDeviceId[deviceId].previousHash = newMsg.previousHash;
        lastMsgOfDeviceId[deviceId].index = newMsg.index;
        lastMsgOfDeviceId[deviceId].stateHash = newMsg.stateHash;
        lastMsgOfDeviceId[deviceId].timestamp = newMsg.timestamp;
        lastMsgOfDeviceId[deviceId].publicKey = newMsg.publicKey;
        lastMsgOfDeviceId[deviceId].authorizedRoots = newMsg.authorizedRoots;
        addedMsgHashAtIndexOfDeviceId[deviceId][newMsg.index] = hasher(newMsg);
        authorizedRootsAtIndexOfDeviceId[deviceId][oldIndex] = _authorizedRoots;
        emit AddUpdateMsg(deviceId, newIndex, _newStateHash);
    }

    function confirmUpdateMsg(
        bytes32 _deviceId,
        bytes32[][MAX_VDF_NODE_NUMBER] memory _proofArray
    ) public onlyInitializedDevice(_deviceId) {
        bytes32 deviceId = getDeviceIdOfAddress(msg.sender);
        require(deviceId!=bytes32(0),"code 0 in confirmUpdateMsg");
        require(isInitializedOfDeviceId[deviceId],"code 1 in confirmUpdateMsg");
        //require(isHealthDeviceNow(deviceId),"code 2 in addUpdateMsg");
        uint32 lastIndex = uint32(lastConfirmedIndexOfDeviceId[deviceId]);
        uint32 confirmedIndex = uint32(uint256(lastIndex).add(1));
        bytes32 msgHash = addedMsgHashAtIndexOfDeviceId[deviceId][bytes4(confirmedIndex)];
        require(msgHash!=bytes32(0),"code 2 in confirmUpdateMsg");
        bytes32 previousHash = addedMsgHashAtIndexOfDeviceId[deviceId][bytes4(lastIndex)];
        bytes32[MAX_VDF_NODE_NUMBER] memory authorizedRoots;
        for(uint32 i=0;i<MAX_VDF_NODE_NUMBER;i++){
            authorizedRoots[i] = authorizedRootsAtIndexOfDeviceId[deviceId][bytes4(confirmedIndex)][i];
        }
        bytes memory confirmedRootBytes = attestMsgAvailability(msgHash, previousHash, confirmedIndex, authorizedRoots, _proofArray);
        bytes32[] memory confirmedRoots = abi.decode(confirmedRootBytes,(bytes32[]));
        lastConfirmedIndexOfDeviceId[deviceId] = confirmedIndex;
        for(uint32 i=0;i<confirmedRoots.length;i++){
            isConfirmedRootForMsgHash[msgHash][confirmedRoots[i]] = true;
        }
        emit ConfirmUpdateMsg(_deviceId, confirmedIndex);
    }

    function closeAttestation() public {
        timer.closeAttestation();
    }

    function resetDevice(
        bytes32 _deviceId
    ) public {
        require(isDev==true, "resetDevice is only enabled in the dev mode.");
        require(deviceIdOfAddress[msg.sender]==_deviceId, "It should be called by the device.");
        deviceIdOfAddress[msg.sender] = bytes32(0);
        authorizerOfDeviceId[_deviceId] = address(0);
        initKeyOfDeviceId[_deviceId] = abi.encode();
        isInitializedOfDeviceId[_deviceId] = false;
        bytes4 lastAddedIndex = lastMsgOfDeviceId[_deviceId].index;
        lastMsgOfDeviceId[_deviceId].deviceId = bytes32(0);
        lastMsgOfDeviceId[_deviceId].previousHash = bytes32(0);
        lastMsgOfDeviceId[_deviceId].stateHash = bytes32(0);
        lastMsgOfDeviceId[_deviceId].index = bytes4(0);
        lastMsgOfDeviceId[_deviceId].timestamp = bytes8(0);
        lastMsgOfDeviceId[_deviceId].publicKey = abi.encode();
        delete lastMsgOfDeviceId[_deviceId].authorizedRoots;
        //delete authorizedRootsAtIndexOfDeviceId[_deviceId];
        lastConfirmedIndexOfDeviceId[_deviceId] = 0;
        /*for(uint32 i=0;i<uint32(lastAddedIndex);i++) {
            bytes32 msgHash = addedMsgHashAtIndexOfDeviceId[_deviceId][bytes4(i)];
            for(uint32 j=0;j<MAX_VDF_NODE_NUMBER;j++) {
                bytes32 authorizedRoot = authorizedRootsAtIndexOfDeviceId[_deviceId][bytes4(i)][j];
                isConfirmedRootForMsgHash[msgHash][authorizedRoot] = false;
            }
        }*/
    }
}