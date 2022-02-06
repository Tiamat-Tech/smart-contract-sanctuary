// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IToken
{
        function approve(address spender,uint256 amount)external;
        function allowance(address owner,address spender)external view returns(uint256);
        function balanceOf(address addr)external view returns(uint256);
        function decimals() external view  returns (uint8);
        function name() external view  returns (string memory);
        function symbol() external view  returns (string memory);
        function totalSupply() external view  returns (uint256);
}

contract DDAOallocV02 is AccessControl, Ownable
{
        using SafeMath for uint256;
        using SafeERC20 for IERC20;
	mapping (uint8 => uint256)public LevelMin;
	address public TokenAddr;

	event EAllocate(uint256 number,address payer,address addr, uint256 sale,uint256 level,uint256 amount);

	struct saleStruct
	{
		uint256 id;
		bool disabled;
		string name;
		string comments;
		address vault;
		uint256 amount;
	}
	mapping(uint256 => saleStruct)public Sale;
	uint256 public SaleMax;

	struct info
	{
		address addr;
		uint8 decimals;
		string name;
		string symbol;
		uint256 totalSupply;
	}
        constructor()
        {
        	_setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
		// DevUSDC
		TokenAddr = 0x753f470F3a283A8e99e5dacf9dD0eDf7F64a9F80;

		LevelMin[1] = 50;
		LevelMin[2] = 100;
		LevelMin[3] = 1000;
	

	}
        // Start: Admin functions
        event adminModify(string txt, address addr);
        modifier onlyAdmin()
        {
                require(IsAdmin(_msgSender()), "Access for Admin's only");
                _;
        }

        function IsAdmin(address account) public virtual view returns (bool)
        {
                return hasRole(DEFAULT_ADMIN_ROLE, account);
        }
        function AdminAdd(address account) public virtual onlyAdmin
        {
                require(!IsAdmin(account),'Account already ADMIN');
                grantRole(DEFAULT_ADMIN_ROLE, account);
                emit adminModify('Admin added',account);
        }
        function AdminDel(address account) public virtual onlyAdmin
        {
                require(IsAdmin(account),'Account not ADMIN');
                require(_msgSender()!=account,'You can`t remove yourself');
                revokeRole(DEFAULT_ADMIN_ROLE, account);
                emit adminModify('Admin deleted',account);
        }
        // End: Admin functions

        function TokenAddrSet(address addr)public virtual onlyAdmin
        {
                TokenAddr = addr;
        }
	function TokenAllowance(address addr)public view returns(uint256 value)
	{
		value = IToken(TokenAddr).allowance(addr,address(this));
	}
	function TokenInfo()public view returns(info memory val)
	{
		val.addr = TokenAddr;
		val.decimals = IToken(TokenAddr).decimals();
		val.name = IToken(TokenAddr).name();
		val.symbol = IToken(TokenAddr).symbol();
		val.totalSupply = IToken(TokenAddr).totalSupply();
	}
	function SaleModify(uint256 id,string memory name,string memory comments,address vault,uint256 amount)public onlyAdmin
	{
		uint256 i = id;
		Sale[i].id = id;
		Sale[i].name = name;
		Sale[i].comments = comments;
		Sale[i].vault = vault;
		Sale[i].amount = amount;
		Sale[i].disabled = true;
		if(SaleMax < id)SaleMax = id;
	}
	function SaleDisable(uint256 id,bool trueorfalse)public onlyAdmin
	{
		Sale[id].disabled = trueorfalse;
	}
	function SaleDisabled(uint256 id)public view returns(bool trueorfalse)
	{
		trueorfalse = Sale[id].disabled;
	}
	function LevelMinChange(uint8 level, uint256 value)public onlyAdmin
	{
		LevelMin[level] = value;
	}

	uint256 public AllocCount;

	mapping (uint256 => uint256) public AllocSaleCount;
	mapping (uint256 => uint256) public AllocSaleAmount;
	mapping (uint256 => mapping(uint256 => uint256)) public AllocSaleLevelCount;
	mapping (uint256 => mapping(uint256 => uint256)) public AllocSaleLevelAmount;

/*
	struct alloc
	{
		uint256 number;
		uint256 blk;
		uint256 time;
		uint256 sale;
		uint8 level;
		address addr;
		address payer;
		uint256 amount;
	}
	uint256 public AllocAmount;

	mapping(uint256 => alloc)public AllocInfo;

	mapping (uint256 => mapping(uint256 => uint256)) public AllocSaleId;
	mapping (uint256 => mapping(uint256 => mapping(uint256 => uint256))) public AllocSaleLevelId;
*/
/*
	mapping (address => uint256) public BuyerCount;
	mapping (address => uint256) public BuyerAmount;
	mapping (address => mapping(uint256 => uint256)) public BuyerSaleCount;
	mapping (address => mapping(uint256 => uint256)) public BuyerSaleAmount;
	mapping (address => mapping(uint256 => mapping(uint256 => uint256))) public BuyerSaleId;
	mapping (address => mapping(uint256 => mapping(uint256 => uint256))) public BuyerSaleLevelCount;
	mapping (address => mapping(uint256 => mapping(uint256 => uint256))) public BuyerSaleLevelAmount;
	mapping (address => mapping(uint256 => mapping(uint256 => mapping(uint256 => uint256)))) public BuyerSaleLevelId;
*/

	function Allocate(uint256 sale, uint8 level, address addr, uint256 amount)public
	{
		require(Sale[sale].disabled == false,"Sale with this ID is disabled");
                require(amount <= IERC20(TokenAddr).balanceOf(_msgSender()),"Not enough tokens to receive");
		require(IERC20(TokenAddr).allowance(_msgSender(),address(this)) >= amount,"You need to be allowed to use tokens to pay for this contract [We are wait approve]");
		require(amount >= LevelMin[level] * 10**IToken(TokenAddr).decimals(),"Amount must be more then LevelMin for this level");

		AllocCount = AllocCount.add(1);
//		AllocAmount     				= AllocAmount.add(amount);
		AllocSaleCount[sale]    			= AllocSaleCount[sale].add(1);
		AllocSaleAmount[sale]   			= AllocSaleAmount[sale].add(amount);
		AllocSaleLevelCount[sale][level]        	= AllocSaleLevelCount[sale][level].add(1);
		AllocSaleLevelAmount[sale][level]       	= AllocSaleLevelAmount[sale][level].add(amount);


/*
		AllocInfo[AllocCount].number 	= AllocCount;
		AllocInfo[AllocCount].blk 	= block.number;
		AllocInfo[AllocCount].time 	= block.timestamp;
		AllocInfo[AllocCount].sale 	= sale;
		AllocInfo[AllocCount].level 	= level;
		AllocInfo[AllocCount].addr 	= addr;
		AllocInfo[AllocCount].payer 	= _msgSender();
		AllocInfo[AllocCount].amount 	= amount;

		AllocSaleLevelId[sale][level][AllocSaleLevelCount[sale][level]]         = AllocCount;
		AllocSaleId[sale][AllocSaleCount[sale]]         = AllocCount;
*/
/**
		BuyerCount[addr]        			= BuyerCount[addr].add(1);
		BuyerAmount[addr]       			= BuyerAmount[addr].add(amount);
		BuyerSaleCount[addr][sale]      		= BuyerSaleCount[addr][sale].add(1);
		BuyerSaleAmount[addr][sale]     		= BuyerSaleAmount[addr][sale].add(amount);
		BuyerSaleId[addr][sale][BuyerSaleCount[addr][sale]]     = AllocCount;
		BuyerSaleLevelCount[addr][sale][level]  	= BuyerSaleLevelCount[addr][sale][level].add(1);
		BuyerSaleLevelAmount[addr][sale][level]         = BuyerSaleLevelAmount[addr][sale][level].add(amount);
		BuyerSaleLevelId[addr][sale][level][BuyerSaleLevelCount[addr][sale][level]]     = AllocCount;
**/

                IERC20(TokenAddr).safeTransferFrom(_msgSender(),Sale[sale].vault, amount);
		emit EAllocate(AllocCount,_msgSender(), addr, sale,level, amount);
	}

}