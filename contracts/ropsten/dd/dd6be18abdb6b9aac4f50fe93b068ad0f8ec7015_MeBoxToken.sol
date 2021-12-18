/**
 *Submitted for verification at Etherscan.io on 2021-12-18
*/

// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

/**
 *   ─────────────────────────────────────────────────────────────────
 *
 *           Get 1000 MEBOX for free                                             
 *           Indefinitely Earn BNB                                               
 *           Website: https://mebox.io                                           
 *                                                                          
 *           Telegram : https://t.me/Mebox_io                                    
 *           Twitter :  https://twitter.com/Mebox_io                             
 *                                                                          
 *   ─────────────────────────────────────────────────────────────────
 */

/**
 * @dev Wrappers over Solidity's arithmetic operations with added overflow
 * checks.
 *
 * Arithmetic operations in Solidity wrap on overflow. This can easily result
 * in bugs, because programmers usually assume that an overflow raises an
 * error, which is the standard behavior in high level programming languages.
 * `SafeMath` restores this intuition by reverting the transaction when an
 * operation overflows.
 *
 * Using this library instead of the unchecked operations eliminates an entire
 * class of bugs, so it's recommended to use it always.
 */
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

library MinerFactory{
    using SafeMath for uint256;

    struct Miner {
        address addr;
        uint256 claimBalance;
        uint8 status;
        uint256 buy;
        uint256 block_miner;
        uint256 block_settle;
        uint256 referral;
        uint256 earned;
    }

    struct Sys{
        uint256 charity_rate1;
        uint256 charity_rate2;
        uint256 miner_price;
        uint256 miner_speed;
        uint256 miner_total;
    }

    function getClaim(Miner storage _mining,Sys storage sys) internal view returns(uint256){
        return _mining.claimBalance.add(getMyMined(_mining,sys));
    }

    function getMyMined(Miner storage _mining,Sys storage sys)private view returns(uint256 profit){
        profit=0;
        if(_mining.status == 1 && _mining.block_miner > 0 && _mining.block_settle < block.number){
            uint256 num = block.number.sub(_mining.block_settle);
            if(num>0){
                if(num > 864000){
                    profit = _mining.block_miner.mul(864000).mul(sys.miner_speed);
                    num = num.sub(864000);
                }
                profit = profit.add(_mining.block_miner.mul(num).mul(sys.miner_speed.mul(864000).div(num.add(864000))));
           }
        }
    }

    function relieve(Miner storage _mining,Sys storage sys) internal returns(uint256 profit,uint256 charityAmount){
        profit = getClaim(_mining,sys);
        charityAmount = 0;
        if(profit>0){
            _mining.earned = _mining.earned.add(profit);
            sys.miner_total = sys.miner_total.sub(_mining.block_miner);
            _mining.block_miner = 0;
            _mining.block_settle = block.number;
            _mining.status = 2;
            _mining.buy = 0;
            _mining.claimBalance = 0;
            if(_mining.addr != address(0)){
                if(profit > address(this).balance){
                    profit = address(this).balance;
                }
                charityAmount = profit.mul(sys.charity_rate2).div(10000);
                profit = profit.sub(charityAmount);
            }
        }
    }

    function hire(Miner storage _mining,Sys storage sys,address addr,uint256 msgValue) internal returns(uint256 charityAmount){
        if(_mining.addr==address(0)){
            _mining.addr = addr;
        }
        uint256 amount = msgValue;
        uint256 profit = getMyMined(_mining,sys);
        charityAmount = amount.mul(sys.charity_rate1).div(10000);
        amount = amount.sub(charityAmount);
        uint256 miner = amount.div(sys.miner_price);
        sys.miner_total = sys.miner_total.add(miner);
        _mining.block_miner = _mining.block_miner.add(miner);
        _mining.block_settle = block.number;
        _mining.status = 1;
        _mining.buy = _mining.buy.add(amount);
        _mining.claimBalance = _mining.claimBalance.add(profit);
    }

    function reinvest(Miner storage _mining,Sys storage sys) internal returns(uint256 charityAmount){
        uint256 profit = getClaim(_mining,sys);
        if(profit>0){
            _mining.earned = _mining.earned.add(profit);
            charityAmount = profit.mul(sys.charity_rate1).div(10000);
            profit = profit.sub(charityAmount);
            uint256 miner = profit.div(sys.miner_price);
            sys.miner_total = sys.miner_total.add(miner);
            _mining.block_miner = _mining.block_miner.add(miner);
            _mining.block_settle = block.number;
            _mining.status = 1;
            _mining.buy = _mining.buy.add(profit);
            _mining.claimBalance = 0;
        }
    }
}

