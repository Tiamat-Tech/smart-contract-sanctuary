// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;

import "../lib/ERC20.sol";
import "../lib/SafeERC20.sol";
import './interfaces/iIncentives.sol';

contract IncentivesToken is ERC20{
    constructor(
        string memory name,
        string memory symbol,
        uint256 initialSupply
    ) ERC20(name, symbol) {
        _mint(msg.sender, initialSupply);
    }
}

contract Incentives is IIncentives{
    
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    struct MaxBorrow{
        address token;
        uint256 amount;
    }

    struct User{
        uint256 id;
        uint256 govTokenBalances;
        MaxBorrow maxBorrowed;
        mapping (address=>uint256) borrowedList;
    }

    uint256 public initialSupply;
    address public owner;
    address[] public allTokens;
    mapping (address=>User) users;
    IERC20 public governanceTokens;
    uint256 private lastUserId = 0;
    bool private entered;


    modifier nonReentrant() {
        require(!entered, "reentrant call");
        entered = true;
        _;
        entered = false;
    }

    modifier onlyOwner() {
        require(owner == msg.sender, "caller is not the owner");
        _;
    }

    constructor(address _governanceTokens) {
        owner = msg.sender;
        entered = false;
        governanceTokens = IERC20(_governanceTokens);
        initialSupply = governanceTokens.totalSupply();

    }

    function createnNewIncentivesToken(string memory name, string memory symbol) external onlyOwner override {
        bytes memory bytecode = type(IncentivesToken).creationCode;
        bytecode = abi.encodePacked(bytecode, abi.encode(name, symbol, initialSupply));
        bytes32 salt = keccak256(abi.encodePacked(name, symbol));
        address contractAddress;
        assembly {
            contractAddress := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        require(contractAddress != address(0), "Create2: Failed on deploy");
        allTokens.push(contractAddress);
        emit IncentivesTokenCreated(symbol, contractAddress);     

    }

    function switchOwner(address newOwner) external onlyOwner override{
        owner = newOwner;
    }


    function putGovernance(uint256 amount) external override{
        
        require(amount > 0, "amount must be greater than 0");
        require(
            governanceTokens.allowance(address(msg.sender), address(this)) >=
                amount,
            "Increase the allowance first,call the approve method"
        );
        governanceTokens.safeTransferFrom(
            address(msg.sender),
            address(this),
            amount
        );
        if(users[msg.sender].id>0){
            users[msg.sender].govTokenBalances=users[msg.sender].govTokenBalances.add(amount);
        }else{
            users[msg.sender].id=++lastUserId;
            users[msg.sender].govTokenBalances=amount;
        }

    }

    function withdrawGovernance(uint256 amount) external override{
        require(users[msg.sender].id>0,"user not exist");
        require(amount>0 
        && users[msg.sender].govTokenBalances.sub(users[msg.sender].maxBorrowed.amount) >= amount,"available Governance amount exceeded");
        users[msg.sender].govTokenBalances=users[msg.sender].govTokenBalances.sub(amount);
        governanceTokens.safeTransfer(address(msg.sender), amount);
    }

    function withdrawIncentives(address tokenAddress, uint256 amount) external override{
        require(users[msg.sender].id>0,"user not exist");
        require(amount>0 
        && users[msg.sender].govTokenBalances.sub(users[msg.sender].borrowedList[tokenAddress]) >= amount,"available Incentives amount exceeded");
        users[msg.sender].borrowedList[tokenAddress] = users[msg.sender].borrowedList[tokenAddress].add(amount);
        if(users[msg.sender].borrowedList[tokenAddress] > users[msg.sender].maxBorrowed.amount){
            users[msg.sender].maxBorrowed.amount = users[msg.sender].borrowedList[tokenAddress];
            users[msg.sender].maxBorrowed.token = tokenAddress;
        }
        IERC20(tokenAddress).safeTransfer(address(msg.sender), amount);

    }

    function withdrawAllIncentives() external nonReentrant override{
        require(users[msg.sender].id>0,"user not exist");
        users[msg.sender].maxBorrowed.amount=users[msg.sender].govTokenBalances;
        for(uint256 i=0;i<allTokens.length;i++){
            uint256 qty = users[msg.sender].govTokenBalances.sub(users[msg.sender].borrowedList[allTokens[i]]);          
            if(qty>0){
                users[msg.sender].borrowedList[allTokens[i]] = users[msg.sender].govTokenBalances;
                IERC20(allTokens[i]).safeTransfer(address(msg.sender), qty);
            }
        }
    }

    function putIncentivesTokens(address tokenAddress, uint256 amount) external override{
        require(users[msg.sender].id>0,"user not exist");
        require(amount>0 && users[msg.sender].borrowedList[tokenAddress] >= amount,"bad amount or tokenAddress");
        require(
            IERC20(tokenAddress).allowance(address(msg.sender), address(this)) >=
                amount,
            "Increase the allowance first,call the approve method"
        );
        IERC20(tokenAddress).safeTransferFrom(
            address(msg.sender),
            address(this),
            amount
        );
        if(amount<users[msg.sender].borrowedList[tokenAddress]){
            users[msg.sender].borrowedList[tokenAddress] = users[msg.sender].borrowedList[tokenAddress].sub(amount);
        }else{
            users[msg.sender].borrowedList[tokenAddress] = 0;
        }
        if(users[msg.sender].maxBorrowed.token==tokenAddress){
            //search for maximum borrow
            MaxBorrow memory max;
            for(uint256 i=0;i<allTokens.length;i++){
                if(users[msg.sender].borrowedList[allTokens[i]]>max.amount){
                    max.amount=users[msg.sender].borrowedList[allTokens[i]];
                    max.token=allTokens[i];
                }
            }
            users[msg.sender].maxBorrowed = max;
        }
    }
    
    function getMaxBorrowed(address user) view external override returns(uint256){
        require(users[user].id>0,"user not exist");
        return users[user].maxBorrowed.amount;
    }
    function getGovBalances(address user) view external override returns(uint256){
        require(users[user].id>0,"user not exist");
        return users[user].govTokenBalances;
    }
    function userState(address user) view external override returns(address[] memory, uint256[] memory){
        require(users[user].id>0,"user not exist");
        address[] memory addr=new address[](allTokens.length+1);
        uint256[] memory balances=new uint256[](allTokens.length+1);
        
        for(uint256 i=0;i<allTokens.length;i++){
            addr[i]=allTokens[i];
            balances[i]=users[user].govTokenBalances.sub(users[user].borrowedList[allTokens[i]]);
        }
        addr[allTokens.length] = address(governanceTokens);
        balances[allTokens.length] = users[user].govTokenBalances.sub(users[msg.sender].maxBorrowed.amount);

        return(addr,balances);
    }
    function availableTokens() view external override returns(address[] memory, uint256[] memory){
        
        address[] memory addr=new address[](allTokens.length+1);
        uint256[] memory balances=new uint256[](allTokens.length+1);
        
        for(uint256 i=0;i<allTokens.length;i++){
            addr[i]=allTokens[i];
            balances[i]=uint256(IERC20(allTokens[i]).balanceOf(address(this)));
        }
        addr[allTokens.length] = address(governanceTokens);
        balances[allTokens.length] = uint256(governanceTokens.balanceOf(address(this)));

        return(addr,balances);     

    }
    function userscount() view external override returns(uint256){
        return lastUserId;
    }

    function getAddress(string memory name, string memory symbol) public view override returns (address) {
        bytes memory bytecode = type(IncentivesToken).creationCode;
        bytecode = abi.encodePacked(bytecode, abi.encode(name, symbol, initialSupply));
        bytes32 salt = keccak256(abi.encodePacked(name, symbol));
        bytes32 hash = keccak256(
            abi.encodePacked(
                bytes1(0xff),
                address(this),
                salt,
                keccak256(bytecode)
            )
        );

        // NOTE: cast last 20 bytes of hash to address
        return address(uint160(uint256(hash)));
    }
}