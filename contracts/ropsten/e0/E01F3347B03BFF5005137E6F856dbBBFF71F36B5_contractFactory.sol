// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.7;

// An ethereum smart contract to split funds between an array of addresses 
// according to their respective percentages.
import './splitContract.sol';

// An ethereum factory smart contract to produce more children contracts
// which would be used to split funds in a specific ratio.
contract contractFactory {
    
    // The array of contracts produced by this factory contract.
    address[] public contracts;

    // Event to trigger the creation of new Child contract address.
    event ChildContractCreated (address splitterContractAddress);
        
    // Returns the length of all the contracts deployed through 
    // this factory contract.
    function getContractCount() public view returns(uint) {
        return contracts.length;
    }
    
    /// @param _address The address array of the new contract in which the funds 
    /// will be splitted.
    /// @param _share The precentage array of the respective ethereum addresses
    /// provided for the funds to get splitted.
    function registerContract(address payable[] memory _address, uint[] memory _share) 
    public returns(address) {
        uint256 length = _share.length;
        uint256 totalPercentage = 0;
        uint256 maxPercentage = 100;
        for (uint256 i = 0; i < length; i++) {
            totalPercentage = totalPercentage + _share[i];
        }
        require(maxPercentage >= totalPercentage, "Total percentage should not be greater than 100");
        splitContract c = new splitContract( _address, _share);
        contracts.push(address(c));
        emit ChildContractCreated(address(c));
        return address(c);
    }
}