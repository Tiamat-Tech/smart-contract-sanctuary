/**
 *Submitted for verification at Etherscan.io on 2021-12-20
*/

pragma solidity >=0.7.0 <0.9.0;

/**
 * @title Storage
 * @dev Store & retrieve value in a variable
 */
contract cbSimple2 {

    uint256 number;

		constructor () public {
			number = 42;
		}

    /**
     * @dev Store value in variable
     * @param num value to store
     */
    function store(uint256 num) public {
        number = num;
    }

    /**
     * @dev Return value 
     * @return value of 'number'
     */
    function retrieve() public view returns (uint256){
        return number;
    }
    
    
    function add(uint256 _value) public {
        number += _value;
    }
    
    
    
}