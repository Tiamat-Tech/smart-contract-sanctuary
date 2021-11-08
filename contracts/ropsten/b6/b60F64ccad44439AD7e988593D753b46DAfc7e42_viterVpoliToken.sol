// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "hardhat/console.sol";

contract viterVpoliToken is ERC20 {
    address public admin;
    uint256 private _totalSupply;
    address nulll = 0x0000000000000000000000000000000000000000;
    mapping(address => uint256) private balances;
    mapping(address => mapping(address => uint256)) private allowances;

    // event Transfer(address indexed from, address indexed to, uint tokens);
    // event Approval(address indexed tokenOwner, address indexed spender, uint tokens);

    constructor() ERC20("viter V poli Token", "VVPT") {
        _totalSupply = 1000 * (10**18);
        _mint(msg.sender, _totalSupply);
        admin = msg.sender;
    }

    //Создает amount токены и назначает их to, увеличивая общее количество.
    function mint(address to, uint256 amount) external {
        require(msg.sender == admin, "Only Admin");
        _mint(to, amount);
        nulll = 0x0000000000000000000000000000000000000000;
        emit Transfer(nulll, to, amount);
    }

    //Возвращает количество существующих токенов
    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    // сжигает количество токенов у вызывающего, уменьшая общий запас.
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
        emit Transfer(msg.sender, nulll, amount);
    }

    //возвращает баланс
    function balanceOf(address account)
        public
        view
        virtual
        override
        returns (uint256)
    {
        return balances[account];
    }

    function transfer(address recipient, uint256 amount)
        public
        virtual
        override
        returns (bool)
    {
        _transfer(_msgSender(), recipient, amount);
        emit Transfer(msg.sender, recipient, amount);
        return true;
    }

    //Возвращает оставшееся количество токенов, spender которые можно будет потратить от имени owner. Это значение изменяется при вызове approve или transferFrom.
    function allowance(address owner, address spender)
        public
        view
        virtual
        override
        returns (uint256)
    {
        return allowances[owner][spender];
    }

    //утверждаю лицо и сумму третьему лицу для пользования
    function approve(address spender, uint256 amount)
        public
        virtual
        override
        returns (bool)
    {
        _approve(_msgSender(), spender, amount);
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    //Отправка токенов доверительным лицом с помощью механизма допуска.
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);
        uint256 currentAllowance = allowances[sender][_msgSender()];
        require(
            currentAllowance >= amount,
            "ERC20: transfer amount exceeds allowance"
        );
        unchecked {
            _approve(sender, _msgSender(), currentAllowance - amount);
        }
        emit Transfer(msg.sender, recipient, amount);
        return true;
    }
}