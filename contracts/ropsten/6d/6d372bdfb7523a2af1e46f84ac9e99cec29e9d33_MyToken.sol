/**
 *Submitted for verification at Etherscan.io on 2021-11-19
*/

// File: @openzeppelin/contracts/token/ERC20/IERC20.sol

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

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
}

// File: @openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol



pragma solidity ^0.8.0;


/**
 * @dev Interface for the optional metadata functions from the ERC20 standard.
 *
 * _Available since v4.1._
 */
interface IERC20Metadata is IERC20 {
    /**
     * @dev Returns the name of the token.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the symbol of the token.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the decimals places of the token.
     */
    function decimals() external view returns (uint8);
}

// File: @openzeppelin/contracts/utils/Context.sol



pragma solidity ^0.8.0;

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

// File: @openzeppelin/contracts/token/ERC20/ERC20.sol



pragma solidity ^0.8.0;




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
 * We have followed general OpenZeppelin Contracts guidelines: functions revert
 * instead returning `false` on failure. This behavior is nonetheless
 * conventional and does not conflict with the expectations of ERC20
 * applications.
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
contract ERC20 is Context, IERC20, IERC20Metadata {
    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;

    /**
     * @dev Sets the values for {name} and {symbol}.
     *
     * The default value of {decimals} is 18. To select a different value for
     * {decimals} you should overload it.
     *
     * All two of these values are immutable: they can only be set once during
     * construction.
     */
    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5.05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the value {ERC20} uses, unless this function is
     * overridden;
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `recipient` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
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
     * - the caller must have allowance for ``sender``'s tokens of at least
     * `amount`.
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);

        uint256 currentAllowance = _allowances[sender][_msgSender()];
        require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");
            _approve(sender, _msgSender(), currentAllowance - amount);
        

        return true;
    }

    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender] + addedValue);
        return true;
    }

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least
     * `subtractedValue`.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        uint256 currentAllowance = _allowances[_msgSender()][spender];
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
            _approve(_msgSender(), spender, currentAllowance - subtractedValue);
        

        return true;
    }

    /**
     * @dev Moves `amount` of tokens from `sender` to `recipient`.
     *
     * This internal function is equivalent to {transfer}, and can be used to
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
    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(sender, recipient, amount);

        uint256 senderBalance = _balances[sender];
        require(senderBalance >= amount, "ERC20: transfer amount exceeds balance");
            _balances[sender] = senderBalance - amount;
        
        _balances[recipient] += amount;

        emit Transfer(sender, recipient, amount);

        _afterTokenTransfer(sender, recipient, amount);
    }

    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);

        _afterTokenTransfer(address(0), account, amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, reducing the
     * total supply.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
     */
    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
            _balances[account] = accountBalance - amount;
        
        _totalSupply -= amount;

        emit Transfer(account, address(0), amount);

        _afterTokenTransfer(account, address(0), amount);
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
    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /**
     * @dev Hook that is called before any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * will be transferred to `to`.
     * - when `from` is zero, `amount` tokens will be minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}

    /**
     * @dev Hook that is called after any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * has been transferred to `to`.
     * - when `from` is zero, `amount` tokens have been minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens have been burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}
}

// File: @openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol



pragma solidity ^0.8.0;



/**
 * @dev Extension of {ERC20} that allows token holders to destroy both their own
 * tokens and those that they have an allowance for, in a way that can be
 * recognized off-chain (via event analysis).
 */
