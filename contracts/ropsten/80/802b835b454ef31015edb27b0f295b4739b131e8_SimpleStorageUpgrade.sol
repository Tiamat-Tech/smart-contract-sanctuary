pragma solidity 0.8.4;

import "hardhat/console.sol";

contract SimpleStorageUpgrade {
    uint256 storedData;

    event Change(string message, uint256 newVal);

    function set(uint256 x) public {
        // console.log("The Value is %d", x);
        require(x < 5000, "Should be less than 5000");
        storedData = x;
        emit Change("set", x);
    }

    function get() public view returns (uint256) {
        return storedData;
    }
}