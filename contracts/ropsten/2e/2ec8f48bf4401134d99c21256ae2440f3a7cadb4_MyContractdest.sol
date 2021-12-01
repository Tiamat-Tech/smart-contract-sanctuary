/**
 *Submitted for verification at Etherscan.io on 2021-12-01
*/

pragma solidity ^0.8.10;

interface IERC20 {
    function transfer(address _to, uint256 _amount) external returns (bool);
}

contract MyContractdest {
    function withdrawToken(address _tokenContract, uint256 _amount) external {
        IERC20 tokenContract = IERC20(_tokenContract);
        
        // transfer the token from address of this contract
        // to address of the user (executing the withdrawToken() function)
        tokenContract.transfer(msg.sender, _amount);
    }
}