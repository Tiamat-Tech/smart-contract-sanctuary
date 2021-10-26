// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "./interfaces/IBuyback.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

contract Buyback is IBuyback, Ownable, Pausable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    IRouter public override router;
    IReserve public override reserve;

    address public override money;

    mapping(address => uint256) public override tokenTreasury;

    event UpdateReserve(address _reserve);
    event UpdateRouter(address _router);
    event UpdateMoney(address _money);

    event TransferMoneyToReserve(uint256 toTransfer);
    event TokenDeposit(address _token, uint256 _deposit);

    modifier isInitialised() {
        require(address(reserve) != address(0), "ERR_BUYBACK_NOT_SET");
        _;
    }

    constructor(address _router, address _money) public {
        require(
            _router != address(0),
            "Buyback:constructor:: ERR_ZERO_ADDRESS_ROUTER"
        );
        require(
            _money != address(0),
            "Buyback:constructor:: ERR_ZERO_ADDRESS_MONEY"
        );

        router = IRouter(_router);
        money = _money;
    }

    function setReserve(address _newAddress) external override onlyOwner {
        require(
            _newAddress != address(0),
            "Buyback:setReserve:: ERR_ZERO_ADDR"
        );
        reserve = IReserve(_newAddress);
        emit UpdateReserve(_newAddress);
    }

    function updateMoney(address _newAddress) external override onlyOwner {
        require(
            _newAddress != address(0),
            "Buyback:updateMoney:: ERR_ZERO_ADDR"
        );
        money = _newAddress;
        emit UpdateMoney(_newAddress);
    }

    function updateRouter(address _newAddress) external override onlyOwner {
        require(
            _newAddress != address(0),
            "Buyback:updateRouter:: ERR_ZERO_ADDR"
        );
        router = IRouter(_newAddress);
        emit UpdateRouter(_newAddress);
    }

    function deposit(address _token, uint256 _deposit)
        external
        override
        returns (bool)
    {
        require(
            _token != address(0),
            "Buyback:deposit:: ERR_ZERO_ADDRESS_MONEY"
        );

        tokenTreasury[_token] = tokenTreasury[_token].add(_deposit);
        IERC20(_token).safeTransferFrom(msg.sender, address(this), _deposit);

        emit TokenDeposit(_token, _deposit);
        return true;
    }

    function buyMoney(
        uint256 amountIn,
        uint256 minOut,
        address token,
        address[] memory path
    )
        external
        payable
        override
        onlyOwner
        whenNotPaused
        isInitialised
        returns (uint256 amountOut)
    {
        require(
            token != address(0),
            "Buyback:buyMoney:: ERR_INVALID_TOKEN_ADDRESS"
        );
        require(path.length != 0, "Buyback:buyMoney:: ERR_INVALID_PATH");
        require(
            path[path.length - 1] != path[0],
            "Buyback:buyMoney:: ERR_SAME_TOKEN_SWAP"
        );

        uint256 toSwap = amountIn == uint256(-1)
            ? tokenTreasury[token]
            : amountIn;

        tokenTreasury[token] = tokenTreasury[token].sub(toSwap);

        IERC20(token).approve(address(router), toSwap);
        amountOut = _swap(toSwap, path, minOut);

        //reserve stores balances hence deposit will check if the actual balance is more by amountOut in reserve
        reserve.deposit(amountOut);

        emit TransferMoneyToReserve(amountOut);
    }

    function _swap(
        uint256 _amountIn,
        address[] memory _path,
        uint256 _minOut
    ) internal returns (uint256) {
        uint256[] memory amountOut = router.swapExactTokensForETH(
            _amountIn,
            _minOut,
            _path,
            address(reserve),
            block.timestamp
        );

        return amountOut[0];
    }

    function transferMoneyToReserve()
        external
        override
        whenNotPaused
        isInitialised
    {
        uint256 toTransfer = tokenTreasury[money];
        tokenTreasury[money] = 0;
        require(
            toTransfer != 0,
            "Buyback:transferMoneyToReserve:: ERR_OUT_OF_BALANCE"
        );

        IERC20(money).safeTransfer(address(reserve), toTransfer);
        reserve.deposit(toTransfer);

        emit TransferMoneyToReserve(toTransfer);
    }
}