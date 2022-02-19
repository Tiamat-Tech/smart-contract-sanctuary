// SPDX-License-Identifier: MIT
/* ======================================================= DEFI HUNTERS DAO =========================================================
	                                           https://defihuntersdao.club/
------------------------------------------------------------ Feb 2021 ---------------------------------------------------------------
 NNNNNNNNL     NNNNNNNNL       .NNNN.      .NNNNNNN.        .JNNNNNN (NNNNNNNNNN    JNNNL     (NN)  .NNNN NNN
 NNNNNNNNNN.   NNNNNNNNNN.     JNNNN)     JNNNNNNNNNL       NNNNNNNF (NNNNNNNNNN   .NNNNN     (NN)  NNNN  NNN
 NNN    4NNN   NNN    4NNN     NNNNNN    (NNN`   `NNN)     (NNF          NNN       (NNNNN)    (NN) NNNF        .__ .___       ___..__
 NNN     NNN)  NNN     NNN)   (NN)4NN)   NNN)     (NNN     (NNN_         NNN       NNN`NNN    (NN)NNNF    NNN  (NNNNNNNN)   JNNNNNNNN
 NNN     4NN)  NNN     4NN)   NNN (NNN   NNN`     `NNN      4NNNNN.      NNN      (NN) NNN)   (NNNNNN.    NNN  (NNNF"NNNN  (NNNF"NNNN
 NNN     JNN)  NNN     JNN)  (NNF  NNN)  NNN       NNN       "NNNNNN     NNN      NNN` (NNN   (NNNNNNN    NNN  (NNF   NNN  NNN)   NNN
 NNN     NNN)  NNN     NNN)  JNNNNNNNNL  NNN)     (NNN          4NNN)    NNN     .NNNNNNNNN.  (NNN NNNL   NNN  (NN)   NNN  NNN    NNN
 NNN    JNNN   NNN    JNNN  .NNNNNNNNNN  4NNN     NNNF           (NN)    NNN     JNNNNNNNNN)  (NN) `NNN)  NNN  (NN)   NNN  NNN)  .NNN
 NNN___NNNN`   NNN___NNNN`  (NNF    NNN)  NNNNL_JNNNN      (NL__JNNN)    NNN     NNN`   (NNN  (NN)  (NNN) NNN  (NN)   NNN  (NNNNNNNNN
 NNNNNNNNN`    NNNNNNNNN`   NNN`    (NNN   4NNNNNNNF       (NNNNNNN)     NNN    (NNF     NNN) (NN)   (NNN.NNN  (NN)   NNN   `NNNNNNNN
 """"""`       """"""`      """      """     """""          `""""`              `""`     `""`             """  `""`   """        .NNN
                                                                                                                            NNNNNNNN)
                                                                                                                            NNNNNNN`
================================================================================================================================ */
pragma solidity ^0.8.11;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

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

