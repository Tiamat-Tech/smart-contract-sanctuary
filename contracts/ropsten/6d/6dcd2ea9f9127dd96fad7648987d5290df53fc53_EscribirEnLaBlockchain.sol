/**
 *Submitted for verification at Etherscan.io on 2021-03-04
*/

pragma solidity >=0.7.0 <0.8.0;

contract EscribirEnLaBlockchain{
    string texto;
    
    function Escribir(string calldata _texto) public {
        texto = _texto;
    }
    
    function Leer() public view returns (string memory){
        return texto;
    }
}