/// SPDX-License-Identifier: MIT
/// CryptoHero Contracts v1.0.0 (HeroCore.sol)

pragma solidity ^0.8.0;

import "./HeroMinting.sol";

contract HeroCore is HeroMinting {
    address public newContractAddress;

    /// @notice Creates the main cryptoHero smart contract instance.
    constructor() {
        // starts paused.
        pause();

        // start with the mythical hero 0 - so we don't have generation-0 parent issues
        _createHero(0, 0, 0, 0, 0, 0, address(this));
    }

    /// @dev Used to mark the smart contract as upgraded, in case there is a serious
    ///  breaking bug. This method does nothing but keep track of the new contract and
    ///  emit a message indicating that the new address is set. It's up to clients of this
    ///  contract to update to the new contract address in that case. (This contract will
    ///  be paused indefinitely if such an upgrade takes place.)
    /// @param _v2Address new address
    function setNewAddress(address _v2Address) external onlyOwner whenPaused {
        newContractAddress = _v2Address;
    }

    /// @notice No tipping!
    /// @dev Reject all Ether from being sent here, unless it's from one of the auction contracts.
    //  (Hopefully, we can prevent user accidents.)
    receive() external payable {
        require(msg.sender == address(breedingAuction), "Only breeding auction payable");
    }

    /// Pause crypto hero contract.
    function pause() public onlyOwner whenNotPaused {
        super._pause();
    }

    /// @dev Override unpause so it requires all external contract addresses
    ///  to be set before contract can be unpaused. Also, we can't have
    ///  newContractAddress set either, because then the contract was upgraded.
    /// @notice This is public rather than external so we can call super.unpause without using an expensive CALL.
    function unpause() public onlyOwner whenPaused {
        require(address(breedingAuction) != address(0), "Breeding auction is not ready.");
        require(address(geneScience) != address(0), "Gene science is not ready.");
        require(newContractAddress == address(0), "New contract was updated.");
        // Actually unpause the contract.
        super._unpause();
    }

    // @dev Allows the owner to capture the balance available to the contract.
    function withdrawBalance() external onlyOwner {
        uint256 balance = address(this).balance;
        address owner = super.owner();
        require(payable(owner).send(balance), "Failed to withdraw balance.");
    }
}