// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;
pragma abicoder v2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";

contract Vault {
    mapping(address => uint256) eth_balances;
    mapping(address => mapping(address => uint256)) erc20_balances;
    address payable weth_address;
    ISwapRouter public immutable swap_router;
    uint24 public constant pool_fee = 3000;

    constructor(address payable _weth_address, ISwapRouter _swap_router) {
        weth_address = _weth_address;
        swap_router = _swap_router;
    }

    function depositETH() public payable {
        eth_balances[msg.sender] += msg.value;
    }

    receive() external payable {
        if (msg.sender != weth_address) {
            depositETH();
        }
    }

    function getETHBalance(address addr) public view returns (uint256) {
        return eth_balances[addr];
    }

    function withdrawETH(uint256 withdraw_amount) public {
        require(
            eth_balances[msg.sender] >= withdraw_amount,
            "insufficient ETH balance"
        );

        // Decrement balance before transferring to prevent re-entrancy attacks.
        eth_balances[msg.sender] -= withdraw_amount;
        (bool success, ) = msg.sender.call{value: withdraw_amount}("");
        require(success, "ETH transfer failed");
    }

    function depositERC20(address token_addr, uint256 amount) public {
        require(
            IERC20(token_addr).transferFrom(msg.sender, address(this), amount),
            "ERC20 transfer failed"
        );
        erc20_balances[token_addr][msg.sender] += amount;
    }

    function withdrawERC20(address token_addr, uint256 amount) public {
        require(
            erc20_balances[token_addr][msg.sender] >= amount,
            "insufficient ERC20 balance"
        );
        erc20_balances[token_addr][msg.sender] -= amount;
        require(
            IERC20(token_addr).transfer(msg.sender, amount),
            "ERC20 transfer failed"
        );
    }

    function getERC20Balance(address token_addr, address owner_addr)
        public
        view
        returns (uint256)
    {
        return erc20_balances[token_addr][owner_addr];
    }

    function wrapETH(uint256 amount) public {
        require(eth_balances[msg.sender] >= amount, "insufficient ETH balance");
        eth_balances[msg.sender] -= amount;
        erc20_balances[weth_address][msg.sender] += amount;

        (bool success, ) = weth_address.call{value: amount}(
            abi.encodeWithSignature("deposit()")
        );
        require(success, "WETH deposit failed");
    }

    function unwrapETH(uint256 amount) public {
        require(
            erc20_balances[weth_address][msg.sender] >= amount,
            "insufficient WETH balance"
        );
        erc20_balances[weth_address][msg.sender] -= amount;
        eth_balances[msg.sender] += amount;

        (bool success, ) = weth_address.call(
            abi.encodeWithSignature("withdraw(uint256)", amount)
        );
        require(success, "WETH withdrawal failed");
    }

    function swapERC20s(
        address from_token,
        address to_token,
        uint256 from_amount,
        uint256 to_amount_min
    ) public returns (uint256) {
        require(
            erc20_balances[from_token][msg.sender] >= from_amount,
            "insufficient ERC20 balance"
        );
        erc20_balances[from_token][msg.sender] -= from_amount;

        // Approve the Uniswap router to spend the tokens owned by this contract.
        TransferHelper.safeApprove(
            from_token,
            address(swap_router),
            from_amount
        );

        // Construct swap parameters and make the swap.
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter
            .ExactInputSingleParams({
                tokenIn: from_token,
                tokenOut: to_token,
                fee: pool_fee,
                recipient: address(this),
                deadline: block.timestamp,
                amountIn: from_amount,
                amountOutMinimum: to_amount_min,
                sqrtPriceLimitX96: 0
            });

        uint256 to_amount = swap_router.exactInputSingle(params);
        erc20_balances[to_token][msg.sender] += to_amount;

        return to_amount;
    }
}