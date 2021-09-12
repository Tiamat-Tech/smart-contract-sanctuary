// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

/**

 ▒█████    ██████  ██▓ ██▀███   ██▓  ██████ 
▒██▒  ██▒▒██    ▒ ▓██▒▓██ ▒ ██▒▓██▒▒██    ▒ 
▒██░  ██▒░ ▓██▄   ▒██▒▓██ ░▄█ ▒▒██▒░ ▓██▄   
▒██   ██░  ▒   ██▒░██░▒██▀▀█▄  ░██░  ▒   ██▒
░ ████▓▒░▒██████▒▒░██░░██▓ ▒██▒░██░▒██████▒▒
░ ▒░▒░▒░ ▒ ▒▓▒ ▒ ░░▓  ░ ▒▓ ░▒▓░░▓  ▒ ▒▓▒ ▒ ░
  ░ ▒ ▒░ ░ ░▒  ░ ░ ▒ ░  ░▒ ░ ▒░ ▒ ░░ ░▒  ░ ░
░ ░ ░ ▒  ░  ░  ░   ▒ ░  ░░   ░  ▒ ░░  ░  ░  
    ░ ░        ░   ░     ░      ░        ░ 

 */

//** OpenZeppelin Dependencies Upgradeable */
import '@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol';
import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol';
import '@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol';
//** OpenZepplin non-upgradeable Swap Token (hex3t) */
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
// Dependencies
import './abstracts/Pauser.sol';

import 'hardhat/console.sol';

/**
    TODO - Random NFT
    TODO - Max token transfer
    TODO - Figure out not taking fee when adding liquidiy
    TODO - Remove uniswap references for pancake swap?
    TODO - Reorganize / Restructure
 */

