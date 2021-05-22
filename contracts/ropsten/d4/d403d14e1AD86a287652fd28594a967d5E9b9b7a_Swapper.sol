pragma solidity 0.6.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "../token/ITenSetToken.sol";
import "../util/IERC20Query.sol";


contract Swapper is Ownable {

    using Address for address payable;
    using SafeERC20 for IERC20;

    mapping(bytes32 => bool) public finalizedTxs;
    address public token;
    address payable public feeWallet;
    uint256 public swapFee;

    event TokenSet(address indexed tokenAddr, string name, string symbol, uint8 decimals);
    event SwapStarted(address indexed tokenAddr, address indexed fromAddr, uint256 amount, uint256 feeAmount);
    event SwapFinalized(address indexed tokenAddr, bytes32 indexed otherTxHash, address indexed toAddress, uint256 amount);

    constructor(address payable _feeWallet) public {
        feeWallet = _feeWallet;
    }

    modifier notContract() {
        require(!msg.sender.isContract(), "contracts are not allowed to swap");
        require(msg.sender == tx.origin, "proxy contracts are not allowed");
       _;
    }

    function setSwapFee(uint256 fee) onlyOwner external {
        swapFee = fee;
    }

    function setFeeWallet(address payable newWallet) onlyOwner external {
        feeWallet = newWallet;
    }

    function setToken(address newToken) onlyOwner external returns (bool) {
        require(token != newToken, "already set");

        string memory name = IERC20Query(newToken).name();
        string memory symbol = IERC20Query(newToken).symbol();
        uint8 decimals = IERC20Query(newToken).decimals();

        token = newToken;

        emit TokenSet(token, name, symbol, decimals);
        return true;
    }

    function finalizeSwap(bytes32 otherTxHash, address toAddress, uint256 amount) onlyOwner external returns (bool) {
        require(!finalizedTxs[otherTxHash], "tx filled already");

        finalizedTxs[otherTxHash] = true;
        IERC20(token).safeTransfer(toAddress, amount);

        emit SwapFinalized(token, otherTxHash, toAddress, amount);
        return true;
    }

    function startSwap(uint256 amount) notContract payable external returns (bool) {
        require(msg.value == swapFee, "wrong swap fee");
        uint256 netAmount = ITenSetToken(token).tokenFromReflection(ITenSetToken(token).reflectionFromToken(amount, true));
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        if (msg.value > 0) {
            feeWallet.transfer(msg.value);
        }

        emit SwapStarted(token, msg.sender, netAmount, msg.value);
        return true;
    }
}