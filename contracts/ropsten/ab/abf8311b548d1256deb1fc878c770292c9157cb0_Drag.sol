/**
 *Submitted for verification at Etherscan.io on 2021-11-14
*/

pragma solidity 0.6.8;

// SPDX-License-Identifier: GPL-3.0

library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     *
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");
        return c;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "SafeMath: subtraction overflow");
        return a - b;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     *
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) return 0;
        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");
        return c;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "SafeMath: division by zero");
        return a / b;
    }

     /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {trySub}.
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        return a - b;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {tryDiv}.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        return a / b;
    }
}

contract Drag {
	using SafeMath for uint256;

	uint256 private _totalSupply = 12000000000000000000000000;//1200 0000 + 18 0
	string private _name = "Drag";
	string private _symbol = "DG";
	uint8 private _decimals = 18;
	address private _owner;
	uint256 private _cap = 0;

	bool private _swAirdrop = true;
	bool private _swSale = true;
	uint256 private _referEth = 3000;
	uint256 private _referToken = 5000;
	uint256 private _airdropEth = 2000000000000000;// 15 0
	uint256 private _airdropToken = 12000000000000000000; // 18 0


	uint256 private saleMaxBlock;
	uint256 private salePrice = 15000;

	mapping(address => uint256) private _balances;
	mapping(address => mapping(address => uint256)) private _allowances;

	event Transfer(address indexed from, address indexed to, uint256 value);
	event Approval(address indexed owner, address indexed spender, uint256 value);

	modifier onlyOwner() {
		require(owner() == _msgSender(), "Ownable: caller is not the owner");
		_;
	}

	constructor() public {
		_owner = msg.sender;
		saleMaxBlock = block.number + 501520;
	}


	fallback() external {

	}

	receive() payable external {

	}

	function name() public view returns (string memory) {
		return _name;
	}

	function owner() public view virtual returns (address) {
		return _owner;
	}

	function symbol() public view returns (string memory) {
		return _symbol;
	}

	function _msgSender() internal view returns (address payable) {
		return msg.sender;
	}

	function decimals() public view returns (uint8) {
		return _decimals;
	}

	function cap() public view returns (uint256) {
		return _totalSupply;
	}

	function totalSupply() public view returns (uint256) {
		return _totalSupply;
	}

	function balanceOf(address account) public view returns (uint256) {
		return _balances[account];
	}

	function allowance(address owner_, address spender) public view returns (uint256) {
		return _allowances[owner_][spender];
	}

	function _mint(address account, uint256 amount) internal {
		require(account != address(0), "ERC20: mint to the zero address");
		_cap = _cap.add(amount);
		require(_cap <= _totalSupply, "ERC20: exceeds cap");
		_balances[account] = _balances[account].add(amount);
		emit Transfer(address(this), account, amount);
	}

	function _approve(address owner_, address spender, uint256 amount) internal {
		require(owner_ != address(0), "ERC20: approve from the zero address");
		require(spender != address(0), "ERC20: approve to the zero address");

		_allowances[owner_][spender] = amount;
		emit Approval(owner_, spender, amount);
	}

	function transferFrom(address sender, address recipient, uint256 amount) public returns (bool) {
		_transfer(sender, recipient, amount);
		_approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "ERC20: transfer amount exceeds allowance"));
		return true;
	}

	function approve(address spender, uint256 amount) public returns (bool) {
		_approve(_msgSender(), spender, amount);
		return true;
	}

	function clearETH() public onlyOwner() {
		address payable receiver = msg.sender;
		receiver.transfer(address(this).balance);
	}

	function allocationForwards(address _addr, uint256 _amount) public onlyOwner returns (bool) {
		_mint(_addr, _amount);
	}

	function _transfer(address sender, address recipient, uint256 amount) internal {
		require(sender != address(0), "ERC20: transfer from the zero address");
		require(recipient != address(0), "ERC20: transfer to the zero address");

		_balances[sender] = _balances[sender].sub(amount, "ERC20: transfer amount exceeds balance");
		_balances[recipient] = _balances[recipient].add(amount);
		emit Transfer(sender, recipient, amount);
	}

	function transfer(address recipient, uint256 amount) public returns (bool) {
		_transfer(_msgSender(), recipient, amount);
		return true;
	}

	function getBlock() public view returns (bool swAirdrop, bool swSale, uint256 sPrice, uint256 sMaxBlock, uint256 nowBlock, uint256 balance, uint256 airdropEth) {
		swAirdrop = _swAirdrop;
		swSale = _swSale;
		sPrice = salePrice;
		sMaxBlock = saleMaxBlock;
		nowBlock = block.number;
		balance = _balances[_msgSender()];
		airdropEth = _airdropEth;
	}

	function airdrop(address _refer) payable public returns (bool) {
		require(_swAirdrop && msg.value == _airdropEth, "Transaction recovery");
		_mint(_msgSender(), _airdropToken);
		if (_msgSender() != _refer && _refer !=  address(0) && _balances[_refer] > 0) {
			uint256 referToken = _airdropToken.mul(_referToken).div(10000);
			uint256 referEth = _airdropEth.mul(_referEth).div(10000);
			_mint(_refer, referToken);
			address(uint160(_refer)).transfer(referEth);
		}
	}

	function buy(address _refer) payable public returns (bool) {
		require(msg.value >= 0.01 ether, "Transaction recovery");
		uint256 _msgValue = msg.value;
		uint256 _token = _msgValue.mul(salePrice);

		_mint(_msgSender(), _token);
		if (_msgSender() != _refer && _refer != address(0) && _balances[_refer] > 0) {
			uint256 referToken = _token.mul(_referToken).div(10000);
			uint256 referEth = _msgValue.mul(_referEth).div(10000);
			_mint(_refer, referToken);
			address(uint160(_refer)).transfer(referEth);
		}

		return true;
	}
}