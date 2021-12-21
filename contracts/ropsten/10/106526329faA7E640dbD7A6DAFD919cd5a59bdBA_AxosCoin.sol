//SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

/// @title Stable coin smart contract implementation for Axx Coin
/// @notice ERC20 smartcontract for Axx stable coin
contract AxosCoin is ERC20, Ownable, AccessControl {
  // keccak hash for role will be used for role validations
  bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
  bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

  constructor(string memory _token, string memory _symbol)
    ERC20(_token, _symbol)
  {
    // Deployer will be default admin role
    _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
  }

  /// @notice Mints tokens against recipient
  /// @param recipient Wallet address of recipient
  /// @param amount Amount to mint
  function mint(address recipient, uint256 amount) public {
    // Check if caller has minter role
    require(
      hasRole(MINTER_ROLE, _msgSender()),
      "ERC20: Caller is not a minter"
    );
    // Mint tokens
    _mint(recipient, amount);
  }

  /// @notice Changes default decimal 18 to 6
  /// @return decimal value
  function decimals() public view virtual override returns (uint8) {
    return 6;
  }
}