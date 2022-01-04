//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IToken {
    function mint(address to, uint256 amount) external;

    function burn(address owner, uint256 amount) external;

    function transfer(address _to, uint256 _value) external returns (bool);

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    function approve(address spender, uint256 amount) external returns (bool);

    function allowance(address owner, address spender)
        external
        view
        returns (uint256);
}

contract EthereumBridgeLMLT {
    address public admin;
    IToken public bridgedToken; //the token of the network the bridge is being deployed on
    uint256 public chainId;
    string public chainName;
     mapping(address => mapping(uint256 => bool)) public processedNonces;
    mapping(uint256 => Chain) public bridgedChains;
    mapping(address => mapping(uint256 => uint256)) bridgedBalances;
    uint256 public bridgedTotalSupply;

    struct Chain {
        uint256 chainId;
        string chainName;
        address bridgedTokenAddress;
        uint256 bridgedSupply;
    }
    event BridgedTokenUpdated(address bridgedTokenAddress, uint256 date);
    event LockedTokens(
        uint256 chainId,
        address sender,
        uint256 amount,
        uint256 date
    );
    event UnlockedTokens(
        uint256 chainId,
        address sender,
        uint256 amount,
        uint256 date
    );
    event NewChainAdded(
        uint256 chainId,
        string chainName,
        address tokenAddress,
        uint256 date
    );
    event ChainUpdated(
        uint256 chainId,
        string chainName,
        address tokenAddress,
        uint256 date
    );

    function updateBridgedToken(address _tokenAddress) external {
        assert(msg.sender == admin);
        bridgedToken = IToken(_tokenAddress);

        emit BridgedTokenUpdated(_tokenAddress, block.timestamp);
    }

    function addChain(
        uint256 _chainId,
        string memory _chainName,
        address _tokenAddress
    ) external {
        assert(msg.sender == admin);
        _addChain(_chainId, _chainName, _tokenAddress);
    }

    function _addChain(
        uint256 _chainId,
        string memory _chainName,
        address _tokenAddress
    ) internal {
        bridgedChains[_chainId] = Chain(_chainId, _chainName, _tokenAddress, 0);
        emit NewChainAdded(
            _chainId,
            _chainName,
            _tokenAddress,
            block.timestamp
        );
    }

    constructor(
        address _tokenToBridge,
        address _bridgedTokenAddress,
        uint256 _chainIdFrom,
        uint256 _chainIdTo,
        string memory _chainNameFrom,
        string memory _chainNameTo
    ) {
        admin = msg.sender;
        bridgedToken = IToken(_tokenToBridge);
        chainId = _chainIdFrom;
        chainName = _chainNameFrom;
        bridgedTotalSupply = 0;
        _addChain(_chainIdTo, _chainNameTo, _bridgedTokenAddress);
    }

    function bridgedBalanceOf(uint256 _chainId, address _account)
        public
        view
        virtual
        returns (uint256)
    {
        return bridgedBalances[_account][_chainId];
    }

    function getTotalSupplyByChainId(uint256 _chainId)
        public
        view
        virtual
        returns (uint256)
    {
        return bridgedChains[_chainId].bridgedSupply;
    }

    function getTotalBridgedSupply() public view virtual returns (uint256) {
        return bridgedTotalSupply;
    }

    function updateChain(
        uint256 _chainId,
        string memory _chainName,
        address _tokenAddress
    ) external {
        assert(msg.sender == admin);
        bridgedChains[_chainId].bridgedTokenAddress = _tokenAddress;
        bridgedChains[_chainId].chainId = _chainId;
        bridgedChains[_chainId].chainName = _chainName;
        emit ChainUpdated(_chainId, _chainName, _tokenAddress, block.timestamp);
    }

    function bridgeTokens(address from,
        address to, uint256 amount,  uint256 _chainId, uint256 nonce,
        bytes calldata signature) public {
         bytes32 message = prefixed(
            keccak256(abi.encodePacked(from, to,  _chainId, amount, nonce))
        );
        require(recoverSigner(message, signature) == from, "wrong signature");
        require(
            processedNonces[from][nonce] == false,
            "transfer already processed"
        );
        processedNonces[from][nonce] = true;
        bridgedToken.transferFrom(msg.sender, address(this), amount);
        bridgedChains[_chainId].bridgedSupply += amount;
        bridgedBalances[msg.sender][_chainId] += amount;
        bridgedTotalSupply += amount;

        emit LockedTokens(_chainId, msg.sender, amount, block.timestamp);
    }

    function unbridgeTokens(
       address from,
        address to,uint256 _chainId, uint256 amount,  uint256 nonce,
        bytes calldata signature
    ) public {
           bytes32 message = prefixed(
            keccak256(abi.encodePacked(from, to, amount, nonce))
        );
        require(recoverSigner(message, signature) == from, "wrong signature");
        require(
            processedNonces[from][nonce] == false,
            "transfer already processed"
        );
        processedNonces[from][nonce] = true;
        bridgedToken.transfer(to, amount);
        bridgedChains[_chainId].bridgedSupply -= amount;
        bridgedBalances[to][_chainId] -= amount;
        bridgedTotalSupply -= amount;

        emit UnlockedTokens(_chainId, to, amount, block.timestamp);
    }

    function prefixed(bytes32 hash) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encodePacked("\x19Ethereum Signed Message:\n32", hash)
            );
    }

    function recoverSigner(bytes32 message, bytes memory sig)
        internal
        pure
        returns (address)
    {
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = splitSignature(sig);

        return ecrecover(message, v, r, s);
    }

    function splitSignature(bytes memory sig)
        internal
        pure
        returns (
            uint8,
            bytes32,
            bytes32
        )
    {
        require(sig.length == 65);

        bytes32 r;
        bytes32 s;
        uint8 v;

        assembly {
            // first 32 bytes, after the length prefix
            r := mload(add(sig, 32))
            // second 32 bytes
            s := mload(add(sig, 64))
            // final byte (first byte of the next 32 bytes)
            v := byte(0, mload(add(sig, 96)))
        }

        return (v, r, s);
    }
}