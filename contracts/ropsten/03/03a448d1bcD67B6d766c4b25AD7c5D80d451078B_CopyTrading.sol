// SPDX-License-Identifier: MIT
pragma solidity >=0.8.2;
pragma abicoder v2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";

import "hardhat/console.sol";

import "./AddressesLib.sol";
import "./Event.sol";
import "./Error.sol";

contract CopyTrading is AccessControl, ReentrancyGuard {
    using AddressesLib for address[];

    address public multiSigAccount;

    ISwapRouter public swapRouter;
    uint24 public constant poolFee = 3000;

    address[] public kolList;

    // kol => users
    mapping(address => address[]) private _followers;
    // user => kol list
    mapping(address => address[]) private _followings;
    // wallet => token => balances
    mapping(address => mapping(address => uint256)) private _balances;

    modifier onlyAdmin() {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), Error.ADMIN_ROLE_REQUIRED);
        _;
    }

    modifier onlyKOL(address _kol) {
        require(kolList.exists(_kol), Error.KOL_ROLE_REQUIRED);
        _;
    }

    constructor(address _multiSigAccount) {
        multiSigAccount = _multiSigAccount;
        renounceRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(DEFAULT_ADMIN_ROLE, _multiSigAccount);
    }

    function setSwapRouter(ISwapRouter _swapRouter) external onlyAdmin {
        swapRouter = _swapRouter;
    }

    function addKOL(address _kol) external onlyAdmin {
        require(!kolList.exists(_kol), Error.KOL_EXISTED);
        kolList.push(_kol);

        emit Event.AddKOL(_kol);
    }

    function removeKOL(address _kol) external onlyAdmin {
        require(kolList.exists(_kol), Error.KOL_NOT_EXISTED);
        kolList.remove(_kol);

        emit Event.RemoveKOL(_kol);
    }

    function follow(address _kol) external {
        require(kolList.exists(_kol), Error.KOL_NOT_EXISTED);

        _followings[_msgSender()].add(_kol);
        _followers[_kol].add(_msgSender());

        emit Event.Follow(_msgSender(), _kol);
    }

    function unFollow(address _kol) external {
        _followings[_msgSender()].remove(_kol);
        _followers[_kol].remove(_msgSender());

        emit Event.UnFollow(_msgSender(), _kol);
    }

    function swap(
        address _inputToken,
        address _outputToken,
        uint256 _amount
    ) external onlyKOL(_msgSender()) returns (uint256 amountOut) {
        require(IERC20(_inputToken).transferFrom(_msgSender(), address(this), _amount), Error.TRANSFER_FAILED);

        // Approve the router to spend input token.
        TransferHelper.safeApprove(_inputToken, address(swapRouter), _amount);

        // TODO: tính amount in theo số người follwers
        uint256 amountIn = _amount;
        address[] memory followers = _followers[_msgSender()];
        for (uint256 i = 0; i < followers.length; i++) {
            amountIn += _balances[followers[i]][_inputToken];
        }

        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: _inputToken,
            tokenOut: _outputToken,
            fee: poolFee,
            recipient: address(this),
            deadline: block.timestamp,
            amountIn: _amount,
            amountOutMinimum: 0, // TODO: tính tỉ lệ trượt giá
            sqrtPriceLimitX96: 0
        });

        amountOut = swapRouter.exactInputSingle(params);

        // TODO: chia số amount out theo tỉ lệ
        for (uint256 i = 0; i < followers.length; i++) {
            _balances[followers[i]][_outputToken] += (amountOut * _balances[followers[i]][_inputToken]) / amountIn;
            _balances[followers[i]][_inputToken] = 0;
        }
    }

    function deposit(address _token, uint256 _amount) external {
        require(IERC20(_token).transferFrom(_msgSender(), address(this), _amount), Error.TRANSFER_FAILED);

        _balances[_msgSender()][_token] += _amount;

        emit Event.Deposit(_msgSender(), _token, _amount);
    }

    function withdrawERC20(address _token, uint256 _amount) external nonReentrant {
        require(_balances[_msgSender()][_token] >= _amount, Error.TRANSFER_AMOUNT_EXCEEDS_BALANCE);

        require(IERC20(_token).transferFrom(address(this), _msgSender(), _amount), Error.TRANSFER_FAILED);

        _balances[_msgSender()][_token] -= _amount;

        emit Event.Withdrawn(_msgSender(), _token, _amount);
    }
}