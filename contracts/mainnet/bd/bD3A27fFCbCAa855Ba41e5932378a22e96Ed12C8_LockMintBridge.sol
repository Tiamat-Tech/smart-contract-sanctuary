// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;
pragma abicoder v2;

import "./interfaces/HandleToken.sol";
import "./Bridge.sol";

/*                                                *\
 *                ,.-"""-.,                       *
 *               /   ===   \                      *
 *              /  =======  \                     *
 *           __|  (o)   (0)  |__                  *
 *          / _|    .---.    |_ \                 *
 *         | /.----/ O O \----.\ |                *
 *          \/     |     |     \/                 *
 *          |                   |                 *
 *          |                   |                 *
 *          |                   |                 *
 *          _\   -.,_____,.-   /_                 *
 *      ,.-"  "-.,_________,.-"  "-.,             *
 *     /          |       |  ╭-╮     \            *
 *    |           l.     .l  ┃ ┃      |           *
 *    |            |     |   ┃ ╰━━╮   |           *
 *    l.           |     |   ┃ ╭╮ ┃  .l           *
 *     |           l.   .l   ┃ ┃┃ ┃  | \,         *
 *     l.           |   |    ╰-╯╰-╯ .l   \,       *
 *      |           |   |           |      \,     *
 *      l.          |   |          .l        |    *
 *       |          |   |          |         |    *
 *       |          |---|          |         |    *
 *       |          |   |          |         |    *
 *       /"-.,__,.-"\   /"-.,__,.-"\"-.,_,.-"\    *
 *      |            \ /            |         |   *
 *      |             |             |         |   *
 *       \__|__|__|__/ \__|__|__|__/ \_|__|__/    *
\*                                                 */

contract LockMintBridge is Bridge {
    function deposit(
        address token,
        uint256 amount,
        uint256 toId
    ) external override hasSigner depositsToken(token, amount, toId) {
        IHandleToken(token).transferFrom(msg.sender, address(this), amount);
    }

    function withdraw(
        address recipient,
        address token,
        uint256 amount,
        uint256 nonce,
        uint256 fromId,
        bytes memory signature
    )
        external
        override
        hasSigner
        withdrawsToken(recipient, token, amount, nonce, fromId, signature)
    {
        IHandleToken erc20 = IHandleToken(token);
        // Mint tokens if contract does not hold enough.
        ensureAmount(erc20, amount);
        // Transfer tokens owned by bridge to user.
        erc20.transfer(msg.sender, amount);
    }

    function ensureAmount(IHandleToken erc20, uint256 amount) private {
        address selfAddress = address(this);
        uint256 selfBalance = erc20.balanceOf(selfAddress);
        if (selfBalance < amount) erc20.mint(selfAddress, amount - selfBalance);
    }
}