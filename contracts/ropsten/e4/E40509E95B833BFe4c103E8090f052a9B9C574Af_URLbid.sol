/*
This contract is unaudited.  
The owner of the contract may change the URL
at anytime, without notice if they perceive 
the current URL redirect to be harmful to 
others or the contract owner.
 */

// SPDX-License-Identifier: MIT
pragma solidity 0.8.5;

import "hardhat/console.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract URLbid is Ownable {
    // ============ Public Immutable Storage ============

    // minimum price required to change the `currentURL`
    uint256 public priceFloor;

    // ============ Public Mutable Storage ============

    // current URL where site will be redirected
    string currentURL = "";

    // ============ Events ============

    event urlChange(string currentURL);
    event priceFloorChange(uint256 priceFloor);

    // ============ External: getURL ============

    /**
     * @notice Query the contract to get current redirect url
     * @return `currentURL`
     */
    function getURL() public view returns (string memory) {
        return currentURL;
    }

    // ============ External: changeURL ============

    /**
     * @notice Change the URL by paying a price above `priceFloor`.
     * @return currentURL
     */
    function changeURL(string memory newURL)
        external
        payable
        returns (string memory)
    {
        require(
            msg.value > priceFloor,
            "Value must be greater than priceFloor"
        );
        currentURL = newURL;
        priceFloor = msg.value;

        emit urlChange(currentURL);
        emit priceFloorChange(priceFloor);
        return currentURL;
    }

    // ============ External: ownerChangeURL ============

    /**
     * @notice Change URL for owner
     * @dev Reverts if not owner
     * Emits urlChange
     * @return currentURL
     */
    function adminChangeURL(string memory adminURL)
        public
        onlyOwner
        returns (string memory)
    {
        currentURL = adminURL;

        emit urlChange(currentURL);
        return currentURL;
    }

    // ============ External: getPriceFloor ============

    /**
     * @notice Query contract for price floor
     * @return priceFloor
     */
    function getPriceFloor() public view returns (uint256) {
        return priceFloor;
    }

    // ============ External: withdrawAll ============

    /**
     * @notice withdraw all funds from the contract, only available to owner
     */
    function withdrawAll() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }
}