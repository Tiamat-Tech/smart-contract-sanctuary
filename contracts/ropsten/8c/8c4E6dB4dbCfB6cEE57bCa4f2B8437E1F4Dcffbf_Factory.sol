// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "./Organization.sol";

contract Factory {
    event NewOrg(address owner, address organization);

    address public clonableOrg;

    /**
     * @dev Set clonable contract address which uses as library
     * @param _clonableAddress: Organization contract address which uses as library
     */
    function setClonableOrg(address _clonableAddress) public {
        require(
            clonableOrg == address(0),
            "organization-contract-address-already-set"
        );
        clonableOrg = _clonableAddress;
    }

    /**
     * @dev Create organization by clone the contract
     */
    function createOrg() public {
        address clone = Clones.clone(clonableOrg);
        Organization newOrg = Organization(clone);
        newOrg.initiate(msg.sender);
        emit NewOrg(msg.sender, clone);
    }
}