// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./CustomToken.sol";

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract Bridge is Initializable, AccessControlUpgradeable, UUPSUpgradeable {
    using SafeERC20 for CustomToken;

    enum SwapState {
        Empty,
        Swapped,
        Redeemed
    }

    enum TokenState {
        NotDefined,
        Active,
        Inactive
    }

    struct Swap {
        uint256 nonce;
        SwapState state;
    }

    struct TokenInfo {
        address tokenAddress;
        string symbol;
        TokenState state;
    }

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant VALIDATOR_ROLE = keccak256("VALIDATOR_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    uint256 public currentBridgeChainId;

    mapping(string => TokenInfo) public tokenBySymbol;
    mapping(uint256 => bool) public isChainActiveById;
    mapping(bytes32 => Swap) public swapByHash;
    string[] tokenSymbols;

    event SwapInitialized(
        uint256 initTimestamp,
        address indexed initiator,
        address recipient,
        uint256 amount,
        string symbol,
        uint256 chainFrom,
        uint256 chainTo,
        uint256 nonce
    );

    event SwapRedeemed(
        address indexed initiator,
        uint256 initTimestamp,
        uint256 nonce
    );

    event TokenStateChanged(
        address indexed initiator,
        address tokenAddress,
        string symbol,
        TokenState newState
    );

    /**
    * @notice activate or disactivate network chain id from the chain list in this contract
    * @param bridgeChainId deployed network chain id
     */
    function initialize(uint256 bridgeChainId) initializer public {
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(UPGRADER_ROLE, msg.sender);
        _setupRole(ADMIN_ROLE, msg.sender);
        _setRoleAdmin(VALIDATOR_ROLE, ADMIN_ROLE);
        _setRoleAdmin(UPGRADER_ROLE, ADMIN_ROLE);
        _setRoleAdmin(ADMIN_ROLE, DEFAULT_ADMIN_ROLE);
        
        currentBridgeChainId = bridgeChainId;
    }

    function _authorizeUpgrade(address newImplementation)
    internal
    onlyRole(UPGRADER_ROLE)
    override
    {}

    /**
    * @notice activate or deactivate network chain id from the chain list in this contract
    * @param chainId network chain id
    * @param isActive bool; activate/deactivate
     */
    function updateChainById(uint256 chainId, bool isActive) external virtual {
        require(
            hasRole(ADMIN_ROLE, msg.sender),
            "Bridge: You should have a admin role"
        );
        isChainActiveById[chainId] = isActive;
    }

    /**
    * @notice provides list of registered tokens in this contract
     */
    function getTokenList() external view virtual returns (TokenInfo[] memory)  {
        TokenInfo[] memory tokens = new TokenInfo[](tokenSymbols.length);
        for (uint i = 0; i < tokenSymbols.length; i++) {
            tokens[i] = tokenBySymbol[tokenSymbols[i]];
        }
        return tokens;
    }

    /**
    * @notice add token to this contract in order to use them in swapping & redeeming
    * @param symbol of the token
    * @param tokenAddress token address
     */
    function addToken(string memory symbol, address tokenAddress) external virtual {
        require(
            hasRole(ADMIN_ROLE, msg.sender),
            "Bridge: You should have a admin role"
        );
        tokenBySymbol[symbol] = TokenInfo({
            tokenAddress: tokenAddress,
            symbol: symbol,
            state: TokenState.Active
        });
        tokenSymbols.push(symbol);
    }

    /**
    * @notice deactivate tokens by symbol
    * @param symbol of the token
     */
    function deactivateTokenBySymbol(string memory symbol) external virtual {
        require(
            hasRole(ADMIN_ROLE, msg.sender),
            "Bridge: You should have a admin role"
        );
        TokenInfo storage token = tokenBySymbol[symbol];
        token.state = TokenState.Inactive;
        emit TokenStateChanged(msg.sender, token.tokenAddress, symbol, token.state);
    }

    /**
    * @notice activate tokens by symbol
    * @param symbol of the token
     */
    function activateTokenBySymbol(string memory symbol) external virtual {
        require(
            hasRole(ADMIN_ROLE, msg.sender),
            "Bridge: You should have a admin role"
        );
        TokenInfo storage token = tokenBySymbol[symbol];
        token.state = TokenState.Active;
        emit TokenStateChanged(msg.sender, token.tokenAddress, symbol, token.state);
    }

    /**
    * @notice swap - produce tokens transaction to the other network bridge.
    * @param recipient address of the token's receiver
    * @param symbol of the sending tokens
    * @param amount of the sending tokens
    * @param chainTo network chain id of the token's receiver; cannot be the same network id
    * @param nonce unique number which should not repeat over all bridges among all networks
     */
    function swap(
        address recipient,
        string memory symbol,
        uint256 amount,
        uint256 chainTo,
        uint256 nonce
    ) external virtual {
        require(
            chainTo != currentBridgeChainId,
            "Bridge: Invalid chainTo is same with current bridge chain"
        );
        require(
            isChainActiveById[chainTo],
            "Bridge: chainTo does not exist/is not active"
        );


        TokenInfo memory token = tokenBySymbol[symbol];
        require(
            token.state == TokenState.Active,
            "Bridge: Token is inactive"
        );
        CustomToken(token.tokenAddress).burn(msg.sender, amount);
        
        bytes32 hash = keccak256(
            abi.encodePacked(
                recipient,
                amount,
                symbol,
                currentBridgeChainId, // ChainFrom
                chainTo,
                nonce
            )
        );

        require(
            swapByHash[hash].state == SwapState.Empty,
            "Bridge: Duplication of the transaction"
        );
        
        swapByHash[hash] = Swap({
        nonce: nonce,
        state: SwapState.Swapped
        });

        emit SwapInitialized(
            block.timestamp,
            msg.sender,
            recipient,
            amount,
            symbol,
            currentBridgeChainId,
            chainTo,
            nonce
        );
    }

    /**
    * @notice redeem - provides tokens from transaction of other network's similar bridge.
    * @param symbol of the sending tokens
    * @param amount of the sending tokens
    * @param chainFrom network chain id of the token's sender; cannot be the same network id
    * @param nonce unique number which should not repeat over all bridges among all networks
    * @param v of the transaction sign
    * @param r of the transaction sign
    * @param s of the transaction sign
     */
    function redeem(
        string memory symbol,
        uint256 amount,
        uint256 chainFrom,
        uint256 nonce,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external virtual {
        TokenInfo memory token = tokenBySymbol[symbol];
        require(
            token.state == TokenState.Active,
            "Bridge: Token is inactive"
        );

        bytes32 hash = keccak256(
            abi.encodePacked(
                msg.sender,
                amount,
                symbol,
                chainFrom,
                currentBridgeChainId, //chainTo
                nonce
            )
        );

        require(
            swapByHash[hash].state == SwapState.Empty,
            "Bridge: Duplication of the transaction"
        );

        bytes32 prefixedHash = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", hash)
        );
        
        address validatorAddress = ecrecover(prefixedHash, v, r, s);
        
        require(
            hasRole(VALIDATOR_ROLE, validatorAddress),
            "Bridge: Validator address is not correct"
        );

        swapByHash[hash] = Swap({
            nonce: nonce,
            state: SwapState.Redeemed
        });

        CustomToken(token.tokenAddress).mint(msg.sender, amount);

        emit SwapRedeemed(
            msg.sender,
            block.timestamp,
            nonce
        );
    }
}