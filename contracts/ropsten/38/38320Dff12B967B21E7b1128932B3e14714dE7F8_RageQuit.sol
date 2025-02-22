// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Context.sol";

contract RageQuit is ReentrancyGuard, Context {
    using SafeERC20 for IERC20;

    IERC20 public immutable rageQuitToken; // gov token to burn
    address public immutable vault; // address of the vault where the tokens should be pulled from

    event RageQuited(address indexed leaver, uint256 indexed quitAmount, address[] tokens, uint256[] amounts);

    constructor(address _rageQuitToken, address _vault) {
        rageQuitToken = IERC20(_rageQuitToken);
        vault = _vault;
    }

    function rageQuit(uint256 _quitAmount, address[] calldata _tokens) external nonReentrant {
        // TODO burn tokens (or transfer them to 0x000....0 address)
        rageQuitToken.transferFrom(_msgSender(), vault, _quitAmount);

        uint256[] memory tokenAmounts = new uint256[](_tokens.length);

        for (uint256 i = 0; i < _tokens.length; i++) {
            require(_tokens[i] != address(rageQuitToken), "RageQuit.rageQuit: Cannot claim rageQuitToken");

            // Prevent same token from being claimed twice by making sure they are in order
            if (i != 0) {
                require(uint160(_tokens[i - 1]) < uint160(_tokens[i]), "RageQuit.rageQuit: Tokens out of order");
            }

            IERC20 token = IERC20(_tokens[i]);

            // calc proportional amount excluding rageQuitTokens in the vault before this tx started
            uint256 tokenAmount = (token.balanceOf(vault) * _quitAmount) /
                (rageQuitToken.totalSupply() - rageQuitToken.balanceOf(vault) + _quitAmount);
            tokenAmounts[i] = tokenAmount;

            token.safeTransferFrom(vault, _msgSender(), tokenAmount);
        }

        emit RageQuited(_msgSender(), _quitAmount, _tokens, tokenAmounts);
    }
}