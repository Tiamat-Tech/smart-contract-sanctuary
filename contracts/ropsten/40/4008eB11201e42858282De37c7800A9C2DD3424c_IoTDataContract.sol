// SPDX-License-Identifier: MIT
pragma solidity >=0.5.16 <0.9.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract IoTDataContract is AccessControl, Ownable {
    bytes32 private constant ALLOWED_IOT_DEVICE =
        keccak256("ALLOWED_IOT_DEVICE");

    struct SensorData {
        string filehash;
        string deviceId;
    }

    uint256 private processedCounter;

    // map sensor data to an id
    mapping(uint256 => SensorData) sensorStore;

    //store registered sensors ddresses in mapping
    mapping(address => bool) private trustedSensors;

    modifier allowedDevice(address allowedAddress) {
        require(
            hasRole(ALLOWED_IOT_DEVICE, allowedAddress),
            "Caller is not authorised to invoke the function "
        );
        _;
    }

    event deviceRegUnregEvent(address indexed _from, string _message);
    event submittedFileEvent(address indexed _from, string _message);

    constructor() {
        processedCounter = 0;

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(DEFAULT_ADMIN_ROLE, address(this));

        _setRoleAdmin(DEFAULT_ADMIN_ROLE, DEFAULT_ADMIN_ROLE);
        _setRoleAdmin(ALLOWED_IOT_DEVICE, DEFAULT_ADMIN_ROLE);
    }

    function submitData(
        string memory _filehash,
        string memory _deviceId,
        address _fromAddress
    ) public allowedDevice(_fromAddress) {
        if (devicePresent(_fromAddress)) {
            // prepare the key
            uint256 _key = getProcessedCounter();

            // persist the sensor data
            SensorData storage sensorReadings = sensorStore[_key];
            sensorReadings.filehash = _filehash;
            sensorReadings.deviceId = _deviceId;

            // increment the  counter
            updateProcessedCounter();

            emit submittedFileEvent(
                msg.sender,
                "[Success] Filehash for sensor successfully added to the chain"
            );
        } else {
            emit submittedFileEvent(
                msg.sender,
                "[Info] The sensor is not registered, returning without updating the chain"
            );
        }
    }

    function updateProcessedCounter() private {
        processedCounter++;
    }

    function getProcessedCounter() public view returns (uint256) {
        return processedCounter;
    }

    // function to check if device is registered
    function devicePresent(address validateAddress)
        private
        view
        returns (bool)
    {
        return trustedSensors[validateAddress];
    }

    // register IoT device
    function registerSensor(address registerAddress) public onlyOwner {
        if (devicePresent(registerAddress)) {
            emit deviceRegUnregEvent(
                registerAddress,
                "[Info] The sensor is already registered"
            );
        } else {
            trustedSensors[registerAddress] = true;
            super.grantRole(ALLOWED_IOT_DEVICE, registerAddress);
            emit deviceRegUnregEvent(
                registerAddress,
                "[Success] The sensor has been registered successfully"
            );
        }
    }

    // remove IoT device
    function removeSensor(address addressToRemove) public onlyOwner {
        if (!devicePresent(addressToRemove)) {
            emit deviceRegUnregEvent(
                addressToRemove,
                "[Warn] Unable to remove -> The sensor is not registered"
            );
        } else {
            trustedSensors[addressToRemove] = false;
            super.revokeRole(ALLOWED_IOT_DEVICE, addressToRemove);
            emit deviceRegUnregEvent(
                addressToRemove,
                "[Success] The sensor has been removed successfully"
            );
        }
    }
}