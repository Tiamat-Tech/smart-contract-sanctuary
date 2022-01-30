// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/IPT.sol";
import "../interfaces/IArena.sol";
import "../interfaces/IToken.sol";

contract PT is IPT, ERC20, Ownable {
  // Tracks the last block that a caller has written to state.
  // Disallow some access to functions if they occur while a change is being written.
  mapping(address => uint256) private lastWrite;

  // reference to the Arena
    IArena public arena;
    // reference to Token contract
    IToken public token;
  
  constructor() ERC20("PT", "PT") { }

      modifier requireContractsSet() {
        require(
            address(arena) != address(0) && address(token) != address(0),"Contracts not set");
        _;
    }

    function setContracts(address _arena,address _token) external onlyOwner {
        arena = IArena(_arena);
        token = IToken(_token);
    }


  /**
   * mints $PT to a recipient
   * @param to the recipient of the $PT
   * @param amount the amount of $PT to mint
   */
  function mint(address to, uint256 amount) external override {
    require(_msgSender() == address(arena),"Only Arena Can Mint");
    _mint(to, amount);
  }

  /**
   * burns $PT from a holder
   * @param from the holder of the $PT
   * @param amount the amount of $PT to burn
   */
  function burn(address from, uint256 amount) external override {
    require(_msgSender() == address(token),"Only Token Contract Can Mint");
    _burn(from, amount);
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
  ) public virtual override(ERC20, IPT) disallowIfStateIsChanging returns (bool) {
      _transfer(sender, recipient, amount);
      return true;
  }

  /** SECURITEEEEEEEEEEEEEEEEE */

  modifier disallowIfStateIsChanging() {
    _;
  }

  function updateOriginAccess() external override {
    lastWrite[tx.origin] = block.number;
  }

  function balanceOf(address account) public view virtual override disallowIfStateIsChanging returns (uint256) {
    return super.balanceOf(account);
  }

  function transfer(address recipient, uint256 amount) public virtual override disallowIfStateIsChanging returns (bool) {
    return super.transfer(recipient, amount);
  }

  // Not ensuring state changed in this block as it would needlessly increase gas
  function allowance(address owner, address spender) public view virtual override returns (uint256) {
    return super.allowance(owner, spender);
  }

  // Not ensuring state changed in this block as it would needlessly increase gas
  function approve(address spender, uint256 amount) public virtual override returns (bool) {
    return super.approve(spender, amount);
  }

  // Not ensuring state changed in this block as it would needlessly increase gas
  function increaseAllowance(address spender, uint256 addedValue) public virtual override returns (bool) {
    return super.increaseAllowance(spender, addedValue);
  }

  // Not ensuring state changed in this block as it would needlessly increase gas
  function decreaseAllowance(address spender, uint256 subtractedValue) public virtual override returns (bool) {
    return super.decreaseAllowance(spender, subtractedValue);
  }


}