abstract contract ERC20Burnable is Context, ERC20 {
    /**
     * @dev Destroys `amount` tokens from the caller.
     *
     * See {ERC20-_burn}.
     */
    function burn(uint256 amount) public virtual {
        _burn(_msgSender(), amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, deducting from the caller's
     * allowance.
     *
     * See {ERC20-_burn} and {ERC20-allowance}.
     *
     * Requirements:
     *
     * - the caller must have allowance for ``accounts``'s tokens of at least
     * `amount`.
     */
    function burnFrom(address account, uint256 amount) public virtual {
        uint256 currentAllowance = allowance(account, _msgSender());
        require(currentAllowance >= amount, "ERC20: burn amount exceeds allowance");
        _approve(account, _msgSender(), currentAllowance - amount);
        _burn(account, amount);
    }
}

// File: @openzeppelin/contracts/security/Pausable.sol



pragma solidity ^0.8.0;


/**
 * @dev Contract module which allows children to implement an emergency stop
 * mechanism that can be triggered by an authorized account.
 *
 * This module is used through inheritance. It will make available the
 * modifiers `whenNotPaused` and `whenPaused`, which can be applied to
 * the functions of your contract. Note that they will not be pausable by
 * simply including this module, only once the modifiers are put in place.
 */
abstract contract Pausable is Context {
    /**
     * @dev Emitted when the pause is triggered by `account`.
     */
    event Paused(address account);

    /**
     * @dev Emitted when the pause is lifted by `account`.
     */
    event Unpaused(address account);

    bool private _paused;

    /**
     * @dev Initializes the contract in unpaused state.
     */
    constructor() {
        _paused = false;
    }

    /**
     * @dev Returns true if the contract is paused, and false otherwise.
     */
    function paused() public view virtual returns (bool) {
        return _paused;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    modifier whenNotPaused() {
        require(!paused(), "Pausable: paused");
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is paused.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    modifier whenPaused() {
        require(paused(), "Pausable: not paused");
        _;
    }

    /**
     * @dev Triggers stopped state.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    function _pause() internal virtual whenNotPaused {
        _paused = true;
        emit Paused(_msgSender());
    }

    /**
     * @dev Returns to normal state.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    function _unpause() internal virtual whenPaused {
        _paused = false;
        emit Unpaused(_msgSender());
    }
}

// File: @openzeppelin/contracts/access/Ownable.sol



pragma solidity ^0.8.0;


/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _setOwner(_msgSender());
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _setOwner(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _setOwner(newOwner);
    }

    function _setOwner(address newOwner) private {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

// File: contracts/erc20.sol


pragma solidity ^0.8.2;

contract MyToken is ERC20, ERC20Burnable, Pausable, Ownable {
    constructor() ERC20("MyToken", "MTK") {
        _mint(msg.sender,1000e18);
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount)
        internal
        whenNotPaused
        override
    {
        super._beforeTokenTransfer(from, to, amount);
    }
}


// hardhat config.just




// require("dotenv").config();

// require("@nomiclabs/hardhat-etherscan");
// require("@nomiclabs/hardhat-waffle");
// require("hardhat-gas-reporter");
// require("solidity-coverage");
// require("@nomiclabs/hardhat-truffle5");

// // This is a sample Hardhat task. To learn how to create your own go to
// // https://hardhat.org/guides/create-task.html
// task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
//   const accounts = await hre.ethers.getSigners();

//   for (const account of accounts) {
//     console.log(account.address);
//   }
// });

// // You need to export an object to set up your config
// // Go to https://hardhat.org/config/ to learn more

// /**
//  * @type import('hardhat/config').HardhatUserConfig
//  */
// module.exports = {
//   defaultNetwork:"hardhat",
//   solidity: {
//     compilers: [
//       {
//         version: "0.6.6",
//         settings: {
//           optimizer: {
//             enabled: true,
//             runs: 200,
//           },
//           evmVersion: "istanbul",
//         },
//       },
//       {
//         version: "0.5.16",
//         settings: {
//           optimizer: {
//             enabled: true,
//             runs: 200,
//           },
//           evmVersion: "istanbul",
//         },
//       },
//       {
//         version: "0.4.18",
//         settings: {
//           optimizer: {
//             enabled: true,
//             runs: 200,
//           },
//           evmVersion: "istanbul",
//         },
//       },
//       {
//         version: "0.8.7",
//         settings: {
//           optimizer: {
//             enabled: true,
//             runs: 200,
//           },
//           evmVersion: "istanbul",
//         },
//       },
//     ],
//   },
//   networks: {
//     ropsten: {
//       url: process.env.ROPSTEN_URL || "",
//       accounts:
//         process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
//     },
//     ganache: {
//       url: 'http://ganache:8545',
//       accounts: {
//         mnemonic: 'tail actress very wool broom rule frequent ocean nice cricket extra snap',
//         path: " m/44'/60'/0'/0/",
//         initialIndex: 0,
//         count: 20,
//       },
//     },
//   },
//   gasReporter: {
//     enabled: process.env.REPORT_GAS !== undefined,
//     currency: "USD",
//   },
//   etherscan: {
//     apiKey: process.env.ETHERSCAN_API_KEY,
//   },
// };



















// test.js




// const {
//     expectEvent, // Assertions for emitted events
//     time,
//     expectRevert,
//   } = require("@openzeppelin/test-helpers");
//   var chai = require("chai");
//    var expect = chai.expect;
// //   const WateenSwapRouter = artifacts.require("WateenSwapRouter");
// //   const WateenSwapFactory = artifacts.require("WateenSwapFactory");
//   const WBNB = artifacts.require("WBNB");
//   const PancakeRouter = artifacts.require("PancakeRouter");
//   const PancakeFacotry = artifacts.require("PancakeFactory");
//   const TestToken = artifacts.require("MyToken");
//   const  LpPair = artifacts.require("PancakePair");
//   contract("NFT-Exchange", (accounts) => {
//     const zeroAddress = "0x0000000000000000000000000000000000000000";
//     const owner = accounts[0];
//     const feeAddress = accounts[1];
//     const testAccount1 = accounts[6];
//     const testAccount2 = accounts[7];
//     const testAccount3 = accounts[8];
//     const testAccount4 = accounts[9];
//     const testAccount5 = accounts[10];
//     const testAccount6 = accounts[11];
//     const testAccount7 = accounts[12];
//     before(async function () {
//         WETHinstance = await WBNB.new();
//         pancakeFactoryInstance = await PancakeFacotry.new(feeAddress);
//         pancakeRouterInstance = await PancakeRouter.new( pancakeFactoryInstance.address,WETHinstance.address);
//         tokenAinstance = await TestToken.new({
//             from:owner
//         });
//         tokenBinstance = await TestToken.new({
//             from:owner
//         });  

//         await pancakeFactoryInstance.setFeeTo(feeAddress, {from: feeAddress});
//     });
  
//     describe("add liquidity", () => {
//         let aQuantity = "1000000000000000000000";
//         let bQuantity = "100000000000000000000";


  
//         it("", async function () {
//             await tokenAinstance.mint(testAccount1,aQuantity, {
//                 from:owner
//             });
//             await tokenBinstance.mint(testAccount1,bQuantity, {
//                 from:owner
//             });

//             await tokenAinstance.approve(pancakeRouterInstance.address,aQuantity, {
//                 from:testAccount1
//             });
//             await tokenBinstance.approve(pancakeRouterInstance.address,bQuantity, {
//                 from:testAccount1
//             });

//             await pancakeRouterInstance.addLiquidity(
//                 tokenAinstance.address,
//                 tokenBinstance.address,
//                 aQuantity,
//                 bQuantity,
//                 0,
//                 0,
//                 testAccount1,
//                 testAccount1,{
//                     from: testAccount1
//                 }
//             )

//             let len = await pancakeFactoryInstance.allPairsLength();
//             let lpAddr = await pancakeFactoryInstance.allPairs(0);
//             const pairInstance = await LpPair.at(lpAddr);
            
//             let lpBalance = await pairInstance.balanceOf(testAccount1);
            
//             console.log("total Supply", Number(await pairInstance.totalSupply()));
//             console.log("adddress 1 Lp balance", Number( await pairInstance.balanceOf(testAccount1)));
//             console.log("adddress 2 Lp balance", Number( await pairInstance.balanceOf(testAccount2)));
//           let getReserve = await pairInstance.getReserves();
//             console.log("Get Reserve Token A", Number(getReserve[0]/1e18));
//             console.log("Get Reserve Token B", Number(getReserve[1]/1e18));
//             console.log("");
//             console.log("");
//             console.log("");
//         })

//         it("", async function () {
//             await tokenAinstance.mint(testAccount2,aQuantity, {
//                 from:owner
//             });
//             await tokenBinstance.mint(testAccount2,bQuantity, {
//                 from:owner
//             });

//             await tokenAinstance.approve(pancakeRouterInstance.address,aQuantity, {
//                 from:testAccount2
//             });
//             await tokenBinstance.approve(pancakeRouterInstance.address,bQuantity, {
//                 from:testAccount2
//             });
//             await pancakeRouterInstance.addLiquidity(
//                 tokenAinstance.address,
//                 tokenBinstance.address,
//                 aQuantity,
//                 bQuantity,
//                 0,
//                 0,
//                 testAccount2,
//                 testAccount2,{
//                     from: testAccount2
//                 }
//             )

//             let len = await pancakeFactoryInstance.allPairsLength();
//             let lpAddr = await pancakeFactoryInstance.allPairs(0);

//             const pairInstance = await LpPair.at(lpAddr);
            
//             let lpBalance = await pairInstance.balanceOf(testAccount2);
            
//             console.log("total Supply", Number(await pairInstance.totalSupply()));
//             console.log("adddress 1 Lp balance", Number( await pairInstance.balanceOf(testAccount1)));
//             console.log("adddress 2 Lp balance", Number( await pairInstance.balanceOf(testAccount2)));
//            let getReserve = await pairInstance.getReserves();
//             console.log("Get Reserve Token A", Number(getReserve[0]/1e18));
//             console.log("Get Reserve Token B", Number(getReserve[1]/1e18));
//             console.log("");
//             console.log("");
//             console.log("");
//         })


//         it("Swap", async function () {
//             let swapToken = "100000000000000000000";
//             await tokenAinstance.mint(testAccount3,swapToken, {
//                 from:owner
//             });
//             // await tokenBinstance.mint(testAccount2,bQuantity, {
//             //     from:owner
//             // });

//             await tokenAinstance.approve(pancakeRouterInstance.address,swapToken, {
//                 from:testAccount3
//             });
//             // await tokenBinstance.approve(pancakeRouterInstance.address,bQuantity, {
//             //     from:testAccount2
//             // });

//             await pancakeRouterInstance.swapExactTokensForTokens(
//                 swapToken,
//                 0,
//                 [tokenAinstance.address,tokenBinstance.address],
//                 testAccount2,
//                 testAccount2,{
//                     from: testAccount3
//                 }
//             )

//             let len = await pancakeFactoryInstance.allPairsLength();
//             let lpAddr = await pancakeFactoryInstance.allPairs(0);

//             const pairInstance = await LpPair.at(lpAddr);
            
//             console.log("total Supply", Number(await pairInstance.totalSupply()));
//             console.log("adddress 1 Lp balance", Number( await pairInstance.balanceOf(testAccount1)));
//             console.log("adddress 2 Lp balance", Number( await pairInstance.balanceOf(testAccount2)));
//          let getReserve = await pairInstance.getReserves();
//             console.log("Get Reserve Token A", Number(getReserve[0]/1e18));
//             console.log("Get Reserve Token B", Number(getReserve[1]/1e18));
//             console.log("");
//             console.log("");
//             console.log("");
//         })

//         it("Swap", async function () {
//             let swapToken = "500000000000000000000";
//             // await tokenAinstance.mint(testAccount3,swapToken, {
//             //     from:owner
//             // });
//             await tokenBinstance.mint(testAccount3,swapToken, {
//                 from:owner
//             });

//             // await tokenAinstance.approve(pancakeRouterInstance.address,swapToken, {
//             //     from:testAccount3
//             // });
//             await tokenBinstance.approve(pancakeRouterInstance.address,swapToken, {
//                 from:testAccount3
//             });

//             await pancakeRouterInstance.swapExactTokensForTokens(
//                 swapToken,
//                 0,
//                 [tokenBinstance.address,tokenAinstance.address],
//                 testAccount2,
//                 testAccount2,{
//                     from: testAccount3
//                 }
//             )

//             let len = await pancakeFactoryInstance.allPairsLength();
//             let lpAddr = await pancakeFactoryInstance.allPairs(0);

//             const pairInstance = await LpPair.at(lpAddr);
            
//             console.log("total Supply", Number(await pairInstance.totalSupply()));
//             console.log("adddress 1 Lp balance", Number( await pairInstance.balanceOf(testAccount1)));
//             console.log("adddress 2 Lp balance", Number( await pairInstance.balanceOf(testAccount2)));
//            let getReserve = await pairInstance.getReserves();
//             console.log("Get Reserve Token A", Number(getReserve[0]/1e18));
//             console.log("Get Reserve Token B", Number(getReserve[1]/1e18));
//             console.log("");
//             console.log("");
//             console.log("");
//         })


//         it("Add Liquidty", async function () {
//             let token = "10000000000000000000";

//             let lpAddr = await pancakeFactoryInstance.allPairs(0);

//             const pairInstance = await LpPair.at(lpAddr);
//             console.log("Fee Addresss Lp Balance",Number(await pairInstance.balanceOf(feeAddress)));
//             console.log("");
//             console.log("");
//             console.log("");



//             await tokenAinstance.mint(testAccount5,token, {
//                 from:owner
//             });
//             await tokenBinstance.mint(testAccount5,token, {
//                 from:owner
//             });

//             await tokenAinstance.approve(pancakeRouterInstance.address,token, {
//                 from:testAccount5
//             });
//             await tokenBinstance.approve(pancakeRouterInstance.address,token, {
//                 from:testAccount5
//             });

//             await pancakeRouterInstance.addLiquidity(
//                 tokenAinstance.address,
//                 tokenBinstance.address,
//                 token,
//                 token,
//                 0,
//                 0,
//                 testAccount5,
//                 testAccount5,{
//                     from: testAccount5
//                 }
//             )

//             let len = await pancakeFactoryInstance.allPairsLength();

            
//             let lpBalance = await pairInstance.balanceOf(testAccount5);
            
//             console.log("total Supply", Number(await pairInstance.totalSupply()));
//             console.log("adddress 1 Lp balance", Number( await pairInstance.balanceOf(testAccount1)));
//             console.log("adddress 2 Lp balance", Number( await pairInstance.balanceOf(testAccount2)));
//             console.log("adddress 2 Lp balance", Number( await pairInstance.balanceOf(testAccount5)));
//             let getReserve = await pairInstance.getReserves();
//             console.log("Get Reserve Token A", Number(getReserve[0]/1e18));
//             console.log("Get Reserve Token B", Number(getReserve[1]/1e18));
//             console.log("Fee Addresss Lp Balance",Number(await pairInstance.balanceOf(feeAddress)));
//             console.log("");
//             console.log("");
//             console.log("");
//         })

//         it("Remove LP", async function () {
//             let token = "10000000000000000000";

//             let lpAddr = await pancakeFactoryInstance.allPairs(0);

//             const pairInstance = await LpPair.at(lpAddr);
//             console.log("Fee Addresss Lp Balance",Number(await pairInstance.balanceOf(feeAddress)));
//             console.log("");
//             console.log("");
//             console.log("");

//             let lpBal= await pairInstance.balanceOf(testAccount1);

//             await pairInstance.approve(pancakeRouterInstance.address,lpBal, {
//                 from:testAccount1
//             });

//             // await tokenBinstance.approve(pancakeRouterInstance.address,token, {
//             //     from:testAccount5
//             // });

//             await pancakeRouterInstance.removeLiquidity(
//                 tokenAinstance.address,
//                 tokenBinstance.address,
//                 lpBal,
//                 0,
//                 0,
//                 testAccount1,
//                 testAccount1,{
//                     from: testAccount1
//                 }
//             )

//             let len = await pancakeFactoryInstance.allPairsLength();

            
//             let lpBalance = await pairInstance.balanceOf(testAccount5);
            
//             console.log("total Supply", Number(await pairInstance.totalSupply()));
//             console.log("adddress 1 Lp balance", Number( await pairInstance.balanceOf(testAccount1)));
//             console.log("adddress 2 Lp balance", Number( await pairInstance.balanceOf(testAccount2)));
//             console.log("adddress 2 Lp balance", Number( await pairInstance.balanceOf(testAccount5)));
//             let getReserve = await pairInstance.getReserves();
//             console.log("Get Reserve Token A", Number(getReserve[0]/1e18));
//             console.log("Get Reserve Token B", Number(getReserve[1]/1e18));
//             console.log("Fee Addresss Lp Balance",Number(await pairInstance.balanceOf(feeAddress)));
//             console.log("");
//             console.log("");
//             console.log("");
//         })

//         it("Remove LP", async function () {
//             let token = "10000000000000000000";

//             let lpAddr = await pancakeFactoryInstance.allPairs(0);

//             const pairInstance = await LpPair.at(lpAddr);
//             console.log("Fee Addresss Lp Balance",Number(await pairInstance.balanceOf(feeAddress)));
//             console.log("");
//             console.log("");
//             console.log("");

//             let lpBal= await pairInstance.balanceOf(testAccount2);

//             await pairInstance.approve(pancakeRouterInstance.address,lpBal, {
//                 from:testAccount2
//             });

//             // await tokenBinstance.approve(pancakeRouterInstance.address,token, {
//             //     from:testAccount5
//             // });

//             await pancakeRouterInstance.removeLiquidity(
//                 tokenAinstance.address,
//                 tokenBinstance.address,
//                 lpBal,
//                 0,
//                 0,
//                 testAccount2,
//                 testAccount2,{
//                     from: testAccount2
//                 }
//             )

//             let len = await pancakeFactoryInstance.allPairsLength();

            
//             let lpBalance = await pairInstance.balanceOf(testAccount5);
            
//             console.log("total Supply", Number(await pairInstance.totalSupply()));
//             console.log("adddress 1 Lp balance", Number( await pairInstance.balanceOf(testAccount1)));
//             console.log("adddress 2 Lp balance", Number( await pairInstance.balanceOf(testAccount2)));
//             console.log("adddress 2 Lp balance", Number( await pairInstance.balanceOf(testAccount5)));
//             let getReserve = await pairInstance.getReserves();
//             console.log("Get Reserve Token A", Number(getReserve[0]/1e18));
//             console.log("Get Reserve Token B", Number(getReserve[1]/1e18));
//             console.log("Fee Addresss Lp Balance",Number(await pairInstance.balanceOf(feeAddress)));
//             console.log("");
//             console.log("");
//             console.log("");
//         })

//         it("Remove LP3", async function () {
//             let token = "10000000000000000000";

//             let lpAddr = await pancakeFactoryInstance.allPairs(0);

//             const pairInstance = await LpPair.at(lpAddr);
//             console.log("Fee Addresss Lp Balance",Number(await pairInstance.balanceOf(feeAddress)));
//             console.log("");
//             console.log("");
//             console.log("");

//             let lpBal= await pairInstance.balanceOf(testAccount5);

//             await pairInstance.approve(pancakeRouterInstance.address,lpBal, {
//                 from:testAccount5
//             });

//             // await tokenBinstance.approve(pancakeRouterInstance.address,token, {
//             //     from:testAccount5
//             // });

//             await pancakeRouterInstance.removeLiquidity(
//                 tokenAinstance.address,
//                 tokenBinstance.address,
//                 lpBal,
//                 0,
//                 0,
//                 testAccount5,
//                 testAccount5,{
//                     from: testAccount5
//                 }
//             )

//             let len = await pancakeFactoryInstance.allPairsLength();

            
//             let lpBalance = await pairInstance.balanceOf(testAccount5);
            
//             console.log("total Supply", Number(await pairInstance.totalSupply()));
//             console.log("adddress 1 Lp balance", Number( await pairInstance.balanceOf(testAccount1)));
//             console.log("adddress 2 Lp balance", Number( await pairInstance.balanceOf(testAccount2)));
//             console.log("adddress 2 Lp balance", Number( await pairInstance.balanceOf(testAccount5)));
//             let getReserve = await pairInstance.getReserves();
//             console.log("Get Reserve Token A", Number(getReserve[0]/1e18));
//             console.log("Get Reserve Token B", Number(getReserve[1]/1e18));
//             console.log("Fee Addresss Lp Balance",Number(await pairInstance.balanceOf(feeAddress)));
//             console.log("");
//             console.log("");
//             console.log("");
//         })

//         it("Remove LP FeeAddress", async function () {
//             let token = "10000000000000000000";

//             let lpAddr = await pancakeFactoryInstance.allPairs(0);

//             const pairInstance = await LpPair.at(lpAddr);
//             console.log("Fee Addresss Lp Balance",Number(await pairInstance.balanceOf(feeAddress)));
//             console.log("");
//             console.log("");
//             console.log("");

//             let lpBal= await pairInstance.balanceOf(feeAddress);

//             await pairInstance.approve(pancakeRouterInstance.address,lpBal, {
//                 from:feeAddress
//             });

//             // await tokenBinstance.approve(pancakeRouterInstance.address,token, {
//             //     from:testAccount5
//             // });

//             await pancakeRouterInstance.removeLiquidity(
//                 tokenAinstance.address,
//                 tokenBinstance.address,
//                 lpBal,
//                 0,
//                 0,
//                 feeAddress,
//                 feeAddress,{
//                     from: feeAddress
//                 }
//             )

//             let len = await pancakeFactoryInstance.allPairsLength();

            
//             let lpBalance = await pairInstance.balanceOf(testAccount5);
            
//             console.log("total Supply", Number(await pairInstance.totalSupply()));
//             console.log("adddress 1 Lp balance", Number( await pairInstance.balanceOf(testAccount1)));
//             console.log("adddress 2 Lp balance", Number( await pairInstance.balanceOf(testAccount2)));
//             console.log("adddress 2 Lp balance", Number( await pairInstance.balanceOf(testAccount5)));
//             let getReserve = await pairInstance.getReserves();
//             console.log("Get Reserve Token A", Number(getReserve[0]));
//             console.log("Get Reserve Token B", Number(getReserve[1]));
//             console.log("Fee Addresss Lp Balance",Number(await pairInstance.balanceOf(feeAddress)));
//             console.log("Fee A Balance", Number(await tokenAinstance.balanceOf(feeAddress)));
//             console.log("Fee A Balance", Number(await tokenBinstance.balanceOf(feeAddress)));
//        console.log("");
//             console.log("");
//             console.log("");
//         })
//     })
  
//   })