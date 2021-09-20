// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";

contract ABCToken is ERC20PresetMinterPauser {

    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    mapping(address => uint256) private _burnBalance;

    uint256 private _totalBurned;

    string public info;

    event ForcedBurn(address requester, address account, uint256 amount);

    event ForcedTransfer(address requester, address from, address to, uint256 value);

    constructor(
        string memory _name, string memory _symbol, string memory _info
    ) ERC20PresetMinterPauser(_name, _symbol) {
        info = _info;
        _setupRole(BURNER_ROLE, _msgSender());
    }

    /**
     * @dev Disable burn function.
     */
    function burn() public virtual {
        revert("ERC20DisableFunctions: Burn is disabled");
    }

    /**
    * @dev Disable burn from function.
    */
    function burnFrom() public virtual {
        revert("ERC20DisableFunctions: Burn from is disabled");
    }

    /**
     * @dev Returns total tokens burned since contract start
     */
    function totalBurned() public view virtual returns (uint256) {
        return _totalBurned;
    }

    /**
     * @dev Returns the amount of burned tokens owned by `account`.
     */
    function burnBalanceOf(address account) public view virtual returns (uint256) {
        return _burnBalance[account];
    }

    /**
    * @dev Burn tokens from a centralized owner
    */
    function forcedBurn(address account, uint256 amount) public virtual {
        require(hasRole(BURNER_ROLE, _msgSender()), "ERC20PresetBurnBalance: must have burner role to burn");
        _burn(account, amount);
        _totalBurned += amount;
        _burnBalance[account] += amount;
        emit ForcedBurn(msg.sender, account, amount);
    }

    /**
    * @dev Transfer tokens from a centralized owner
    */
    function forcedTransfer(address from, address to, uint256 amount) public virtual {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "ERC20ForcedTransfer: must have admin role to force transfer");
        _transfer(from, to, amount);
        emit ForcedTransfer(msg.sender, from, to, amount);
    }

}