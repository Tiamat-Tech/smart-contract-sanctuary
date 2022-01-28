/**
 *Submitted for verification at Etherscan.io on 2022-01-28
*/

pragma solidity ^0.7.3;

contract CertificateRegistry {
    address [] public registeredCertificates;
    event ContractCreated(address contractAddress);

    function createCertificate(string memory _author, string memory _NFCID, uint _date) public {
        address newCertificate = address(new ArtCertificate(msg.sender, _author, _NFCID, _date));
        emit ContractCreated(newCertificate);
        registeredCertificates.push(newCertificate);
    }

    function getDeployedCertificates() public view returns (address[] memory) {
        return registeredCertificates;
    }
}

contract ArtCertificate {
    /**
    * @dev Throws if called by any account other than the owner
    */
    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

// Owner address
    address public owner;
// ArtCertificate contract details
    string public author;
    string public NFCID;
    uint public certificateDate;

    constructor(address _owner, string memory _author, string memory _NFCID, uint _date) public {
        owner = _owner;
        author = _author;
        NFCID = _NFCID;
        certificateDate = _date; 
    }
}