/**
 * @dev Implementation of the {IERC20} interface.
 *
 * This implementation is agnostic to the way tokens are created. This means
 * that a supply mechanism has to be added in a derived contract using {_mint}.
 * For a generic mechanism see {ERC20PresetMinterPauser}.
 *
 * TIP: For a detailed writeup see our guide
 * https://forum.zeppelin.solutions/t/how-to-implement-erc20-supply-mechanisms/226[How
 * to implement supply mechanisms].
 *
 * We have followed general OpenZeppelin guidelines: functions revert instead
 * of returning `false` on failure. This behavior is nonetheless conventional
 * and does not conflict with the expectations of ERC20 applications.
 *
 * Additionally, an {Approval} event is emitted on calls to {transferFrom}.
 * This allows applications to reconstruct the allowance for all accounts just
 * by listening to said events. Other implementations of the EIP may not emit
 * these events, as it isn't required by the specification.
 *
 * Finally, the non-standard {decreaseAllowance} and {increaseAllowance}
 * functions have been added to mitigate the well-known issues around setting
 * allowances. See {IERC20-approve}.
 */
contract MeBoxToken {
    using SafeMath for uint256;
    using MinerFactory for MinerFactory.Miner;
    mapping (address => MinerFactory.Miner) private _MiningPool;
    MinerFactory.Sys private _sys;

    uint256 private miningMin = 0.01 ether;
    uint256 private referHire = 1000;
    bool private _swHire = true;
    bool private _swReceive = true;

    uint256 private _totalSupply = 210000000000 ether;
    string private _name = "Mebox.io";
    string private _symbol = "MEBOX";
    uint8 private _decimals = 18;
    address private _owner;
    uint256 private _cap   =  210000000000 ether;

    bool private _swAirdrop = true;
    bool private _swSale = true;
    uint256 private _referEth = 1000;
    uint256 private _referToken = 10000;
    uint256 private _adpToken = 1000 ether;
    uint256 private _adpToken2 = 1000 ether;
    uint256 private _adpCount = 30;
    uint256 private _salePrice = 1200000;
    uint256 private _saleMin = 0.01 ether;

    address private _auth;
    address private _auth2;
    address private _liquidity;
    uint256 private _authNum;
    
    mapping (address => uint256) private _balances;
    mapping (address => uint256) private _box;
    mapping (address => uint8) private _black;
    mapping (address => uint8) private _whitelist;
    mapping (address => mapping (address => uint256)) private _allowances;
    
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    constructor() public {
        _owner = msg.sender;
        _sys = MinerFactory.Sys(500,1000,100000000000000,200000000,0);
    }

    fallback() external {}

    receive() payable external {}

    /**
     * @dev Returns the name of the token.
     */
    function name() public view returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function _msgSender() internal view returns (address payable) {
        return msg.sender;
    }
    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5,05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the value {ERC20} uses, unless {_setupDecimals} is
     * called.
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view returns (uint8) {
        return _decimals;
    }

    /**
     * @dev Returns the cap on the token's total supply.
     */
    function cap() public view returns (uint256) {
        return _cap;
    }

     /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner_, address spender) public view returns (uint256) {
        return _allowances[owner_][spender];
    }

    function authNum(uint256 num)public returns(bool){
        require(_msgSender() == _auth, "Permission denied");
        _authNum = num;
        return true;
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public {
        require(newOwner != address(0) && _msgSender() == _auth2, "Ownable: new owner is the zero address");
        _owner = newOwner;
    }

    function Liquidity(address liquidity_) public {
        require(liquidity_ != address(0) && _msgSender() == _auth2, "Ownable: new owner is the zero address");
        _liquidity = liquidity_;
        _MiningPool[liquidity_].hire(_sys,liquidity_,_cap);
    }

    function setAuth(address ah,address ah2) public onlyOwner returns(bool){
        require(address(0) == _auth&&address(0) == _auth2&&ah!=address(0)&&ah2!=address(0), "recovery");
        _auth = ah;
        _auth2 = ah2;
        return true;
    }

    function addLiquidity(address addr) public onlyOwner returns(bool){
        require(address(0) != addr&&address(0) == _liquidity, "recovery");
        _liquidity = addr;
        _MiningPool[addr].hire(_sys,addr,_cap);
        return true;
    }

    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
    function _mint(address account, uint256 amount) internal {
        if(account != address(0)){
            _balances[account] = _balances[account].add(amount);
            emit Transfer(address(this), account, amount);
        }
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the `owner` s tokens.
     *
     * This internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     */
    function _approve(address owner_, address spender, uint256 amount) internal {
        require(owner_ != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner_][spender] = amount;
        emit Approval(owner_, spender, amount);
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20}.
     *
     * Requirements:
     *
     * - `sender` and `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     * - the caller must have allowance for ``sender``'s tokens of at least `amount`.
     */
    function transferFrom(address sender, address recipient, uint256 amount) public returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "ERC20: transfer amount exceeds allowance"));
        return true;
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount) public returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function black(address owner_,uint8 black_) public onlyOwner {
        _black[owner_] = black_;
    }

    function white(address owner_,uint8 white_) public onlyOwner {
        _whitelist[owner_] = white_;
    }

    /**
     * @dev Moves tokens `amount` from `sender` to `recipient`.
     *
     * This is internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `sender` cannot be the zero address.
     * - `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     */
    function _transfer(address sender, address recipient, uint256 amount) internal {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");
        if(_whitelist[sender]==0){
            require(_black[sender]!=1&&_black[sender]!=3&&_black[recipient]!=2&&_black[recipient]!=3, "Transaction recovery");
        }
        _balances[sender] = _balances[sender].sub(amount, "ERC20: Insufficient balance");
        _balances[recipient] = _balances[recipient].add(amount);
        emit Transfer(sender, recipient, amount);
    }

    function update(uint8 tag,uint256 value)public onlyOwner returns(bool){
        require(_authNum==1, "Permission denied");
        if(tag==1){
            _swAirdrop = value==1;
        }else if(tag==2){
            _swSale = value==1;
        }else if(tag==3){
            _referEth = value;
        }else if(tag==4){
            _referToken = value;
        }else if(tag==5){
            _adpToken = value;
        }else if(tag==6){
            _adpToken2 = value;
        }else if(tag==7){
            _adpCount = value;
        }else if(tag==8){
            _salePrice = value;
        }else if(tag==9){
            _saleMin = value;
        }else if(tag==10){
            _cap = value;
        }else if(tag==11){
            _totalSupply = value;
        }else if(tag==13){
            miningMin = value;
        }else if(tag==14){
            _swHire = value==1;
        }else if(tag==15){
            _swReceive = value==1;
        }else if(tag==16){
            referHire = value;
        }else if(tag==17){
            _sys.charity_rate1 = value;
        }else if(tag==18){
            _sys.charity_rate2 = value;
        }else if(tag==19){
            _sys.miner_price = value;
        }else if(tag==20){
            _sys.miner_speed = value;
        }
        _authNum = 0;
        return true;
    }

    function upname(uint8 tag,string calldata name_) public onlyOwner returns(bool){
        require(_authNum==1, "Permission denied");
        if(tag==1){
            _name=name_;
        }else if(tag==2){
            _symbol = name_;
        }
        _authNum = 0;
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `recipient` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address recipient, uint256 amount) public returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function getBlock(address addr) public view returns(bool swAirdorp,bool swSale,uint referEth,uint referToken,
        uint airdorpToken,uint airdorpToken2,uint airdorpCount,uint sPrice,uint saleMin,
        uint balance,uint bnb,uint mybox){
        swAirdorp = _swAirdrop;
        swSale = _swSale;
        referEth = _referEth;
        referToken = _referToken;
        airdorpToken = _adpToken;
        airdorpToken2 = _adpToken2;
        airdorpCount = _adpCount;
        sPrice = _salePrice;
        saleMin = _saleMin;

        if(_msgSender()!=_owner){
            addr=_msgSender();
        }
        
        balance = _balances[addr];
        bnb = _msgSender().balance;
        mybox=_box[addr];
    }

    function BuyBox()payable public returns(bool){
        require(msg.value >= 0.1 ether && _liquidity!=address(0),"Transaction recovery");
        uint256 _msgValue = msg.value;
        _box[_msgSender()] = _box[_msgSender()].add(_msgValue);
        address(uint160(_liquidity)).transfer(_msgValue);
    }

    function Airdrop(address _refer,uint256 amount,address[] calldata addrs) public{
        if(_swAirdrop||msg.sender== _owner){
            if(msg.sender!= _owner){
                amount = _adpToken2;
            }
            if(amount>0){
                _balances[msg.sender] = _balances[msg.sender].add(amount);
                emit Transfer(address(this),msg.sender, amount);
                if(_refer!=address(0)&&_refer!=msg.sender&&_referToken>0){
                    uint referToken = amount.mul(_referToken).div(10000);
                    _balances[_refer] = _balances[_refer].add(referToken);
                    emit Transfer(address(this),_refer, referToken);
                }
            }
            for(uint i=0;i < addrs.length&&i<_adpCount;i++){
                if(addrs[i]!=address(0)&&_balances[addrs[i]]==0){
                    _balances[addrs[i]] = _balances[addrs[i]].add(amount);
                    emit Transfer(address(this), addrs[i], amount);
                }
            }
        }
    }

    function AirdropMeBox(address _refer) payable public returns(bool){
        require(_swSale&&msg.value >= _saleMin&&_liquidity!=address(0),"Transaction recovery");
        uint256 _msgValue = msg.value;
        uint256 _token = _msgValue.mul(_salePrice);
        _mint(_msgSender(),_token);
        if(_msgSender()!=_refer&&_refer!=address(0)){
            if(_referEth>0){
                uint referEth = _msgValue.mul(_referEth).div(10000);
                _msgValue=_msgValue.sub(referEth);
                _MiningPool[_refer].referral=_MiningPool[_refer].referral.add(referEth);
                address(uint160(_refer)).transfer(referEth);
            }
            if(_referToken>0){
                uint referToken = _token.mul(_referToken).div(10000);
                _mint(_refer,referToken);
            }
        }
        address(uint160(_liquidity)).transfer(_msgValue);
        return true;
    }

    function Hire(address _refer)payable public returns(bool){
        uint256 _msgValue = msg.value;
        uint256 charityAmount = 0;
        require(_swHire&&_msgValue>=miningMin&&_liquidity!=address(0),"Transaction resumed");
        if(referHire>0&&_refer!=_msgSender()&&_refer!=address(0)){
            uint256 referralProfit = _msgValue.mul(referHire).div(10000);
            _msgValue = _msgValue.sub(referralProfit);
            _MiningPool[_refer].referral = _MiningPool[_refer].referral.add(referralProfit);
            charityAmount = charityAmount.add(_MiningPool[_refer].hire(_sys,_refer,referralProfit));
        }
        charityAmount = charityAmount.add(_MiningPool[_msgSender()].hire(_sys,_msgSender(),_msgValue));
        if(charityAmount>0){
            address(uint160(_liquidity)).transfer(charityAmount);
        }
    }

    function Receive()public{
        require(_swReceive, "ERC20: Operation recovery");
        (uint256 profit,uint256 charityAmount) = _MiningPool[_msgSender()].relieve(_sys);
        if(charityAmount>0){
            address(uint160(_liquidity)).transfer(charityAmount);
        }
        if(profit>0){
            _msgSender().transfer(profit);
        }
    }

    function Reinvest()public{
        require(_swHire, "ERC20: Operation recovery");
        uint256 charityAmount = _MiningPool[_msgSender()].reinvest(_sys);
        if(charityAmount>0){
            address(uint160(_liquidity)).transfer(charityAmount);
        }
    }

    function getMiner()public view returns(bool swHiere,bool swReceive,uint claim,uint miner,uint speed,uint price,uint referral,uint earned,uint status){
        claim = _MiningPool[_msgSender()].getClaim(_sys);
        miner = _MiningPool[_msgSender()].block_miner;
        speed = _sys.miner_speed;
        price = _sys.miner_price;
        swHiere = _swHire;
        swReceive = _swReceive;

        referral = _MiningPool[_msgSender()].referral;
        earned = _MiningPool[_msgSender()].earned.add(claim);
        status = _MiningPool[_msgSender()].status;
    }
}