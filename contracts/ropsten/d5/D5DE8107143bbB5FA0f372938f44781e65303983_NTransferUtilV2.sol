/* solhint-disable */

// Neptune Mutual Protocol (https://neptunemutual.com)
// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.0;
import "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-solidity/contracts/token/ERC20/utils/SafeERC20.sol";

library NTransferUtilV2 {
  using SafeERC20 for IERC20;

  function ensureTransfer(
    IERC20 malicious,
    address recipient,
    uint256 amount
  ) external {
    // @suppress-address-trust-issue The address `malicious` can't be trusted and therefore we are ensuring that it does not act funny.
    // @suppress-address-trust-issue The address `recipient` can be trusted as we're not treating (or calling) it as a contract.

    require(recipient != address(0), "Invalid recipient");
    require(amount > 0, "Invalid transfer amount");

    uint256 pre = malicious.balanceOf(recipient);
    malicious.safeTransfer(recipient, amount);

    uint256 post = malicious.balanceOf(recipient);

    // slither-disable-next-line incorrect-equality
    require(post - pre == amount, "Invalid transfer");
  }

  function ensureTransferFrom(
    IERC20 malicious,
    address sender,
    address recipient,
    uint256 amount
  ) external {
    // @suppress-address-trust-issue The address `malicious` can't be trusted and therefore we are ensuring that it does not act funny.
    // @suppress-address-trust-issue The address `recipient` can be trusted as we're not treating (or calling) it as a contract.
    require(recipient != address(0), "Invalid recipient");
    require(amount > 0, "Invalid transfer amount");

    uint256 pre = malicious.balanceOf(recipient);
    malicious.safeTransferFrom(sender, recipient, amount);
    uint256 post = malicious.balanceOf(recipient);

    // slither-disable-next-line incorrect-equality
    require(post - pre == amount, "Invalid transfer");
  }
}