/**
 *Submitted for verification at Etherscan.io on 2021-06-27
*/

contract DogeCoin {
    address owner;

    string constant name = 'DogeCoin';
    string constant symbol = 'DC';
    uint8 constant decimals = 10;
    
    uint totalSupply = 0;
    mapping(address => mapping(address => uint)) allowed;
    mapping(address => uint) balances;
    
    event emission(address _address, uint value);
    event Transfer(address _address_X, address _address_Y, uint value);
    event Approval(address _address_X, address _address_Y, uint value);
    
    constructor() {
        owner = msg.sender;
    }

    function mint(address _address, uint value) public payable {
        require(owner == msg.sender);
        require(totalSupply < totalSupply + value);
        balances[_address] += value;
        totalSupply += value;
        emit emission(_address, value);
    }
    
    function balanceOf(address _address) public payable returns(uint) {
        return balances[_address];
    }
    
    function balanceOf() public payable returns(uint) {
        return balances[msg.sender];
    }
    
    function transfer(address _address, uint value) public payable {
        require(balances[msg.sender] >= value);
        require(balances[_address] < balances[_address] + value);
        balances[msg.sender] -= value;
        balances[_address] += value;
        emit Transfer(msg.sender, _address, value);
    }
    
    function transferForm(address _address_X, address _address_Y, uint value) public payable {
        require(allowed[_address_X][_address_Y] >= value);
        require(balances[_address_X] >= value);
        require(balances[_address_Y] < balances[_address_Y] + value);
        balances[_address_X] -= value;
        balances[_address_Y] += value;
        allowed[_address_X][_address_Y] -= value;
        emit Transfer(_address_X, _address_Y, value);
    }
    
    function approve(address _address_Y, uint value) public payable {
        require(balances[msg.sender] >= value);
        allowed[msg.sender][_address_Y] = value;
        emit Approval(msg.sender, _address_Y, value);
    }
    
    function allowance(address _address_X, address _address_Y) public payable returns(uint) {
        return allowed[_address_X][_address_Y];
    }
}