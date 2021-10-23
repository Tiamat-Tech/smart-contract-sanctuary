// SPDX-License-Identifier: MIT
pragma solidity >=0.8.2 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";

contract DefiYieldToken is
    ERC20,
    ERC20Burnable,
    AccessControl,
    ERC20Permit,
    ERC20Votes
{
    /// @notice Define a name for a minter and whitelister roles
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BLACKLISTER_ROLE = keccak256("BLACKLISTER_ROLE");

    /**
     * @notice Timestamp after which minting will be allowed, but not often
     * then ones a year
     */
    uint256 public mintingAllowedAfter;

    /// @notice Minimal time between mints
    uint256 public delayBetweenMints;

    /// @notice To combat fraudulent activities
    mapping(address => bool) public blacklist;

    /// @notice When fraud activity detected
    event AddToBlacklist(address violator);

    /// @notice When user was blocked by mistake
    event RemoveFromBlacklist(address user);

    /// @notice When blacklister role burn black funds
    event DestroyBlackFunds(address violator, uint256 burnedAmount);

    constructor(uint256 _delayBetweenMints)
        ERC20("DefiYieldToken", "DFY")
        ERC20Permit("DefiYieldToken")
    {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(MINTER_ROLE, msg.sender);
        _setupRole(BLACKLISTER_ROLE, msg.sender);
        // Delay between minting is prohibited
        delayBetweenMints = _delayBetweenMints;
        // Disable minting for a one year
        _delayNextMinting();
        // Send initial supply to the deployer (1 Billion DFY)
        _mint(msg.sender, 1_000_000_000e18);
    }

    /**
     * @notice Stop evil user
     * @param violator - Address to ban
     */
    function addToBlacklist(address violator)
        external
        onlyRole(BLACKLISTER_ROLE)
    {
        blacklist[violator] = true;
        emit AddToBlacklist(violator);
    }

    /**
     * @notice In case a user have been blacklisted by mistake
     * @param user - Unblocked address
     */
    function removeFromBlacklist(address user)
        external
        onlyRole(BLACKLISTER_ROLE)
    {
        blacklist[user] = false;
        emit RemoveFromBlacklist(user);
    }

    /**
     * @notice Burn black funds
     * @param violator - Address with funds to burn
     */
    function destroyBlackFunds(address violator)
        external
        onlyRole(BLACKLISTER_ROLE)
    {
        require(blacklist[violator], "address is not blacklisted");
        uint256 amountToDestroy = balanceOf(violator);
        require(amountToDestroy > 0, "nothing to burn");
        _burn(violator, amountToDestroy);
        emit DestroyBlackFunds(violator, amountToDestroy);
    }

    /**
     * @notice Mint new tokens
     * @param to - Address where to send a tokens
     * @param amount - How much tokens to send
     */
    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        require(
            block.timestamp >= mintingAllowedAfter,
            "minting not allowed yet"
        );
        require(to != address(0), "cannot mint to the zero address");
        require(amount > 0, "cannot mint zero amount");
        _delayNextMinting();
        _mint(to, amount);
    }

    /// @notice Disable mint function for a year from now
    function _delayNextMinting() private {
        mintingAllowedAfter = block.timestamp + delayBetweenMints;
    }

    // The following functions are overrides required by Solidity.

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20) {
        // Blacklisted from only burn allowed
        if (to != address(0)) {
            require(!blacklist[from], "from address is blacklisted");
            require(!blacklist[to], "to address is blacklisted");
        }
        super._beforeTokenTransfer(from, to, amount);
    }

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20, ERC20Votes) {
        super._afterTokenTransfer(from, to, amount);
    }

    function _mint(address to, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._mint(to, amount);
    }

    function _burn(address account, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._burn(account, amount);
    }
}