// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

import "@openzeppelin/contracts/access/Ownable.sol";

contract DocStamp is Ownable {

    bool _a ; //false
    uint256 _i; //0
    address _n;// 0x0000000000000000000000000000000000000000 = address(0)

    mapping(bytes32 => address) public records;
    event CertificateIssued(bytes32 indexed record, uint256 indexed timestamp, bool indexed returnValue);

    function issueCertificate(string memory name, string memory details) external onlyOwner {
        require(bytes(name).length > 0);
        require(bytes(details).length > 0);
        bytes32 certificate = keccak256(abi.encodePacked(name,details));
        require(certificate != keccak256(abi.encodePacked("")),"!certificate");
        records[certificate] = msg.sender;
        emit CertificateIssued(certificate, block.timestamp, true);
    }

    function verifyCertificate(string memory name, string memory details, bytes32 certificate) external view returns(bool) {
        bytes32 testCertificate = keccak256(abi.encodePacked(name,details));
        if (testCertificate == certificate && records[certificate] == msg.sender) {
            return true;
        }
        return false;
    }
}