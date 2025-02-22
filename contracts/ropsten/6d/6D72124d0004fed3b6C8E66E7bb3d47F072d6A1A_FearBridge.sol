// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IMuonV02.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

interface IERC20 {
    function transfer(address recipient, uint256 amount) external;

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external;

    function pool_burn_from(address b_address, uint256 b_amount) external;

    function pool_mint(address m_address, uint256 m_amount) external;
}

contract FearBridge is Ownable {
    using ECDSA for bytes32;

    /* ========== STATE VARIABLES ========== */
    struct TX {
        uint256 txId;
        uint256 tokenId;
        uint256 amount;
        uint256 fromChain;
        uint256 toChain;
        address user;
    }

    uint256 public lastTxId = 0; // unique id for deposit tx
    uint256 public network; // current chain id
    uint256 public minReqSigs; // minimum required tss
    uint256 public fee;
    uint256 public scale = 1e6;
    address public muonContract;
    bool public mintable; // use mint functions instead of transfer
    uint8 constant APP_ID = 5; // muon's  app id
    // we assign a unique ID to each chain (default is CHAIN-ID)
    mapping(uint256 => address) public sideContracts;
    // tokenId => tokenContractAddress
    mapping(uint256 => address) public tokens;
    mapping(uint256 => TX) public txs;
    // user => (destination chain => user's txs id)
    mapping(address => mapping(uint256 => uint256[])) public userTxs;
    // source chain => (tx id => false/true)
    mapping(uint256 => mapping(uint256 => bool)) public claimedTxs;

    /* ========== CONSTRUCTOR ========== */

    constructor(
        address _muon,
        bool _mintable,
        uint256 _minReqSigs,
        uint256 _fee
    ) {
        network = getExecutingChainID();
        mintable = _mintable;
        muonContract = _muon;
        minReqSigs = _minReqSigs;
        fee = _fee;
    }

    /* ========== PUBLIC FUNCTIONS ========== */

    function deposit(
        uint256 amount,
        uint256 toChain,
        uint256 tokenId
    ) external returns (uint256) {
        return depositFor(msg.sender, amount, toChain, tokenId);
    }

    function depositFor(
        address user,
        uint256 amount,
        uint256 toChain,
        uint256 tokenId
    ) public returns (uint256 txId) {
        require(
            sideContracts[toChain] != address(0),
            "Bridge: unknown toChain"
        );
        require(toChain != network, "Bridge: selfDeposit");
        require(tokens[tokenId] != address(0), "Bridge: unknown tokenId");

        IERC20 token = IERC20(tokens[tokenId]);
        if (mintable) {
            token.pool_burn_from(msg.sender, amount);
        } else {
            token.transferFrom(msg.sender, address(this), amount);
        }
        txId = ++lastTxId;
        txs[txId] = TX({
            txId: txId,
            tokenId: tokenId,
            fromChain: network,
            toChain: toChain,
            amount: amount,
            user: user
        });
        userTxs[user][toChain].push(txId);

        emit Deposit(user, tokenId, amount, toChain, txId);
    }

    function claim(
        address user,
        uint256 amount,
        uint256 fromChain,
        uint256 toChain,
        uint256 tokenId,
        uint256 txId,
        bytes calldata _reqId,
        SchnorrSign[] calldata sigs
    ) public {
        require(
            sideContracts[fromChain] != address(0),
            "Bridge: source contract not exist"
        );
        require(toChain == network, "Bridge: toChain should equal network");
        require(
            sigs.length >= minReqSigs,
            "Bridge: insufficient number of signatures"
        );

        {
            bytes32 hash = keccak256(
                abi.encodePacked(
                    abi.encodePacked(
                        sideContracts[fromChain],
                        txId,
                        tokenId,
                        amount
                    ),
                    abi.encodePacked(fromChain, toChain, user, APP_ID)
                )
            );

            IMuonV02 muon = IMuonV02(muonContract);
            require(
                muon.verify(_reqId, uint256(hash), sigs),
                "Bridge: not verified"
            );
        }

        require(!claimedTxs[fromChain][txId], "Bridge: already claimed");
        require(tokens[tokenId] != address(0), "Bridge: unknown tokenId");

        amount -= (amount * fee) / scale;
        IERC20 token = IERC20(tokens[tokenId]);
        if (mintable) {
            token.pool_mint(user, amount);
        } else {
            token.transfer(user, amount);
        }

        claimedTxs[fromChain][txId] = true;
        emit Claim(user, tokenId, amount, fromChain, txId);
    }

    /* ========== VIEWS ========== */

    function collatDollarBalance(uint256 collat_usd_price)
        public
        view
        returns (uint256)
    {
        return 0;
    }

    function pendingTxs(uint256 fromChain, uint256[] calldata ids)
        public
        view
        returns (bool[] memory unclaimedIds)
    {
        unclaimedIds = new bool[](ids.length);
        for (uint256 i = 0; i < ids.length; i++) {
            unclaimedIds[i] = claimedTxs[fromChain][ids[i]];
        }
    }

    function getUserTxs(address user, uint256 toChain)
        public
        view
        returns (uint256[] memory)
    {
        return userTxs[user][toChain];
    }

    function getTx(uint256 _txId)
        public
        view
        returns (
            uint256 txId,
            uint256 tokenId,
            uint256 amount,
            uint256 fromChain,
            uint256 toChain,
            address user
        )
    {
        txId = txs[_txId].txId;
        tokenId = txs[_txId].tokenId;
        amount = txs[_txId].amount;
        fromChain = txs[_txId].fromChain;
        toChain = txs[_txId].toChain;
        user = txs[_txId].user;
    }

    function getExecutingChainID() public view returns (uint256) {
        uint256 id;
        assembly {
            id := chainid()
        }
        return id;
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    function addToken(uint256 tokenId, address tokenAddress)
        external
        onlyOwner
    {
        tokens[tokenId] = tokenAddress;
    }

    function setNetworkID(uint256 _network) external onlyOwner {
        network = _network;
        delete sideContracts[network];
    }

    function setFee(uint256 _fee) external onlyOwner {
        fee = _fee;
    }

    function setMinReqSigs(uint256 _minReqSigs) external onlyOwner {
        minReqSigs = _minReqSigs;
    }

    function setSideContract(uint256 _network, address _addr)
        external
        onlyOwner
    {
        require(network != _network, "Bridge: current network");
        sideContracts[_network] = _addr;
    }

    function setMintable(bool _mintable) external onlyOwner {
        mintable = _mintable;
    }

    function emergencyWithdrawETH(uint256 amount, address addr)
        external
        onlyOwner
    {
        require(addr != address(0));
        payable(addr).transfer(amount);
    }

    function emergencyWithdrawERC20Tokens(
        address _tokenAddr,
        address _to,
        uint256 _amount
    ) external onlyOwner {
        IERC20(_tokenAddr).transfer(_to, _amount);
    }

    /* ========== EVENTS ========== */
    event Deposit(
        address indexed user,
        uint256 tokenId,
        uint256 amount,
        uint256 indexed toChain,
        uint256 txId
    );

    event Claim(
        address indexed user,
        uint256 tokenId,
        uint256 amount,
        uint256 indexed fromChain,
        uint256 txId
    );
}