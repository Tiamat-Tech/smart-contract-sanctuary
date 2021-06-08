//SPDX-License-Identifier: Unlicense
pragma solidity ^0.6.2;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "./interfaces/IMogulSmartWallet.sol";
import "./matic/BasicMetaTransaction.sol";

contract MogulSmartWalletFactory is BasicMetaTransaction {
    address public mogulSmartWalletLogicContractAddress;
    address public owner;

    event NewWallet(
        address smartWalletAddress,
        address owner,
        address[] guardians,
        uint256 minGuardianVotesRequired
    );

    /**
     * @dev Sets the logic contract address and owner
     *
     * Parameters:
     *
     * - _mogulSmartWalletLogicContractAddress: the Mogul Smart Wallet Logic contract address.
     * - _owner: the owner of the Factory contract.
     */
    constructor(address _mogulSmartWalletLogicContractAddress, address _owner)
        public
    {
        mogulSmartWalletLogicContractAddress = _mogulSmartWalletLogicContractAddress;
        owner = _owner;
    }

    /**
     * @dev Deploys a smart wallet contract to a deterministic address,
     * derived from the logic contract address and the provided salt
     *
     * Parameters:
     *
     * - _salt: a unique salt to derive the deployment address.
     * - _owner: owner of the smart wallet.
     * - _guardians: initial guardians of the smart wallet.
     * - _minGuardianVotesRequired: minimum guardian votes required
     * to change owners.
     * - _pausePeriod: number of seconds to pause the
     * smart wallet owner actions  when locked
     *
     * Requirements:
     *
     * - caller must be owner.
     */
    function deployMogulSmartWalletDeterministic(
        bytes32 _salt,
        address _owner,
        address[] memory _guardians,
        uint256 _minGuardianVotesRequired,
        uint256 _pausePeriod
    ) public {
        require(msgSender() == owner, "Caller is not the owner");
        address predictedAddress =
            Clones.cloneDeterministic(
                mogulSmartWalletLogicContractAddress,
                _salt
            );
        IMogulSmartWallet(predictedAddress).initialize(
            _owner,
            _guardians,
            _minGuardianVotesRequired,
            _pausePeriod
        );

        emit NewWallet(
            predictedAddress,
            _owner,
            _guardians,
            _minGuardianVotesRequired
        );
    }

    /**
     * @dev Predicts the deterministic address of a smart wallet contract,
     * derived from the logic contract address and the provided salt
     *
     * Parameters:
     *
     * - _salt: a unique salt to derive the deployment address.
     */
    function predictMogulSmartWalletDeterministicAddress(bytes32 _salt)
        public
        view
        returns (address predictedAddress)
    {
        return
            Clones.predictDeterministicAddress(
                mogulSmartWalletLogicContractAddress,
                _salt,
                address(this)
            );
    }


    /**
     * @dev Owner function to tranfer ownership to another address
     *
     * Parameters:
     *
     * - newOwner: the new owner of the factory.
     *
     * Requirements:
     *
     * - caller must be owner.
     */
    function changeOwner(address newOwner) public {
        require(msgSender() == owner, "Caller is not the owner");
        owner = newOwner;
    }
}