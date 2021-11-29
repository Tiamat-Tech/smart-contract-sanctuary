pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IWETH.sol";
import "./MainProxy.sol";

/**
 * @title A vault contract for safe managment of deposited assets.
 * @notice A contract that tracks amount of assets (tokens and ether) deposited to the platform by the user and amount of assets locked in orders.
 * @dev Ether balances are kept in vaultBalances mapping and Ether amount is mapped to with the 0 address.
 */
contract Vault {
    using SafeERC20 for IERC20;

    address public mainProxy;
    MainProxy MainProxyInstance;

    address payable public weth;
    IWETH WETH;

    mapping(address => mapping(address => uint256)) internal vaultBalances;
    mapping(address => mapping(address => uint256)) internal inOrders;

    event Deposit(
        address from,
        address indexed to,
        address indexed asset,
        uint256 indexed amount
    );
    event Withdraw(
        address from,
        address indexed to,
        address indexed asset,
        uint256 indexed amount
    );
    event MovedToOrder(
        address user, // no need to index user, since this info can be retrieved from Main via orderHash
        address asset, // no need to index asset, since this info can be retrieved from Main via orderHash
        uint256 indexed amount,
        bytes32 indexed order
    );
    event MovedFromOrder(
        address user, // no need to index user, since this info can be retrieved from Main via orderHash
        address asset, // no need to index asset, since this info can be retrieved from Main via orderHash
        uint256 indexed amount,
        bytes32 indexed order
    );
    event FundsReleased(
        address user, // no need to index user, since this info can be retrieved from Main via orderHash
        address assetA, // no need to index asset, since this info can be retrieved from Main via orderHash
        uint256 indexed amountA,
        address indexed destination,
        bytes32 indexed orderHash
    );
    event FillExecuted(
        address user, // no need to index user, since this info can be retrieved from Main via orderHash
        address assetB, // no need to index asset, since this info can be retrieved from Main via orderHash
        uint256 indexed amountB,
        bytes32 indexed orderHash
    );
    event InternalMatchTransfer(
        bytes32 indexed orderA,
        bytes32 orderB, // no need to index second order
        uint256 indexed baseAmount,
        uint256 indexed quoteAmount
    ); // event doesn't contain baseToken and quoteToken addresses, since they can be retrieved via orderA hash and baseToken is always baseToken of orderA

    /**
     * @dev Constructs the Vault contract.
     * @param _mainProxy An address of the EIP1967 Upgradable Proxy for the Main.
     * @param _weth An address of Wrapped Ether contract.
     */
    constructor(address payable _mainProxy, address payable _weth) {
        mainProxy = _mainProxy;
        MainProxyInstance = MainProxy(_mainProxy);

        weth = _weth;
        WETH = IWETH(_weth);
    }

    // used for safe asset managment by the contracts ecosystem
    modifier onlyAllowed() {
        // sender must be either main proxy, current implementation or previous implementation that is a valid, non security risk version
        require(
            MainProxyInstance.isActiveImplementation(msg.sender) == true || msg.sender == mainProxy,
            "You are not allowed to call this function."
        );
        _;
    }

    /**
     * @notice Function called for depositing Ether. A value of the message will be the amount credited.
     * @param toUser An address of the account on the platform to which deposited Ether amount will be credited. In most cases this will be the sender.
     */
    function depositEther(address toUser) external payable {
        vaultBalances[toUser][address(0)] += msg.value;

        emit Deposit(msg.sender, toUser, address(0), msg.value);
    }

    /**
     * @notice Function called to withdraw Ether.
     * @dev The call will fail if vault balance of the sender is insufficient.
     * @param toAddress An address to which withdrawn Ether will be sent.
     * @param amount An amount of Ether to be withdrawn.
     */
    function withdrawEther(address payable toAddress, uint256 amount) external {
        require(
            amount <= vaultBalances[msg.sender][address(0)],
            "Insufficient amount of assets in vault."
        );

        vaultBalances[msg.sender][address(0)] -= amount;

        toAddress.transfer(amount);

        emit Withdraw(msg.sender, toAddress, address(0), amount);
    }

    /**
     * @notice Function called to deposit tokens. Sender must approve vault contract as a token spender for the amount to be deposited.
     * @dev The call will fail if token balance of the sender is insufficient or if approval for the vault contract is insufficient.
     * @param token An address of the token to be deposited.
     * @param amount An amount of token to be deposited.
     * @param toUser An address of the platform user to whom the funds will be credited.
     */
    function depositToken(
        address token,
        uint256 amount,
        address toUser
    ) external {
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        vaultBalances[toUser][token] += amount;

        emit Deposit(msg.sender, toUser, token, amount);
    }

    /**
     * @notice Function used to withdraw tokens.
     * @dev The call will fail if vault token balance of the sender is insufficient.
     * @param token An addess of the token to be withdrawn.
     * @param amount An amount of tokens to be withdrawn.
     * @param toAddress An address to which the tokens will be withdrawn.
     */
    function withdrawToken(
        address token,
        uint256 amount,
        address toAddress
    ) external {
        require(
            amount <= vaultBalances[msg.sender][token],
            "Insufficient amount assets in vault."
        );

        vaultBalances[msg.sender][token] -= amount;

        IERC20(token).safeTransfer(toAddress, amount);

        emit Withdraw(msg.sender, toAddress, token, amount);
    }

    /**
     * @notice Function used to retrieve asset balance of specific address. This balance does not include amount locked in orders.
     * @dev To retrieve Ether balance, use 0 address for the asset parameter.
     * @param asset An addess of the asset (token address or 0 address for the Ether) to be checked.
     * @param user An address of the user whose balance should be checked.
     */
    function vaultBalanceOf(address asset, address user)
        external
        view
        returns (uint256 balance)
    {
        return vaultBalances[user][asset];
    }

    /**
     * @notice Function used to retrieve asset balance of specific address locked in order(s).
     * @dev To retrieve Ether balance, use 0 address for the asset parameter.
     * @param asset An addess of the asset (token address or 0 address for the Ether) to be checked.
     * @param user An address of the user whose balance should be checked.
     */
    function inOrderBalanceOf(address asset, address user)
        external
        view
        returns (uint256 balance)
    {
        return inOrders[user][asset];
    }

    /**
     * @dev Function used to allocate tokens in the order. The call will fail if vault token balance of the user is insufficient. To prevent malicious contracts from manipulating user funds without approval, this function requires that tx originates from the actual owner of the funds, i.e. tx.origin will be treated as user.
     * @param asset An addess of the asset to be added to the order (i.e. token address or zero address for ether).
     * @param amount An amount of tokens to be allocated into order.
     * @param orderHash A hash of the order that triggered allocation.
     */
    function moveToOrder(
        address asset,
        uint256 amount,
        bytes32 orderHash
    ) external onlyAllowed {
        require(
            amount <= vaultBalances[tx.origin][asset],
            "Insufficient vault balance."
        );

        vaultBalances[tx.origin][asset] -= amount;
        inOrders[tx.origin][asset] += amount;

        emit MovedToOrder(tx.origin, asset, amount, orderHash);
    }

    /**
     * @dev Function used to allocate tokens from order, back to the vault upon cancellation. The call will fail if in order token balance of the user is insufficient. To prevent malicious contracts from manipulating user funds without approval, this function requires that tx originates from the actual owner of the funds, i.e. tx.origin will be treated as user.
     * @param asset An addess of the asset to be removed from order balance (i.e. token address or zero address for ether).
     * @param amount An amount of tokens to be allocated into vault.
     * @param orderHash A hash of the order that triggered deallocation.
     */
    function orderCancellation(
        address asset,
        uint256 amount,
        bytes32 orderHash
    ) external onlyAllowed {
        require(
            amount <= inOrders[tx.origin][asset],
            "Insufficient in order balance."
        );

        inOrders[tx.origin][asset] -= amount;
        vaultBalances[tx.origin][asset] += amount;

        emit MovedFromOrder(tx.origin, asset, amount, orderHash);
    }

    /**
     * @dev Function used to allocate tokens from order, back to the vault upon expiration. The call will fail if in order token balance of the user is insufficient.
     * @param asset An addess of the asset to be removed from order balance (i.e. token address or zero address for ether).
     * @param amount An amount of tokens to be allocated into vault.
     * @param orderHash A hash of the order that triggered deallocation.
     * @param user An address of the user.
     */
    function orderExpiration(
        address asset,
        uint256 amount,
        bytes32 orderHash,
        address user
    ) external onlyAllowed {
        require(
            amount <= inOrders[user][asset],
            "Insufficient in order balance."
        );

        inOrders[user][asset] -= amount;
        vaultBalances[user][asset] += amount;

        emit MovedFromOrder(user, asset, amount, orderHash);
    }

    /**
     * @dev Function used to release funds to order module, to execute trade/swap.
     * @param user An address of the user.
     * @param assetA An addess of the asset to be released (i.e. token address or zero address for ether).
     * @param amountA An amount of tokens to be released.
     * @param orderHash The hash of the order being executed.
     * @param destination An address of the order module, that will execute the trade/swap.
     * @param wrap If true, will wrap Ether as WETH9 before release, if asset is zero address.
     */
    function orderFill_ReleaseFunds(
        address user,
        address assetA,
        uint256 amountA,
        bytes32 orderHash,
        address payable destination,
        bool wrap
    ) external onlyAllowed {
        require(
            amountA <= inOrders[user][assetA],
            "Insufficient in order balance."
        );

        if (assetA == address(0)) {
            if (wrap) {
                WETH.deposit{value: amountA}();

                IERC20(weth).safeTransfer(destination, amountA);
            } else destination.transfer(amountA);
        } else IERC20(assetA).safeTransfer(destination, amountA);

        inOrders[user][assetA] -= amountA;

        emit FundsReleased(user, assetA, amountA, destination, orderHash);
    }

    /**
     * @dev Function called after order fill had been successfull and balances need to be rebalanced. Funds must be sent to contract before triggering this function! IMPORTANT: Does no check if assets have been returned!
     * @param user An address of the user.
     * @param assetB An addess of the asset gotten from trade/swap.
     * @param amountB An amount of asset gotten from trade/swap.
     * @param orderHash The hash of the order that triggered this change.
	 * @param unwrap If order received and sent WETH to the Vault from handler, setting this to anything other than 0 will unwrap that amount of WETH.
     */
    function orderFill_Succeeded(
        address user,
        address assetB,
        uint256 amountB,
        bytes32 orderHash,
		uint256 unwrap
    ) external onlyAllowed {
		if (assetB == address(0) && unwrap > 0) WETH.withdraw(unwrap);

        vaultBalances[user][assetB] += amountB;

        emit FillExecuted(user, assetB, amountB, orderHash);
    }

    /**
     * @dev Function called to adjust the balance in Vault contract for the second order when internal match happens. A and B arguments are respective to the first order.
     * @param orderA Hash of the first order.
     * @param orderB Hash of the second order (order to be updated).
     * @param userA Creator of the first order.
     * @param userB Creator of the second order.
     * @param assetA Base asset of first order and quote asset of second order.
     * @param assetB Quote asset of first order and base asset of second order.
     * @param amountA Volume of base token taken from first order and received by the second order.
     * @param amountB Volume of quote token received in first order and taken from second order.
     */
    function internalMatch(
        bytes32 orderA,
        bytes32 orderB,
        address userA,
        address userB,
        address assetA,
        address assetB,
        uint256 amountA,
        uint256 amountB
    ) external onlyAllowed {
        vaultBalances[userB][assetA] += amountA;
        inOrders[userA][assetA] -= amountA;
        inOrders[userB][assetB] -= amountB;

        emit InternalMatchTransfer(orderA, orderB, amountA, amountB); // InternalMatchTransfer is equialent of FillExecuted
    }

    fallback() external payable {}
}