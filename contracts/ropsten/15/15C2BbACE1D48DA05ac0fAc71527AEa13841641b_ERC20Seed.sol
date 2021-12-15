// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract ERC20Seed is ERC20PresetMinterPauser {
    using SafeMath for uint256;

    mapping(address => uint256) public totalMinted;

    // Addresses that are whitelisted to receive transfers even when (only) transfers paused
    // Needed for potential bridging
    mapping(address => bool) public whitelistedTo;

    // Separate transferPaused flag that prevents only transfers (except to whitelistedTo addresses)
    // since we want to allow minting & burning when paused
    bool public areTransfersPaused;

    constructor(string memory name, string memory symbol)
        ERC20PresetMinterPauser(name, symbol)
    {
        areTransfersPaused = true;
    }

    modifier onlyAdmin() {
        require(
            hasRole(DEFAULT_ADMIN_ROLE, _msgSender()),
            "Only default admin"
        );
        _;
    }

    // Only pauses transfers (allows minting & burning)
    function pauseTransfers() external onlyAdmin {
        areTransfersPaused = true;
    }

    // Only un-pauses transfers (allows minting & burning)
    // The global pause is still in effect
    function unPauseTransfers() external onlyAdmin {
        areTransfersPaused = false;
    }

    function setWhitelistedTo(address _to, bool _whitelisted)
        external
        onlyAdmin
    {
        whitelistedTo[_to] = _whitelisted;
    }

    function mint(address to, uint256 amount) public virtual override {
        require(
            hasRole(MINTER_ROLE, _msgSender()),
            "Access: minter role needed"
        );
        _mint(to, amount);
        totalMinted[to] = totalMinted[to].add(amount);
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual override {
        require(
            !areTransfersPaused || whitelistedTo[recipient],
            "Transfers are paused"
        );

        super._transfer(sender, recipient, amount);
    }
}