// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.11;

contract Sender {
    uint256 public count;

    function called() external {
        bytes memory message = abi.encodePacked("Sender: ", msg.sender);

        require(
            msg.sender == address(0xCDf41a135C65d0013393B3793F92b4FAF31032d0),
            string(message)
        );

        count += 1;
    }
}