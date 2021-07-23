// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./Organization.sol";

contract Factory is Ownable {
    event OrganizationAdded(address owner, address organization);

    address public clonableOrg;

    /**
     *@dev Set clonable contract address which uses as library
     *@param _clonableAddress: Organization contract address which uses as library
     */
    function setClonableOrg(address _clonableAddress) external onlyOwner {
        require(
            clonableOrg == address(0),
            "organization-contract-address-already-set"
        );
        clonableOrg = _clonableAddress;
    }

    /**
     *@dev Create organization by clone the contract
     */
    function createOrg() public {
        address clone = Clones.clone(clonableOrg);
        Organization newOrg = Organization(clone);
        newOrg.initiate(msg.sender);
        emit OrganizationAdded(msg.sender, clone);
    }
}