contract OsirisToken is ERC20Upgradeable, AccessControlUpgradeable, OwnableUpgradeable, Pauseable {
    event SwapETHForTokens(uint256 amountIn, address[] path);
    event SwapTokensForETH(uint256 amountIn, address[] path);

    //** Constants */
    address public constant deadAddress = 0x000000000000000000000000000000000000dEaD;

    //** Role Variables */
    bytes32 private constant MINTER_ROLE = keccak256('MINTER_ROLE');

    //** Variables */
    address public ticket;
    uint8 public buyTax; // done
    uint8 public sellTax; // done
    uint8 public transferTax; // done
    uint256 numTokensBeforeLiquify; // done
    uint256 numBNBBeforeBuyback; // done
    bool inSwapAndLiquify; // done
    bool swapAndLiquifyEnabled; // done
    bool buybackEnabled; // done
    bool feeEnabled; // done
    IUniswapV2Router02 public uniswapV2Router; // done
    address public uniswapV2Pair; // done
    mapping(address => bool) private _isExcludedFromFee; // done

    //** Time Transfer Variables */
    mapping(address => uint256) public _timeOfLastTransfer;
    mapping(address => bool) public _blacklist;
    mapping(address => bool) public _whitelist;
    mapping(address => bool) public pairs;
    mapping(address => bool) public routers;
    bool public timeLimited; // done
    uint256 public timeBetweenTransfers; // done

    //** Black list for bots */
    modifier isBlackedListed(address sender, address recipient) {
        require(_blacklist[sender] == false, 'ERC20: Account is blacklisted from transferring');
        _;
    }

    //** Role Modifiers */
    modifier onlyMinter() {
        require(hasRole(MINTER_ROLE, _msgSender()), 'Caller is not a minter');
        _;
    }

    /** Lock while swapping */
    modifier lockTheSwap {
        inSwapAndLiquify = true;
        _;
        inSwapAndLiquify = false;
    }

    //** Initialize functions */
    function initialize(
        string memory _name,
        string memory _symbol,
        address _ticket,
        address _router
    ) public initializer {
        __ERC20_init(_name, _symbol);
        __Ownable_init(); // Contract creator becomes owner
        __Pausable_init(); // Contract creator becomes pauser

        // vars
        swapAndLiquifyEnabled = true;
        buybackEnabled = true;
        timeLimited = true;
        feeEnabled = true;
        timeBetweenTransfers = 300; // 15mins
        transferTax = 2; // 2%
        buyTax = 4; // 4%
        sellTax = 8; // 8%

        // Swap
        routers[_router] = true;
        uniswapV2Router = IUniswapV2Router02(_router);
        uniswapV2Pair = IUniswapV2Factory(uniswapV2Router.factory()).createPair(
            address(this),
            uniswapV2Router.WETH()
        );
        pairs[uniswapV2Pair] = true;

        // Initial Exclusion
        _isExcludedFromFee[owner()] = true;
        _isExcludedFromFee[address(this)] = true;

        // Supply
        uint256 initialSupply = 1e6 * 1e9; // 1million
        _mint(owner(), initialSupply);
        numTokensBeforeLiquify = (totalSupply() * 2) / 100; // 2% of total supply
        numBNBBeforeBuyback = 1e18; // 1bnb

        // addresses
        ticket = _ticket;

        emit Transfer(address(0), _msgSender(), initialSupply);
    }

    function addMinters(address[] calldata instances) external onlyOwner {
        for (uint256 index = 0; index < instances.length; index++) {
            _setupRole(MINTER_ROLE, instances[index]);
        }
    }

    function mint(address to, uint256 amount) external onlyMinter {
        _mint(to, amount);
    }

    //** Roles management - only for multi sig address */
    function setupRole(bytes32 role, address account) external onlyOwner {
        _setupRole(role, account);
    }

    //** Transfers */
    function isTimeLimited(address sender, address recipient) internal {
        if (timeLimited && _whitelist[recipient] == false && _whitelist[sender] == false) {
            address toDisable = sender;
            if (pairs[sender] == true) {
                toDisable = recipient;
            } else if (pairs[recipient] == true) {
                toDisable = sender;
            }

            if (pairs[toDisable] == true || routers[toDisable] == true || toDisable == address(0))
                return; // Do nothing as we don't want to disable router

            if (_timeOfLastTransfer[toDisable] == 0) {
                _timeOfLastTransfer[toDisable] = block.timestamp;
            } else {
                require(
                    block.timestamp - _timeOfLastTransfer[toDisable] > timeBetweenTransfers,
                    'ERC20: Time since last transfer must be greater then time to transfer'
                );
                _timeOfLastTransfer[toDisable] = block.timestamp;
            }
        }
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `recipient` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address recipient, uint256 amount)
        public
        virtual
        override
        isBlackedListed(msg.sender, recipient)
        returns (bool)
    {
        isTimeLimited(msg.sender, recipient);

        (uint256 taxed, uint256 amountLeft) = getTax(msg.sender, recipient, amount);
        if (taxed > 0) {
            uint256 halfTaxed = taxed / 2;
            super.transfer(address(this), halfTaxed);
            _burn(msg.sender, taxed - halfTaxed);
        }

        swap(msg.sender, recipient);

        return super.transfer(recipient, amountLeft);
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Requirements:
     *
     * - `sender` and `recipient` cannot be the zero address.
     * - the sender must have a balance of at least `amount`.
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override isBlackedListed(sender, recipient) returns (bool) {
        isTimeLimited(sender, recipient);

        (uint256 taxed, uint256 amountLeft) = getTax(sender, recipient, amount);
        if (taxed > 0) {
            uint256 halfTaxed = taxed / 2;
            super.transferFrom(sender, address(this), halfTaxed);
            _burn(sender, taxed - halfTaxed);
        }

        swap(sender, recipient);

        return super.transferFrom(sender, recipient, amountLeft);
    }

    /** @dev get tax 
        @param sender {address}
        @param recipient {address}
        @param amount {uint256}
    */
    function getTax(
        address sender,
        address recipient,
        uint256 amount
    ) public view returns (uint256 taxed, uint256 amountLeft) {
        //if any account belongs to _isExcludedFromFee account then remove the fee
        if (_isExcludedFromFee[sender] || _isExcludedFromFee[recipient] || !feeEnabled) {
            taxed = 0;
            amountLeft = amount;
        } else if (pairs[sender] == true) {
            // Buy
            taxed = (amount * uint256(buyTax)) / 100;
            amountLeft = amount - taxed;
        } else if (pairs[recipient] == true) {
            // Sell
            taxed = (amount * uint256(sellTax)) / 100;
            amountLeft = amount - taxed;
        } else {
            // Transfer
            taxed = (amount * uint256(transferTax)) / 100;
            amountLeft = amount - taxed;
        }
    }

    /** @dev liquify
        @param from {address}
        @param to {address}
    */
    function swap(address from, address to) internal {
        uint256 contractTBalance = balanceOf(address(this));
        if (
            contractTBalance >= numTokensBeforeLiquify &&
            !inSwapAndLiquify &&
            pairs[from] == false &&
            swapAndLiquifyEnabled
        ) {
            swapAndLiquify(contractTBalance);
        }

        uint256 contractBalance = address(this).balance;
        if (
            !inSwapAndLiquify &&
            swapAndLiquifyEnabled &&
            pairs[to] == true &&
            buybackEnabled &&
            contractBalance > numBNBBeforeBuyback
        ) {
            uint256 halfBNB = contractBalance;
            buyBackTokens(halfBNB);
            payable(owner()).transfer(contractBalance - halfBNB);
        }
    }

    /** @dev Swap and liquify
        @param contractBalance {uint256}
    */
    function swapAndLiquify(uint256 contractBalance) private lockTheSwap {
        swapTokensForEth(contractBalance);
    }

    /** @dev buyBackTokens
        @param amount {uint256}
    */
    function buyBackTokens(uint256 amount) private lockTheSwap {
        if (amount > 0) {
            swapETHForTokens(amount);
        }
    }

    /** @dev buyBackTokens
        @param tokenAmount {uint256}
    */
    function swapTokensForEth(uint256 tokenAmount) private {
        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();

        _approve(address(this), address(uniswapV2Router), tokenAmount);

        // make the swap
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            address(this),
            block.timestamp
        );

        emit SwapTokensForETH(tokenAmount, path);
    }

    /** @dev swapEthForTokens
        @param amount {uint256}
    */
    function swapETHForTokens(uint256 amount) private {
        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = uniswapV2Router.WETH();
        path[1] = address(this);

        // make the swap
        uniswapV2Router.swapExactETHForTokensSupportingFeeOnTransferTokens{value: amount}(
            0, // accept any amount of Tokens
            path,
            deadAddress, // Burn address
            block.timestamp + 300
        );

        emit SwapETHForTokens(amount, path);
    }

    /** Additional Setters */

    /** @dev set time limited
        @param _timeLimited {bool}
    */
    function setTimeLimited(bool _timeLimited) external onlyOwner {
        timeLimited = _timeLimited;
    }

    /** @dev set time between transfers
        @param _timeBetweenTransfers {uint256}
    */
    function setTimeBetweenTransfers(uint256 _timeBetweenTransfers) external onlyOwner {
        timeBetweenTransfers = _timeBetweenTransfers;
    }

    /** @dev set is a pair
        @param _pair {address}
        @param _isPair {bool}
    */
    function setPair(address _pair, bool _isPair) external onlyOwner {
        pairs[_pair] = _isPair;
    }

    /** @dev set a router
        @param _router {address}
        @param _isRouter {bool}
    */
    function setRouter(address _router, bool _isRouter) external onlyOwner {
        routers[_router] = _isRouter;
    }

    /** @dev set blacklist address
        @param _address {address}
        @param _blacklisted {bool}
    */
    function setBlackListedAddress(address _address, bool _blacklisted) external onlyOwner() {
        _blacklist[_address] = _blacklisted;
    }

    /** @dev set whitelisted address
        @param _address {address}
        @param _whitelisted {bool}
    */
    function setWhiteListedAddress(address _address, bool _whitelisted) external onlyOwner {
        _whitelist[_address] = _whitelisted;
    }

    /** @dev set liquify enabled
        @param enabled {bool}
    */
    function setSwapAndLiquifyEnabled(bool enabled) external onlyOwner {
        swapAndLiquifyEnabled = enabled;
    }

    /** @dev set buyback enabled
        @param enabled {bool}
    */
    function setBuyBackEnabled(bool enabled) external onlyOwner {
        buybackEnabled = enabled;
    }

    /** @dev set fee enabled
        @param enabled {bool}
    */
    function setFeeEnabled(bool enabled) external onlyOwner {
        feeEnabled = enabled;
    }

    /** @dev set num before liquify 
        @param amount {uint256}
    */
    function setNumTokensBeforeLiquify(uint256 amount) external onlyOwner {
        numTokensBeforeLiquify = amount;
    }

    /** @dev set num before buyback 
        @param amount {uint256}
    */
    function setNumBNBBeforeBuyback(uint256 amount) external onlyOwner {
        numBNBBeforeBuyback = amount;
    }

    /** @dev set buy tax {onlyOwner}
        @param tax {uint8}
     */
    function setBuyTax(uint8 tax) external onlyOwner {
        buyTax = tax;
    }

    /** @dev set transfer tax {onlyOwner}
        @param tax {uint8}
     */
    function setTransferTax(uint8 tax) external onlyOwner {
        transferTax = tax;
    }

    /** Exclude 
        Description: When an account is excluded from fee, we remove fees then restore fees
        @param account {address}
     */
    function setExcludeForAccount(address account, bool exclude) external onlyOwner {
        _isExcludedFromFee[account] = exclude;
    }

    /** @dev set sell tax {onlyOwner}
        @param tax {uint8}
     */
    function setSellTax(uint8 tax) external onlyOwner {
        sellTax = tax;
    }

    /** Additional */
    function decimals() public view virtual override returns (uint8) {
        return 9;
    }
}