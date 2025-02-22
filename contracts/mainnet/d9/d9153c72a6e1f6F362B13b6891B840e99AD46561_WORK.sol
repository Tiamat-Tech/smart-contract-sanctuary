// SPDX-License-Identifier: MIT
//
// ██╗    ██╗ ██████╗ ██████╗ ██╗  ██╗
// ██║    ██║██╔═══██╗██╔══██╗██║ ██╔╝
// ██║ █╗ ██║██║   ██║██████╔╝█████╔╝
// ║██║███╗██║██║   ██║██╔══██╗██╔═██╗
// ╚███╔███╔╝╚██████╔╝██║  ██║██║  ██╗
// ╚╚══╝╚══╝  ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝
//
//                                      *%@@@#,
//                           @@@@@@@@@@@@@@@@@@@@@@@@@@@@%
//                      @@@@@@@...........&@&,,,,,,,,,,,,@@@@@@
//                  @@@@@,.......,..(@@@@@@@@@@@@@@&,,,,,,,,,,@@@@@
//               @@@@@@@[email protected]@@@@@@&&&&&&@@@&&&&&&&@@@@@@*,,,,*@@@@@@
//           @@@@[email protected]@@@@@@&&@@@&&&@@@@@@@@@@@&&&&&@%#&@@@@@@@****@@@%
//          @@@@[email protected]@@@&&&&&&&@@@@&&&&&@@@@@%####@@@@######@@@@@/****@@@@
//       @@@@.... @@@&&&&&@@@####@@&&&@@@/@(&@@###@@&&&@@@#####&@@@/****@@@%
//       @@@[email protected]@@&&&&@@@########%@&@@(**@(,,@@%@@&&&&&&&@@@#####@@@//***@@@
//     &@@,..,[email protected]@@&@@&@@(###########@@@****@#,,,@@@&&&&&&&&&&&@@@@@@(@@@****/@@/
//   @@@[email protected]@@&&&@@@@###########@@@@/**/@#,,/@@@@@&&&&&&&&&@@@@@(((&@@/****@@%
//   &@@@@@,&@@&&&&@@&&&@@(######@@@*,,@&//@#,@@,,,@@@&&&&&&@@%###@@(((#@@@*@@@@@(
//   @@%///(@@&&&&@@&&&&&&@@@###@@@,,,,,@@@@@@@,,,,,#@@@&&@@#######@@((((@@,[email protected]@@
//  @@@////@@&&&&@&&&&&&&&&&&@@@@@@@@@@@@@@@@@@@@@@@@@@@@&##########@@(((&@@[email protected]@@
//  @@&///%@@&&&@@&&&&&&&&&&@@@@@@%%%%%%##&@%%%%%%%%%@@@@@&##########@@(((@@*[email protected]@@
// (@@////@@@&&&@@&&&&&&&&&@@@(,@@%%%%&@@&///@@@%%%%#@@*@@@@#########@@#((@@@.../@@
// @@@////@@@@@@@@@@@@@@@@@@@,,,@@%%%@@@(/////(@@@#%%@@/**@@@@@@@@@@@@@%##@@@[email protected]@
// /@@////@@@##(@(#####(@@@#,,,,@@%%&@@(///////(@@#%%@@/****@@@&&&&&&@@###@@&.../@@
//  @@%///#@@###@@####%@@@@@@@@@@@@@@@@@&(/////(@@@@@@@@@@@@@@@@@&&&&@@###@@[email protected]@@
//  @@@////@@((##@##(@@@*,,,,,@@@@%%%@@&#&@@((/@@@%%%@@@@[email protected]@@&&@@###@@@[email protected]@@
//   @@@@@@@@@###%@@@@@,,,,,#@*/@@%%%%@@@(##%@@@%%%%%@@/*@@.....&@@@@####@@@@@@@@@
//   #@@,,,,@@@###@@@,,,,,,@&**/@@%%%%%%%&@@@%%%%%%%%@@***@@&[email protected]@@###@@,,,,@@@.
//   &@@*,,,@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@,,,,&@@/
//     (@@%,,,/@@@&&&&@@&&&&&&&&&&&@@######@&&&&&&@@&&&&&&&&&&&@@&&&&@@@,,,,@@@.
//       @@@,,,,@@@@&&&&@@@&&&&&&&@@######%@&&&&&&&@@&&&&&%&&@@&&&&@@@,,,,,@@@
//       %@@#,,,,@@@@&&&&&&@@@&&@@#######&@&&&&&&&&@@@&&@@@&&&&&@@@,,,,,@@@*
//          @@@(,,,,,@@@@@&&&&&&@@@@@@####@@&&&&&&@@@@@@&&&&&&@@@@,,,,,@@@%
//           #@@@,,,@@,@@@@@@&&@&&&&&&&&&@@@@&&&&&&&&&@@@@@@@(@@@,,,@@@,
//               @@@@&,,,,,,*@@@@@@@@&&&&&@@@&&&&&&@@@@@@%[email protected]@@@@
//                  @@@@@,,,,,,,,,,,(@@@@@@@@@@@@&...........(@@@@&
//                      @@@@@@&,,,,,,,,,,,@@&..........,@@@@@@&
//                           [email protected]@@@@@@@@@@@@@@@@@@@@@@@@@@

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/utils/Context.sol";

contract WORK is
    Context,
    AccessControlEnumerable,
    ERC20Burnable,
    ERC20Pausable
{
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    /**
     * @dev Grants `DEFAULT_ADMIN_ROLE`, `MINTER_ROLE` and `PAUSER_ROLE` to the
     * account set as `owner`.
     *
     * See {ERC20-constructor}.
     */
    constructor(
        string memory name,
        string memory symbol,
        address owner
    ) ERC20(name, symbol) {
        _mint(owner, 500000000 * 10**18);
        _setupRole(DEFAULT_ADMIN_ROLE, owner);
        _setupRole(MINTER_ROLE, owner);
        _setupRole(PAUSER_ROLE, owner);
    }

    /**
     * @dev Creates `amount` new tokens for `to`.
     *
     * See {ERC20-_mint}.
     *
     * Requirements:
     *
     * - the caller must have the `MINTER_ROLE`.
     */
    function mint(address to, uint256 amount) public virtual {
        require(
            hasRole(MINTER_ROLE, _msgSender()),
            "ERC20PresetMinterPauser: must have minter role to mint"
        );
        _mint(to, amount);
    }

    /**
     * @dev Pauses all token transfers.
     *
     * See {ERC20Pausable} and {Pausable-_pause}.
     *
     * Requirements:
     *
     * - the caller must have the `PAUSER_ROLE`.
     */
    function pause() public virtual {
        require(
            hasRole(PAUSER_ROLE, _msgSender()),
            "ERC20PresetMinterPauser: must have pauser role to pause"
        );
        _pause();
    }

    /**
     * @dev Unpauses all token transfers.
     *
     * See {ERC20Pausable} and {Pausable-_unpause}.
     *
     * Requirements:
     *
     * - the caller must have the `PAUSER_ROLE`.
     */
    function unpause() public virtual {
        require(
            hasRole(PAUSER_ROLE, _msgSender()),
            "ERC20PresetMinterPauser: must have pauser role to unpause"
        );
        _unpause();
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override(ERC20, ERC20Pausable) {
        super._beforeTokenTransfer(from, to, amount);
    }
}