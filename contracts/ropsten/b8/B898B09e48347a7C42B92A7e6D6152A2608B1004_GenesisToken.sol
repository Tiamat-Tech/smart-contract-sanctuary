// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;


import "./OpenzeppelinAbstract.sol";


contract GenesisToken is OpenzeppelinAbstract
{

    constructor(string memory newContractName, address[] memory payees, uint256[] memory shares)
    ERC1155("")
    PaymentSplitter(payees, shares)
    EIP712(newContractName, "1.0.0")
    payable
    {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(OPERATOR_ROLE, msg.sender);
        _grantRole(SIGNER_ROLE, msg.sender);
    }

}