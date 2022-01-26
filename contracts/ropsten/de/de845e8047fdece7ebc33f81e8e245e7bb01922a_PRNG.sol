/**
 *Submitted for verification at Etherscan.io on 2022-01-25
*/

pragma solidity ^0.8.0;

contract PRNG {

    mapping(address => uint256) public NumberOfTickets;
    mapping(address =>uint32[]) public ticketNumbers;  // 0-5 firsrt 6 tickets,6-11 second 6 tickets so on
    mapping(address => uint256) public nonces;


    function encode() public view returns (bytes32) {
        return keccak256(abi.encode(msg.sender,nonces[msg.sender]));
    }

    function castUint(bytes4 p) public pure returns (uint32) {
        return uint32(p);
    }


    function getByteIndex(bytes32  x,uint256 y) public pure returns (bytes4) {
        return _concat(_concat1(0x00,x[y]),_concat1(x[y+1],x[y+2]));
    }

    function length(address ad) public view returns (uint){
        return ticketNumbers[ad].length;
    }
    

    function getRNG(uint256 j) public  returns (uint32[] memory) {
        nonces[msg.sender]++;
        NumberOfTickets[msg.sender]+=j;
        bytes32 hash = encode();
        for(uint256 i =0;i<5*j;i=i+5){
            uint32 temp = castUint(getByteIndex(hash,i))/10**4;
            if(temp < 1000000){
                temp = temp-1000000 + temp;
                ticketNumbers[msg.sender].push(temp);
            }else{
                ticketNumbers[msg.sender].push(temp);
            }
        }
        return ticketNumbers[msg.sender];
    }

    function div(uint x,uint y) public pure returns (uint) {
        return x/y;
    } 



    function encodePacked(bytes1[] memory b) public pure returns(bytes memory) {
        return abi.encodePacked(b);
    }

    function _concat(bytes2 a,bytes2 b) public pure returns (bytes4) {
        return bytes4(bytes.concat(a,b));
    }

    function _concat1(bytes1 a,bytes2 b) public pure returns (bytes2) {
        return bytes2(bytes.concat(a,b));
    }

    //536000 //1,072,000
    //0-9 /1million
}