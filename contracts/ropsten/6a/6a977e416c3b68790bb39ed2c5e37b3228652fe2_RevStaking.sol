pragma solidity ^0.4.22;

library SafeMath {
    function mul(uint256 a, uint256 b) internal constant returns (uint256) {
        uint256 c = a * b;
        assert(a == 0 || c / a == b);
        return c;
    }

    function div(uint256 a, uint256 b) internal constant returns (uint256) {
        // assert(b > 0); // Solidity automatically throws when dividing by 0
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn&#39;t hold
        return c;
    }

    function sub(uint256 a, uint256 b) internal constant returns (uint256) {
        assert(b <= a);
        return a - b;
    }

    function add(uint256 a, uint256 b) internal constant returns (uint256) {
        uint256 c = a + b;
        assert(c >= a);
        return c;
    }
}


/**
 * @title Ownable
 * @dev The Ownable contract has an owner address, and provides basic authorization control
 * functions, this simplifies the implementation of "user permissions".
 */
contract Ownable {
    address public owner;


    /**
     * @dev The Ownable constructor sets the original `owner` of the contract to the sender
     * account.
     */
    function Ownable() {
        owner = msg.sender;
    }


    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }


    /**
     * @dev Allows the current owner to transfer control of the contract to a newOwner.
     * @param newOwner The address to transfer ownership to.
     */
    function transferOwnership(address newOwner) onlyOwner {
        require(newOwner != address(0));
        owner = newOwner;
    }

}
contract ERC20Token {
    function transferFrom(address _from, address _to, uint _value) public returns (bool);
}
contract RevStaking {
    struct stakingDetail{
        uint256 duration;
        address stakingAddress;
        uint256 amount;
        uint256 timeStart;
    }
    
    mapping (address => stakingDetail) stakingDetails;
    address [] public stakedAddress;
    
    function stack(address _stakingAddress, uint256 _amount, uint256 _duration) public{
        require(_amount>10000);
        
        ERC20Token _token = ERC20Token(0x53981B4004FE67fB3D0Da666D635fDdadeeD5cf8);
        _token.transferFrom(msg.sender, _stakingAddress, _amount);
        
        var stakingDetail = stakingDetails[_stakingAddress];
        stakingDetail.duration = _duration;
        stakingDetail.stakingAddress = _stakingAddress;
        stakingDetail.amount = _amount;
        stakingDetail.timeStart = now;
        
        stakedAddress.push(_stakingAddress);
    }
    
    function getStakedAddresses() view public returns (address[]){
        return stakedAddress;
    }
    
    function getStakedAddress(address _stakingAddress) view public returns (uint256, address, uint256, uint256){
        return (stakingDetails[_stakingAddress].duration,stakingDetails[_stakingAddress].stakingAddress,stakingDetails[_stakingAddress].amount,stakingDetails[_stakingAddress].timeStart);
    }
}