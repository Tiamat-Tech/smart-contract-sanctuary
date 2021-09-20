// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./CustomToken.sol";

contract Bridge is AccessControl {
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

    uint256 public immutable currentBridgeChainId;

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

    constructor (uint256 bridgeChainId) {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(ADMIN_ROLE, msg.sender);
        _setRoleAdmin(VALIDATOR_ROLE, ADMIN_ROLE);
        _setRoleAdmin(ADMIN_ROLE, DEFAULT_ADMIN_ROLE);
        currentBridgeChainId = bridgeChainId;
    }

    function updateChainById(uint256 chainId, bool isActive) external {
        require(
            hasRole(ADMIN_ROLE, msg.sender),
            "Bridge: You should have a admin role"
        );
        isChainActiveById[chainId] = isActive;
    }

    function getTokenList() external view returns (TokenInfo[] memory) {
        TokenInfo[] memory tokens = new TokenInfo[](tokenSymbols.length);
        for (uint i = 0; i < tokenSymbols.length; i++) {
            tokens[i] = tokenBySymbol[tokenSymbols[i]];
        }
        return tokens;
    }

    function addToken(string memory symbol, address tokenAddress) external {
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

    function deactivateTokenBySymbol(string memory symbol) external {
        require(
            hasRole(ADMIN_ROLE, msg.sender),
            "Bridge: You should have a admin role"
        );
        TokenInfo storage token = tokenBySymbol[symbol];
        token.state = TokenState.Inactive;
        emit TokenStateChanged(msg.sender, token.tokenAddress, symbol, token.state);
    }

    function activateTokenBySymbol(string memory symbol) external {
        require(
            hasRole(ADMIN_ROLE, msg.sender),
            "Bridge: You should have a admin role"
        );
        TokenInfo storage token = tokenBySymbol[symbol];
        token.state = TokenState.Active;
        emit TokenStateChanged(msg.sender, token.tokenAddress, symbol, token.state);
    }

    function swap(
        address recipient,
        string memory symbol,
        uint256 amount,
        uint256 chainTo,
        uint256 nonce
    ) external {
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

    function redeem(
        string memory symbol,
        uint256 amount,
        uint256 chainFrom,
        uint256 nonce,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
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

        CustomToken(token.tokenAddress).mint(msg.sender, amount);

        swapByHash[hash] = Swap({
            nonce: nonce,
            state: SwapState.Redeemed
        });

        emit SwapRedeemed(
            msg.sender,
            block.timestamp,
            nonce
        );
    }
}