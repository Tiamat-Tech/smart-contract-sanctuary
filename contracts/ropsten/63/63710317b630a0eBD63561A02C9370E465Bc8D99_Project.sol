// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

contract ERC1 is ERC1155("https://game.example/api/item/{id}.json") {

    function mint (address _account, uint256 _id, uint256 _amount, bytes memory _data) external {
        ERC1155._mint(_account, _id, _amount, _data);
    }

    function burn (address _account, uint256 _id, uint256 _amount) external {
        ERC1155._burn(_account, _id, _amount);
    }

}