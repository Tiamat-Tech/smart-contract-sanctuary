// SPDX-icense-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/**
 * @title Coinsfast
 * @dev Coinsfast Token, where all tokens are pre-assigned to the creator.
 */

contract Coinsfast is ERC20PausableUpgradeable, OwnableUpgradeable {
	uint256 public whiteListCount;

	function initialize(string memory _name, string memory _symbol, uint256 _supply) public initializer {
		__ERC20_init(_name, _symbol);
		_mint(msg.sender, _supply * (10 ** uint256(decimals())));
	}

	/**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `recipient` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     * @param recipient The wallet address of the investor receiving the tokens
     * @param amount The amount of tokens being sent
     */
	function transfer(address recipient, uint256 amount) public virtual override whenNotPaused() returns (bool) {
		_beforeTokenTransfer(msg.sender, recipient, amount);
		_transfer(_msgSender(), recipient, amount);
		return true;
	}

	/**
     * @dev Triggers stopped state.
     *
     * Requirements:
     *
     * - The contract must not be paused and must be called by the owner.
     */
	function pause() public onlyOwner() {
		_pause();
	}

	/**
     * @dev Returns to normal state.
     *
     * Requirements:
     *
     * - The contract must be paused and must be called by the owner.
     */
	function unpause() public onlyOwner() {
		_unpause();
	}

	/**
    @dev List of checks before token transfers are allowed
    @param from The wallet address sending the tokens
    @param to The wallet address recieving the tokens
    @param amount The amount of tokens being transfered
   */
	function _beforeTokenTransfer(
		address from,
		address to,
		uint256 amount
	) internal override {
		require(!paused(), 'ERC20Pausable: token transfer while paused');
		require(amount > 0, 'Amount must not be 0');
	}

	///mapping of the addresses if it is whitelisted or not
	mapping(address => bool) public isWhiteListed;

	/***
     * @notice Check of an address is whitelisted
     * @param _address Address to be checked if whitelisted
     * @return Whether the address passed is whitelisted or not
     */
	function getWhiteListStatus(address _address) public view onlyOwner returns (bool) {
		return isWhiteListed[_address];
	}

	/***
     * @notice Add an address to the whitelist
     * @param _address The address to be added to the whitelist
     */
	function addWhiteList(address[] memory _address) public onlyOwner {
		for (uint256 i = 0; i < _address.length; i++) {
				isWhiteListed[_address[i]] = true;
				whiteListCount++;
				emit AddedWhiteList(_address[i]);
		}
	}

	/***
      * @notice Remove an address from the whitelist
      * @param _address The address to be removed from the whitelist
      */
	function removeWhiteList(address[] memory _address) public onlyOwner {
		for (uint256 i = 0; i < _address.length; i++) {
			if (isWhiteListed[_address[i]]) {
				isWhiteListed[_address[i]] = false;
				whiteListCount--;
				emit RemovedWhiteList(_address[i]);
			}
		}
	}

	event AddedWhiteList(address _address);
	event RemovedWhiteList(address _address);
}