/**
 *Submitted for verification at Etherscan.io on 2021-08-29
*/

pragma  solidity 0.6.0;



contract ntransact{
    
    event Deposit( address from, uint _value);//Declares an event
    address private _owner;
    
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }
    
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    
    function _setOwner(address newOwner) public payable {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
    constructor()public{
        _setOwner(_msgSender());
    }
    
    function owner() public view virtual returns (address) {
        return _owner;
    }
    
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }
    modifier min(uint _amount){
        require(msg.value>=_amount,"Your deposit amount must be grater than 0");
        _;
    }
    
    address[] public dep;
    uint public totalDeposits=0;
    
    receive() external payable min(1 ether){
        dep.push(msg.sender);
        totalDeposits=totalDeposits+msg.value;
        emit Deposit(msg.sender,msg.value);
        
    }
    
    function withdrawDep(address payable _to,uint _amount)public onlyOwner{
        _to.transfer(_amount);
        totalDeposits=totalDeposits- _amount;
        
        
    }
    
}