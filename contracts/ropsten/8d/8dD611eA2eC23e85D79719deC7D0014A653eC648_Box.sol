//ropsten --- 0x8dD611eA2eC23e85D79719deC7D0014A653eC648
pragma solidity ^0.6.0;

//import "./access-ctrl/auth.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Box is Ownable {
    uint256 private value;

    //emmitted when the stored value changes
    event ValueChanged(uint256 newValue);


    //stores new value in the contract
    function store(uint256 newValue) public onlyOwner {

        value = newValue;
        emit ValueChanged(newValue);
    }

    //read the last sored value
    function retrieve() public view returns (uint256){
        return value;
    }
}