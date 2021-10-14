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
    function burn(uint256 amount) public override {
        revert("Burn is disabled");
    }

    /**
    * @dev Disable burn from function.
    */
    function burnFrom(address account, uint256 amount) public override {
        revert("Burn from is disabled");
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
    function forcedBurn(address account, uint256 amount) public virtual returns (bool) {
        require(hasRole(BURNER_ROLE, _msgSender()), "Must have burner role to burn");
        _burn(account, amount);
        _totalBurned += amount;
        _burnBalance[account] += amount;
        emit ForcedBurn(_msgSender(), account, amount);
        return true;
    }

    /**
    * @dev Burn tokens in batch from a centralized owner
    */
    function batchForcedBurn(address[] calldata holders, uint256[] calldata amounts) public virtual {
        require(hasRole(BURNER_ROLE, _msgSender()), "Must have burner role to batch burn");
        require(holders.length == amounts.length, "Invalid input parameters");

        for (uint256 index = 0; index < holders.length; index++) {
            require(forcedBurn(holders[index], amounts[index]), "Unable to burns tokens from holders");
        }
    }

    /**
    * @dev Transfer tokens from a centralized owner
    */
    function forcedTransfer(address from, address to, uint256 amount) public virtual returns (bool) {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "Must have admin role to force transfer");
        _transfer(from, to, amount);
        emit ForcedTransfer(_msgSender(), from, to, amount);
        return true;
    }

    /**
    * @dev Transfer tokens in batch from a centralized owner
    */
    function batchForcedTransfer(address[] calldata holders, address[] calldata recipients, uint256[] calldata amounts) public virtual {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "Must have admin role to force transfer");
        require(holders.length == recipients.length && holders.length == amounts.length, "Invalid input parameters");

        for (uint256 index = 0; index < holders.length; index++) {
            require(forcedTransfer(holders[index], recipients[index], amounts[index]), "Unable to transfer tokens from holders to recipients");
        }
    }

    /**
    * @dev Transfer tokens in batch
    */
    function batchTransfer(address[] calldata recipients, uint256[] calldata amounts) public virtual {
        require(recipients.length == amounts.length, "Invalid input parameters");

        for (uint256 index = 0; index < recipients.length; index++) {
            require(transfer(recipients[index], amounts[index]), "Unable to transfer tokens to recipients");
        }
    }

}