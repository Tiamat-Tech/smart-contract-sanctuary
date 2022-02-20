// SPDX-License-Identifier: MIT
pragma solidity =0.8.11;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract SPAACE is Ownable, ERC20, ERC20Burnable, ERC20Permit, ERC20Votes {
    using EnumerableSet for EnumerableSet.AddressSet;

    /**
     * @notice Raised when the owner begins the parameter unlock process, to allow community monitoring.
     *
     * @param timestamp When the parameters will be unlocked and able to be changed by the owner.
     */
    event NotifyParametersUnlockTimestamp(uint indexed timestamp);
    /**
     * @notice Raised when the owner re-locks the parameters.
     */
    event ParametersLocked();
    /**
     * @notice Raised when the owner enables transfer tax, to allow community monitoring.
     */
    event TaxEnabled();
    /**
     * @notice Raised when the owner disables transfer tax, to allow community monitoring.
     */
    event TaxDisabled();
    /**
     * @notice Raised when the owner enables true burning, to allow community monitoring.
     */
    event BurnEnabled();
    /**
     * @notice Raised when the owner disables true burning, to allow community monitoring.
     */
    event BurnDisabled();
    /**
     * @notice Raised when the owner changes the treasury address, to allow community monitoring.
     *
     * @param treasury The new treasury address.
     */
    event TreasuryAddressChanged(address indexed treasury);
    /**
     * @notice Raised when the owner changes the staking address, to allow community monitoring.
     *
     * @param staking The new staking address.
     */
    event StakingAddressChanged(address indexed staking);
    /**
     * @notice Raised when the owner excludes an address from transfer tax, to allow community monitoring.
     *
     * @param excluded The address that was excluded.
     */
    event ExcludedFromTax(address[] indexed excluded);
    /**
     * @notice Raised when the owner reincludes an address to transfer tax, to allow community monitoring.
     *
     * @param reincluded The address that was reincluded.
     */
    event ReincludedToTax(address[] indexed reincluded);
    /**
     * @notice Raised when the owner rescues stuck tokens mistakenly sent to the contract to allow community monitoring.
     *
     * @param token The address of the rescued token.
     * @param recipient Where the rescued tokens were sent.
     * @param amount The amount of tokens that were rescued.
     */
    event RescueTokens(IERC20 indexed token, address indexed recipient, uint amount);
    /**
     * @notice Raised when the owner rescues stuck ether mistakenly sent to the contract, to allow community monitoring.
     *
     * @param recipient Where the rescued tokens were sent.
     * @param amount The amount of ether that were rescued.
     */
    event RescueEther(address indexed recipient, uint amount);

    /**
     * @notice The timestamp at which parameters will be unlocked and changeable by the owner.
     *
     * If the owner has not requested a parameter unlock, this will be 0.
     */
    uint public parametersUnlockTimestamp;
    /**
     * @notice Whether tax on transfer for non-excluded addresses is enabled.
     */
    bool public taxEnabled = true;
    /**
     * @notice Whether true burning is enabled.
     */
    bool public burnEnabled;
    /**
     * @notice The treasury address to receive 50% of transfer tax (when enabled).
     */
    address public treasury;
    /**
     * @notice The staking address to receive 50% of transfer tax (when enabled).
     */
    address public staking;
    /**
     * @notice The set of addresses that are exempt from transfer tax.
     */
    EnumerableSet.AddressSet private excludedFromTax;

    /**
     * @notice Initialise the SPAACE token.
     *
     * Upon deployment, 1 billion (1,000,000,000) tokens will be sent to the deployer.
     * As this is the only location in the contract where the mint function is called, this is the maximum possible
     * supply of the token.
     *
     * Exclude the deployer, treasury and staking addresses from tax.
     *
     * @param treasury_ The treasury address to receive 50% of transfer tax (when enabled).
     * @param staking_ The staking address to receive 50% of transfer tax (when enabled).
     */
    constructor(address treasury_, address staking_) ERC20("SPAACE", "SPCE") ERC20Permit("SPAACE") {
        treasury = treasury_;
        staking = staking_;

        address[] memory exclude = new address[](3);

        exclude[0] = treasury_;
        exclude[1] = staking_;
        exclude[2] = _msgSender();

        _addExcluded(exclude);

        _mint(_msgSender(), 1_000_000_000 * 10**decimals());
    }

    /**
     * @notice Retrieve the set of addresses excluded from tax.
     * @return The set of addresses excluded from tax.
     */
    function excludedFromTaxAll() external view returns (address[] memory) {
        return excludedFromTax.values();
    }

    /**
     * @notice Retrieve a specific address excluded from tax.
     *
     * @param index The index of the address excluded from tax to retrieve.
     * @return The address excluded from tax at the specified index.
     */
    function excludedFromTaxAt(uint index) external view returns (address) {
        return excludedFromTax.at(index);
    }

    /**
     * @notice Retrieve the number of addresses excluded from tax.
     * @return The number of addresses excluded from tax.
     */
    function excludedFromTaxLength() external view returns (uint) {
        return excludedFromTax.length();
    }

    /**
     * @notice Determine wheter a specified address is excluded from tax.
     *
     * @param excluded The address of the potential excluded address.
     * @return Whether the address is excluded.
     */
    function isExcludedFromTax(address excluded) external view returns (bool) {
        return excludedFromTax.contains(excluded);
    }

    /**
     * @notice Add addresses to the set of addresses exempted from tax.
     *
     * @param excluded The addresses to exclude.
     */
    function addExcluded(address[] calldata excluded) external onlyOwner {
        _addExcluded(excluded);
    }

    /**
     * @notice Add addresses to the set of addresses exempted from tax.
     *
     * @param excluded The addresses to exclude.
     */
    function _addExcluded(address[] memory excluded) internal {
        for (uint i; i < excluded.length; ++i) {
            excludedFromTax.add(excluded[i]);
        }

        emit ExcludedFromTax(excluded);
    }

    /**
     * @notice Remove addresses from the set of addresses exempted from tax.
     *
     * @param reincluded The addresses to reinclude.
     */
    function removeExcluded(address[] calldata reincluded) external onlyOwner {
        for (uint i; i < reincluded.length; ++i) {
            excludedFromTax.remove(reincluded[i]);
        }

        emit ReincludedToTax(reincluded);
    }

    /**
     * @notice Start the process of unlocking the parameters. Parameters can be changed two days later.
     */
    function unlockParameters() external onlyOwner {
        uint unlockTimestamp = block.timestamp + 2 days;
        parametersUnlockTimestamp = unlockTimestamp;

        emit NotifyParametersUnlockTimestamp(unlockTimestamp);
    }

    /**
     * @notice Lock parameters from being changed. Takes effect immediately.
     */
    function lockParameters() external onlyOwner {
        parametersUnlockTimestamp = 0;

        emit ParametersLocked();
    }

    /**
     * @notice Modifier to prevent functions being called while parameters are locked.
     */
    modifier whenParametersUnlocked() {
        uint unlockTimestamp = parametersUnlockTimestamp;
        require(0 != unlockTimestamp, "Parameters not unlocked");
        require(block.timestamp >= unlockTimestamp, "Too early");
        _;
    }

    /**
     * @notice Enable tax on transfer for addresses that aren't excluded.
     */
    function enableTax() external onlyOwner whenParametersUnlocked {
        taxEnabled = true;

        emit TaxEnabled();
    }

    /**
     * @notice Disables tax on transfer.
     */
    function disableTax() external onlyOwner whenParametersUnlocked {
        taxEnabled = false;

        emit TaxDisabled();
    }

    /**
     * @notice Enables true burning (reduction in total supply).
     */
    function enableBurn() external onlyOwner whenParametersUnlocked {
        burnEnabled = true;

        emit BurnEnabled();
    }

    /**
     * @notice Disables true burning (reduction in total supply).
     */
    function disableBurn() external onlyOwner whenParametersUnlocked {
        burnEnabled = false;

        emit BurnDisabled();
    }

    /**
     * @notice Changes the treasury address to receive 50% of transfer tax (when enabled).
     *
     * @param treasury_ The new treasury address.
     */
    function changeTreasuryAddress(address treasury_) external onlyOwner whenParametersUnlocked {
        treasury = treasury_;

        emit TreasuryAddressChanged(treasury_);
    }

    /**
     * @notice Changes the staking address to receive 50% of transfer tax (when enabled).
     *
     * @param staking_ The new staking address.
     */
    function changeStakingAddress(address staking_) external onlyOwner whenParametersUnlocked {
        staking = staking_;

        emit StakingAddressChanged(staking_);
    }

    /**
     * @notice Send tokens mistakenly transferred to this contract to the owner.
     *
     * @dev Ensure you review the contract of the token to be rescued before calling this function.
     *
     * @param token Address of the token to rescue.
     */
    function rescueTokens(IERC20 token) external onlyOwner {
        uint balance = token.balanceOf(address(this));

        require(token.transfer(_msgSender(), balance), "Token transfer failed");

        emit RescueTokens(token, _msgSender(), balance);
    }

    /**
     * @notice Send ether mistakenly transferred to this contract to the owner.
     */
    function rescueEther() external onlyOwner {
        uint balance = address(this).balance;

        (bool sent, ) = _msgSender().call{ value: balance }("");
        require(sent, "Failed to send Ether");

        emit RescueEther(_msgSender(), balance);
    }

    /**
     * @dev Hook that is called after any transfer of tokens. This includes minting and burning.
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
        uint amount
    ) internal override(ERC20, ERC20Votes) {
        super._afterTokenTransfer(from, to, amount);
    }

    /** @dev Creates `amount` tokens and assigns them to `account`, increasing the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
    function _mint(address to, uint amount) internal override(ERC20, ERC20Votes) {
        super._mint(to, amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, reducing the total supply.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
     *
     * @notice Tokens can only be burnt if true burning is enabled.
     */
    function _burn(address account, uint amount) internal override(ERC20, ERC20Votes) {
        require(burnEnabled, "Burning disabled");
        super._burn(account, amount);
    }

    /**
     * @notice Moves `amount` of tokens from `sender` to `recipient`, applying transfer tax as appropriate.
     *
     * @param sender The sender of the tokens.
     * @param recipient The recipient of the tokens.
     * @param amount The amount to transfer (before tax).
     */
    function _transfer(
        address sender,
        address recipient,
        uint amount
    ) internal override {
        if (taxEnabled && !excludedFromTax.contains(sender) && !excludedFromTax.contains(recipient)) {
            uint tax = amount / 100;
            amount -= tax;
            uint tax1 = tax / 2;
            uint tax2 = tax - tax1;
            super._transfer(sender, treasury, tax1);
            super._transfer(sender, staking, tax2);
        }

        super._transfer(sender, recipient, amount);
    }
}