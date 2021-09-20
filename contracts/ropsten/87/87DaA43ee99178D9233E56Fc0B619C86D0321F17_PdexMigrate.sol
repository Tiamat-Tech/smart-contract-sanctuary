// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract PdexMigrate {
    address private burnTokenAddress =
        0x3737373737373737373737373737373737373737;

    event PdexMigratedEvent(uint256 amount, bytes32 pdexAddress);

    function migrate(
        address _tokenOwnerAddress,
        bytes32 _recipient,
        uint256 _amount
    ) public {
        // Testnet address => 0x0c7f69F66AB81BB257198BAa7f42fd1469E002a6
        require(
            IERC20(0x0c7f69F66AB81BB257198BAa7f42fd1469E002a6).transferFrom(
                _tokenOwnerAddress,
                burnTokenAddress,
                _amount
            ),
            "Contract token allowances insufficient to complete this migration"
        );
        emit PdexMigratedEvent(_amount, _recipient);
    }
}