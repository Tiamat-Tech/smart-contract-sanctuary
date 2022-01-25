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

    mapping(bytes4 => FunctionDetails) public functionoHashes;

    constructor() {
        functionoHashes[0x5ae401dc] = FunctionDetails("5ae401dc", "multicall", "uint256,bytes[]");
    }

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

    function decodeUniswap(bytes memory _data) external pure returns (uint256 returnint, bytes[] memory returnbytes) {
        bytes memory functionArguments = BytesLib.slice(_data, 4, _data.length - 4);

        // Uniswap multicall(uint256,bytes[])
        
        require(BytesLib.toBytes4(_data, 0) == 0x5ae401dc, "unexpected function call");
        (returnint , returnbytes) = abi.decode(functionArguments, (uint256, bytes[]));

        // assembly {
        //     sig := mload(add(_data, add(0x20, 0)))
        //     remaining := mload(add(_data, add(0x20, 32)))
        // }
    }
}