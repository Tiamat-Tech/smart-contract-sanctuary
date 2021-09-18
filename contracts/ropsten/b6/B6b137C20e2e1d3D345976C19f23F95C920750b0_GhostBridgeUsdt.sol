// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./access/AccessControl.sol";

interface IUSDT {
    // other methods not needed
    function balanceOf(address who) external pure returns (uint);
    function transfer(address to, uint value) external;
}

// GHOST ERC20 token contracts
contract GhostBridgeUsdt is AccessControl {
    // role which could mint bridge transactions
    bytes32 public constant GATE_KEEPER_ROLE = keccak256("GATE_KEEPER_ROLE");

	/*
	 * @dev Emitted when transaction took verification on current chain
	 * @param blockNumber Specific block number of transaction
	 * @param transactionIndex Specific index of transaction
	 * @param to Address where tokens should be sent
	 * @param amount Amount of tokens to be sent
	 */
    event TransactionMinted(uint32 indexed blockNumber, uint32 txIndex, address to, uint256 amount);

	/**
	 * @dev Emitted when admin rescues some 'limbo' funds.
	 * @param admin Admin address
	 * @param receiver User address, which gets tokens
	 * @param asset Address of a rescued token
	 * @param amount Amount of rescued tokens
	 */
	event AssetsRescued(address indexed admin, address indexed receiver, address asset, uint256 amount);

	// container for GHOST EIP-20 token
    IUSDT _token;

	// hashmap for all occured transactions
    mapping (uint64 => bool) private _mintedTransactions;

	modifier transactionNotExists(uint32 blockNumber, uint32 transactionIndex) {
        require(!_mintedTransactions[
			uint64((uint64(blockNumber) << 32) | transactionIndex)
		], "GhostBridge: transaction already exists");
		_;
	}

	modifier transactionExists(uint32 blockNumber, uint32 transactionIndex) {
        require(_mintedTransactions[
			uint64((uint64(blockNumber) << 32) | transactionIndex)
		], "GhostBridge: transaction not exists");
		_;
	}

    /*
     * @dev Function that initializes state variables of a contract
     * @params token IUSDT based token, GHOST token
     */
    constructor(IUSDT token) {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(GATE_KEEPER_ROLE, _msgSender());
        _token = token;
    }

    /*
     * @dev Function that returns internal state token
     */
    function getToken() public view returns (IUSDT) {
        return _token;
    }

    /*
     * @dev Push transaction from GHOST chain to Ethereum-based chain and vice versa
     *
     * @params blockNumber Number of block in `Older Twin` network
     * @params transactionIndex Unique index of transaciton in `Older Twin` network
     * @params to Address where tokens should be moved in `Younger Twin` network
     * @params amount Amount of tokens to be transact in `Younger Twin` network
     *
     * @returns Boolean result of operation
     */
    function mintTx(uint32 _blockNumber, uint32 _transactionIndex, address _to, uint256 _amount) public transactionNotExists(_blockNumber, _transactionIndex) returns (bool) {
        require(hasRole(GATE_KEEPER_ROLE, _msgSender()), "GhostBridge: must have gatekeeper role");
        require(_to != address(0), "GhostBridge: destination is zero address");
        require(_to != address(this), "GhostBridge: destination is current smart contracts");
        require(_to != _msgSender(), "GhostBridge: self minting forbidden");
        require(_token.balanceOf(address(this)) >= _amount, "GhostBridge: not enough balance on current bridge");

        _token.transfer(_to, _amount);
        _mintedTransactions[uint64((uint64(_blockNumber) << 32) | _transactionIndex)] = true;

        emit TransactionMinted(_blockNumber, _transactionIndex, _to, _amount);
        return true;
    }

	/**
	 * @dev Functionality to rescue locked funds in 'limbo'. If user occasionally will send
	 * any EIP-20 applicable token or ether to this smart contract, admin can manually send
	 * them back.
	 *
	 * @param _rescueToken Address of the token to be rescued
	 * @param _to Address where tokens should be transfered
	 * @param _amount Amount of tokens to be transfered
	 */
    function rescueFunds(IUSDT _rescueToken, address payable _to, uint256 _amount) external returns (bool) {
	require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "GhostBridge: must have admin role");
        require(_to != address(0) && _to != address(this), "GhostBridge: not a valid recipient");
        require(_amount > 0, "GhostBridge: amount should be greater than 0");

		if (address(_rescueToken) == address(0)) {
			require(address(this).balance >= _amount, "Not enough ETH to rescue");
			payable(_to).transfer(_amount);
		} else if (address(_token) == address(_rescueToken)) {
			require(_token.balanceOf(address(this)) > _amount, "Not enough GHOST to rescue");
			_token.transfer(_to, _amount);
		} else {
			require(_rescueToken.balanceOf(address(this)) > _amount, "Not enough ERC20 to rescue");
			_rescueToken.transfer(_to, _amount);
		}

        emit AssetsRescued(_msgSender(), _to, address(_rescueToken), _amount);
        return true;
    }
}