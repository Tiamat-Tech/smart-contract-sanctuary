pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";

contract Event_test is EIP712 {

    using ECDSA for bytes32;

    /* Constructor */
    constructor() EIP712("Event_test", "1") {


    }



    function encode_parmas(address _address,uint256 _randomId,uint256 _TokenId,string memory _randomString) public pure returns(bytes memory){
        bytes memory result = abi.encode(_address, _randomId,_TokenId,_randomString);
        return result;
    }

    function matchAddresSigner(bytes32 hash, bytes memory signature) public pure returns (address) {
        return hash.recover(signature);
    }


    function hashTransaction(address sender, uint256 qty, string memory nonce ,bytes[] memory _bytesArray) public view returns (bytes32) {
        bytes32 hash = _hashTypedDataV4(keccak256(
            abi.encodePacked(
                "\x19Ethereum Signed Message:\n32",
                keccak256(abi.encode(sender, qty, nonce,_bytesArray))
            )
        ));
        return hash;

}
}