// SPDX-License-Identifier: MIT

pragma solidity =0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

contract MockCurveSwap {
    using SafeERC20 for IERC20;

    address[] public coins;
    int256 private flag;

    // Rinkeby
    // address public dai = 0x5592EC0cfb4dbc12D3aB100b257153436a1f0FEa;
    // address public usdc = 0x4DBCdF9B62e891a7cec5A2568C3F4FAF9E8Abe2b;
    // address public usdt = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    // address public eth = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    // address public stETH = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;
    // Ropsten
    address public dai = 0x31F42841c2db5173425b5223809CF3A38FEde360;
    address public usdc = 0x07865c6E87B9F70255377e024ace6630C1Eaa37F;
    address public usdt = 0x110a13FC3efE6A245B50102D2d79B3E76125Ae83;
    address public eth = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address public stETH = 0x90B15EC7EaEF2B0106A1F63c4eBb51572723d970;

    constructor(int256 _flag) public {
        // 3pool
        if (_flag == 0) {
            // dai Decimals 18
            // coins.push(0x6B175474E89094C44Da98b954EedeAC495271d0F);
            coins.push(dai); // compound testnet dai
            // usdc Decimals 6
            // coins.push(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
            coins.push(usdc); // compound testnet usdc
            // usdt Decimals 6
            coins.push(usdt);
        }

        // steth pool
        if (_flag == 1) {
            // eth
            coins.push(eth);
            // stETH
            coins.push(stETH);
        }

        flag = _flag;
    }

    function get_virtual_price() public view returns (uint256) {
        if (flag == 0) {
            // 3pool
            return 1018866463172349805;
        }

        // steth pool
        if (flag == 1) {
            return 1022271091125736664;
        }
    }

    function calc_withdraw_one_coin(uint256 tokenAmount, int128 tokenId)
        public
        view
        returns (uint256)
    {
        if (flag == 0) {
            if (tokenId == 0) {
                return (tokenAmount * 1e18) / 981778883539993100;
            }

            if (tokenId == 1) {
                return (tokenAmount * 1e18) / 981219459544321700000000000000;
            }

            if (tokenId == 2) {
                return (tokenAmount * 1e18) / 981365065980278300000000000000;
            }
        }

        if (flag == 1) {
            if (tokenId == 0) {
                return (tokenAmount * 1e18) / 984051122905618300;
            }

            if (tokenId == 1) {
                return (tokenAmount * 1e18) / 975056549775736200;
            }
        }
    }

    function remove_liquidity(
        uint256 _token_amount,
        uint256[] memory min_amounts
    ) public {
        // Not required for testing
    }

    // def remove_liquidity_one_coin(_token_amount: uint256, i: int128, min_amount: uint256)
    function remove_liquidity_one_coin(
        uint256 _token_amount,
        int128 i,
        uint256 min_amount
    ) public {
        uint256 amount = calc_withdraw_one_coin(_token_amount, i);
        // 3pool
        if (flag == 0) {
            if (i == 0) {
                IERC20(dai).safeTransfer(msg.sender, amount);
            }

            if (i == 1) {
                IERC20(usdc).safeTransfer(msg.sender, amount);
            }

            if (i == 2) {
                IERC20(usdt).safeTransfer(msg.sender, amount);
            }
        }

        // steth pool
        if (flag == 1) {
            if (i == 0) {
                msg.sender.transfer(amount);
            }

            if (i == 1) {
                IERC20(stETH).safeTransfer(msg.sender, amount);
            }
        }
    }
}