/**
Контракт стейкинга токенов DDAO для участия в аллокациях или 
любых иных мероприятиях от  https://defihuntersdao.club/
Для отражения всей суммы стейкинга необходимо, чтобы токены 
находились на контракте не менее 5 дней.
Вывести токены можно в любой момент.
**/
contract DDAOStaking01 is AccessControl
{
	using SafeMath for uint256;
	using SafeERC20 for IERC20;

	address public owner = _msgSender();

	/**
	Стуктура хранения данных о каждом кошельке, который делает стейк
	**/
	struct info
	{
	    bool exists;
	    address 	addr;
	    uint48 	time;
	    uint256 	amount;
	    uint256 	stale;
	}
	mapping (address => info) public Stakers;
	address[] Users;

	
	/**
	В стейк отдаются монеты на период 5 раз по 1 дню изначально.
	Значение StakeTime может меняться функцией StakeTimeChang().
	**/
	uint48 public StakeTime  = 1 hours;
	uint8  constant stake_steps = 5;

	// коэффициент округления. Изначально береться 0.1%
	uint16 constant koef = 1000;

	// DDAO TOken
	// testnet
	 address public TokenAddr = 0xF870b9C48C2B9757696c25988426e2A0941334B5;
	// mainnet
	//address public TokenAddr = 0x90F3edc7D5298918F7BB51694134b07356F7d0C7;

	event eStake(address addr, uint256 amount,  uint48 time, uint256 now_amount, uint256 stale);
	event eUnStake(address addr, uint256 amount,  uint48 time, uint256 now_amount, uint256 stale);
	event eStakeStaleFix(address addr, uint48 time, uint256 now_amount, uint256 stale);

	constructor() 
	{
	_setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
	Admins.push(_msgSender());
	//AdminAdd(_msgSender());
	// Административный адрес владельца DDAO
	//_setupRole(DEFAULT_ADMIN_ROLE, 0x208b02f98d36983982eA9c0cdC6B3208e0f198A3);
	AdminAdd(0x208b02f98d36983982eA9c0cdC6B3208e0f198A3);
	//_setupRole(DEFAULT_ADMIN_ROLE, 0x80C01D52e55e5e870C43652891fb44D1810b28A2);
	}

	// Start: Admin functions
	event adminModify(string txt, address addr);
	address[] Admins;
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
		Admins.push(account);
	}
	function AdminDel(address account) public virtual onlyAdmin
	{
		require(IsAdmin(account),'Account not ADMIN');
		require(_msgSender()!=account,'You can`t remove yourself');
		revokeRole(DEFAULT_ADMIN_ROLE, account);
		emit adminModify('Admin deleted',account);
	}
	/**
	Список адресов, которые могут быть админами.
	Проверить нужно функцию: IsAdmin(address)
	**/
	function AdminList()public view returns(address[] memory)
	{
		return Admins;
	}
	// End: Admin functions

	
	function TokenAddrSet(address addr)public virtual onlyAdmin
	{
		TokenAddr = addr;
	}

	/**
	Tokens have already been sold to customers and they have received aDDAO. 
	We answer with our name. 
	In the last change, we added token addresses directly to the contract so that 
	it would not be visible that these are not proxy contracts. The withdrawal of 
	tokens is needed in case we are somehow broken, despite all the tests and audits, 
	so that we can withdraw and redo the contract
	**/
	function AdminGetCoin(uint256 amount) public onlyAdmin
	{
		payable(_msgSender()).transfer(amount);
	}
	function AdminGetToken(address tokenAddress, uint256 amount) public onlyAdmin 
	{
		IERC20 ierc20Token = IERC20(tokenAddress);
		ierc20Token.safeTransfer(_msgSender(), amount);
	}

	/**
	В будущем может понадобиться изменить интервал стейкинга
	**/
	function StakeTimeChange(uint48 time)public onlyAdmin
	{
	    StakeStaleMultiFix();
	    StakeTime = time;
	}
	/** 
	функция выводит баланс в токенах DDAO которые уже отлежались в стейкинге (не весь баланс в стейкинге) 
	Synonym balanceOf() - for compatibility discord services, allocation  and others services
	**/
	function StakeStale(address addr)public view returns(uint256 balance)
	{
		balance = Stakers[addr].stale.add(StakeCalculate(addr,0));
	}
	function balanceOf(address addr)public view returns(uint256 balance)
	{
		balance = StakeStale(addr);
	}
	/**
	Функция вывода всего застейканного баланса
	**/
	function StakeAmount(address addr)public view returns(uint256 balance)
	{
		balance = Stakers[addr].stale.add(Stakers[addr].amount);
	}
	// Функция вывода баланса токена DDAO для текущего контракта
        function TokenBalance() public view returns(uint256)
        {
                IERC20 ierc20Token = IERC20(TokenAddr);
                return ierc20Token.balanceOf(address(this));
        }

	// owner ddao and his friend
	/**
	В стейкинг может закинуть любой адрес. Необходимо, чтобы на балансе были токены.
	К примеру, у пользователя есть горячий, холодный кошелек, Ledger, Trezor etc.
	Для упрощения работы с токенами для участия в сейлах или других мероприятиях от https://defihuntersdao.club/
	можно выполнять действия с одного адреса, которые не касаются снятия средств.
	!!! Важно: Если отправитель этой транзакции делает стейк для адреса, который ему не принадлежит - доступ к токенам теряется навсегда.
	**/
	function Stake(address addr,uint256 amount)public
	{	
	    require(amount.mul(10**IToken(TokenAddr).decimals()) <= IERC20(TokenAddr).balanceOf(_msgSender()),"Not enough tokens to receive");
	    require(IERC20(TokenAddr).allowance(_msgSender(),address(this)) >= amount.mul(10**IToken(TokenAddr).decimals()),"You need to be allowed to use tokens to pay for this contract [We are wait approve]");

	    if(addr == address(0))addr = _msgSender();

	    IERC20(TokenAddr).safeTransferFrom(_msgSender(),address(this), amount.mul(10**IToken(TokenAddr).decimals()));

	    if(Stakers[addr].time == 0)
	    {
		Stakers[addr].time 	= uint48(block.timestamp);
		Stakers[addr].addr 	= addr;
		Stakers[addr].amount 	= amount;
		Stakers[addr].stale 	= 0;
		Users.push(addr);
	    }
	    else
	    {
		//uint256 stale = StakeCalculate(addr,uint48(block.timestamp));
		StakeStaleFix(addr);
		Stakers[addr].time 	= uint48(block.timestamp);
		Stakers[addr].amount 	= Stakers[addr].amount.add(amount);
	    }
	    emit eStake(addr, amount, Stakers[addr].time, Stakers[addr].amount, Stakers[addr].stale);
	    
	}
	/**
	    Функция высчитывает и показывает суммы токенов, которые могут считаться отлежавшимися в зависимости от времени.
	**/
	function StakeCalculate(address addr,uint48 time)public view returns(uint256 stale)
	{
	    if(time == 0)time = uint48(block.timestamp);

	    uint48 	interval;
	    uint256 	delta_amount;
	    uint48 	delta_time;
	    uint256 	part;
	    interval 	= StakeTime * stake_steps;
	    delta_amount = Stakers[addr].amount - Stakers[addr].stale;
	    delta_time 	= time - Stakers[addr].time; 
	    part = delta_time * koef / interval;
	    if(part > koef)part = koef;
	    stale = Stakers[addr].amount * part / koef;
	}
	//only owner of ddao
	/**
	Вывод токенов можно осуществить в любой момент.
	Вывод может осуществить только владелец адреса.
	**/
	function Unstake(uint256 amount)public
	{
	    address addr = _msgSender();
	    uint256 all = Stakers[addr].amount + Stakers[addr].stale;
	    require(amount <= all,'You have requested more tokens than you have in the stake');
	    StakeStaleFix(addr);
	    if(Stakers[addr].stale == 0)
	    {
		Stakers[addr].amount = Stakers[addr].amount.sub(amount);
	    }
	    else
	    {
		if(amount >= Stakers[addr].amount)
		{
		    amount = amount.sub(Stakers[addr].amount);
		    Stakers[addr].amount = 0;

		    Stakers[addr].stale = Stakers[addr].stale.sub(amount);
		}
		else
		{
		    Stakers[addr].amount = Stakers[addr].amount.sub(amount);
		}
		
	    }
	    Stakers[addr].time = uint48(block.timestamp);
	    IERC20(TokenAddr).safeTransfer(_msgSender(), amount.mul(10**IToken(TokenAddr).decimals()));
	    emit eUnStake(addr, amount, Stakers[addr].time, Stakers[addr].amount, Stakers[addr].stale);
	}
	/**
	Функция фиксасции суммы отлежавшихся токенов и свежих в зависимости от времени.
	**/
	function StakeStaleFix(address addr)public
	{
	    if(Stakers[addr].amount >= 0)
	    {
	    uint256 temp;
	    temp = StakeCalculate(addr,0);
	    require(temp <= Stakers[addr].amount,"Unknown Error in StakeCalculate");
	    Stakers[addr].stale = Stakers[addr].stale.add(temp);
	    Stakers[addr].amount = Stakers[addr].amount.sub(temp);
	    Stakers[addr].time = uint48(block.timestamp);
	    emit eStakeStaleFix(addr, Stakers[addr].time, Stakers[addr].amount, Stakers[addr].stale);
	    }
	}
	/**
	Функция пересчета отлежавшихся сумм.
	Нужна при изменении интервала.
	**/
	function StakeStaleMultiFix()public
	{
	    for(uint32 i=0;i < Users.length;i++)
	    {
		StakeStaleFix(Users[i]);
	    }
	}

	
	/**
	Информация о текущем времени блока в сети
	**/
	function BlockTime()public view returns(uint256)
	{
	    return block.timestamp;
	}
	function StakersCount()public view returns(uint256)
	{
	    return Users.length;
	}
	function StakersList()public view returns(address[] memory)
	{
	    return Users;
	}
}