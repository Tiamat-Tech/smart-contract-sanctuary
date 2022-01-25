// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;
import "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./base/MultiToken.sol";
import "./lib/BytesLib.sol";

contract AssetManagerUniswap is MultiToken("(AdamUniswap)") {

    struct FunctionDetails {
        string hash;
        string name;
        string arguments;
    }

    mapping(string => FunctionDetails) public functionoHashes;

    event Deposit(address indexed _from, uint indexed _id, uint _value);

    function depositERC20(ERC20 token, uint amount) external {
        TransferHelper.safeTransferFrom(address(token), msg.sender, address(this), amount);

        if(addressToId[address(token)] == 0) {
            _createToken(address(token), token.name(), 18);
        }

         _mint(msg.sender, addressToId[address(token)], amount, "");

         emit Deposit(msg.sender, addressToId[address(token)], amount);
    }

    function getMintedContractsList() external view returns(address[] memory) {
        return mintedContracts;
    }

    function decode(bytes memory _data) external pure returns(bytes memory) {
        return BytesLib.slice(_data, 0, 4);
        // assembly {
        //     sig := mload(add(_data, add(0x20, 0)))
        //     remaining := mload(add(_data, add(0x20, 32)))
        // }
    }
}