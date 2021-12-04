// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

/**
 *      ____        _            _     _ _     _
 *     / ___|  __ _| |_ ___  ___| |__ (_) |__ | | ___  ___
 *     \___ \ / _` | __/ _ \/ __| '_ \| | '_ \| |/ _ \/ __|
 *      ___) | (_| | || (_) \__ \ | | | | |_) | |  __/\__ \
 *     |____/ \__,_|\__\___/|___/_| |_|_|_.__/|_|\___||___/
 *      ____  _             _        ____       _     _
 *     / ___|| |_ __ _  ___| | _____| __ ) _ __(_) __| | __ _  ___
 *     \___ \| __/ _` |/ __| |/ / __|  _ \| '__| |/ _` |/ _` |/ _ \
 *      ___) | || (_| | (__|   <\__ \ |_) | |  | | (_| | (_| |  __/
 *     |____/ \__\__,_|\___|_|\_\___/____/|_|  |_|\__,_|\__, |\___|
 *                                                      |___/
 */

// TODO: withdraw721 batch?

import "@openzeppelin/contracts/access/Ownable.sol";

import "./Interfaces.sol";

/**
 * @title Satoshibles Stacks Bridge Lock
 * @notice Locker for the ethereum side of the Satoshibles Stacks Bridge.
 * The StacksBridge can be used at https://stacksbridge.com/
 * @author Aaron Hanson <[email protected]>
 */
contract SatoshiblesStacksBridgeLock is IERC721Receiver, Ownable {

    /// The maximum token batch size for locks/releases
    uint256 public constant MAX_BATCH_SIZE = 50;

    /// Magic value for IERC721Receiver interface
    bytes4 constant ERC721_RECEIVED = 0x150b7a02;

    /// Satoshibles contract instance
    IERC721 public immutable SATOSHIBLE_CONTRACT;

    /// Bridge worker address
    address public worker;

    /// The current state of the bridge
    bool public bridgeIsOpen;

    /// The escrowed fee charged when locking, to pay for gas to release later
    uint256 public gasEscrowFee;

    /**
     * @notice Emitted when the bridgeIsOpen flag changes
     * @param isOpen Indicates whether or not the bridge is now open
     */
    event BridgeStateChanged(
        bool indexed isOpen
    );

    /**
     * @notice Emitted when a Satoshible is locked (bridging to Stacks)
     * @param tokenId The satoshible token ID
     * @param ethereumSender The sender's eth address
     * @param stacksReceiver The receiver's stacks address
     */
    event Locked(
        uint256 indexed tokenId,
        address indexed ethereumSender,
        string stacksReceiver
    );

    /**
     * @notice Requires the bridge to be open
     */
    modifier onlyWhenBridgeIsOpen()
    {
        require(
            bridgeIsOpen == true,
            "Bridge is currently closed"
        );
        _;
    }

    /**
     * @notice Requires the msg.sender to be the Worker address
     */
    modifier onlyWorker()
    {
        require(
             _msgSender() == worker,
            "Caller is not the worker"
        );
        _;
    }

    modifier doesntExceedMaxBatchSize(uint256[] calldata _tokenIds)
    {
        require(
            _tokenIds.length <= MAX_BATCH_SIZE,
            "Batch size too large"
        );
        _;
    }

    /**
     * @notice Boom... Let's go!
     * @param _immutableSatoshible Satoshible contract address
     */
    constructor(
        address _immutableSatoshible,
        address _worker
    ) {
        SATOSHIBLE_CONTRACT = IERC721(
            _immutableSatoshible
        );

        worker = _worker;
        bridgeIsOpen = true;
        gasEscrowFee = 0.01 ether;
    }

    /**
     * @notice Locks a satoshible to bridge it to Stacks
     * @param _tokenId The satoshible token ID
     * @param _stacksReceiver The stacks address to receive the satoshible
     */
    function lock(
        uint256 _tokenId,
        string calldata _stacksReceiver
    )
        external
        payable
        onlyWhenBridgeIsOpen
    {
        require(
            msg.value == gasEscrowFee,
            "Not enough ether"
        );

        _lock(
            _tokenId,
            _stacksReceiver
        );
    }

    /**
     * @notice Locks a batch of satoshibles to bridge to Stacks
     * @param _tokenIds The satoshible token IDs
     * @param _stacksReceiver The stacks address to receive the satoshibles
     */
    function lockBatch(
        uint256[] calldata _tokenIds,
        string calldata _stacksReceiver
    )
        external
        payable
        onlyWhenBridgeIsOpen
        doesntExceedMaxBatchSize(_tokenIds)
    {
        unchecked {
            require(
                msg.value == gasEscrowFee * _tokenIds.length,
                "Not enough ether"
            );

            for (uint256 i = 0; i < _tokenIds.length; i++) {
                _lock(
                    _tokenIds[i],
                    _stacksReceiver
                );
            }
        }
    }

    /**
     * @notice Releases a satoshible after bridging from Stacks
     * @param _tokenId The satoshible token ID
     * @param _receiver The eth address to receive the satoshible
     */
    function release(
        uint256 _tokenId,
        address _receiver
    )
        external
        onlyWorker
        onlyWhenBridgeIsOpen
    {
        _release(_tokenId, _receiver);
    }

    /**
     * @notice Releases a batch of satoshibles after bridging from Stacks
     * @param _tokenIds The satoshible token IDs
     * @param _receiver The eth address to receive the satoshibles
     */
    function releaseBatch(
        uint256[] calldata _tokenIds,
        address _receiver
    )
        external
        onlyWorker
        onlyWhenBridgeIsOpen
        doesntExceedMaxBatchSize(_tokenIds)
    {
        unchecked {
            for (uint256 i = 0; i < _tokenIds.length; i++) {
                _release(
                    _tokenIds[i],
                    _receiver
                );
            }
        }
    }

    /**
     * @notice Opens or closes the bridge
     * @param _isOpen Whether to open or close the bridge
     */
    function setBridgeIsOpen(
        bool _isOpen
    )
        external
        onlyOwner
    {
        bridgeIsOpen = _isOpen;

        emit BridgeStateChanged(
            _isOpen
        );
    }

    /**
     * @notice Sets a new worker address
     * @param _newWorker New worker address
     */
    function setWorker(
        address _newWorker
    )
        external
        onlyOwner
    {
        worker = _newWorker;
    }

    /**
     * @notice Sets a new gas escrow fee
     * @param _newGasEscrowFee New gas escrow fee amount in wei
     */
    function setGasEscrowFee(
        uint256 _newGasEscrowFee
    )
        external
        onlyOwner
    {
        gasEscrowFee = _newGasEscrowFee;
    }

    /**
     * @notice Transfers gas escrow ether to worker address
     * @param _amount Amount to transfer (in wei)
     */
    function transferGasEscrowToWorker(
        uint256 _amount
    )
        external
        onlyOwner
    {
        payable(worker).transfer(
            _amount
        );
    }

    /**
     * @notice Withdraws any ERC20 tokens
     * @dev WARNING: Double check token transfer function before calling this
     * @param _token Contract address of token
     * @param _to Address to which to withdraw
     * @param _amount Amount to withdraw
     * @param _hasVerifiedToken Must be true (sanity check)
     */
    function withdrawERC20(
        address _token,
        address _to,
        uint256 _amount,
        bool _hasVerifiedToken
    )
        external
        onlyOwner
    {
        require(
            _hasVerifiedToken == true,
            "Need to verify token"
        );

        IERC20(_token).transfer(
            _to,
            _amount
        );
    }

    /**
     * @notice Withdraws any ERC721 tokens
     * @dev WARNING: Double check token is legit before calling this
     * @param _token Contract address of token
     * @param _to Address to which to withdraw
     * @param _tokenIds Token IDs to withdraw
     * @param _hasVerifiedToken Must be true (sanity check)
     */
    function withdrawERC721(
        address _token,
        address _to,
        uint256[] calldata _tokenIds,
        bool _hasVerifiedToken
    )
        external
        onlyOwner
    {
        require(
            _hasVerifiedToken == true,
            "Need to verify token"
        );

        for (uint256 i = 0; i < _tokenIds.length; i++) {
            IERC721(_token).safeTransferFrom(
                address(this),
                _to,
                _tokenIds[i]
            );
        }
    }

    /**
     * @notice Disabled override of Ownable's renounceOwnership()
     */
    function renounceOwnership()
        public
        view
        override
        onlyOwner
    {
        revert("Cannot renounce ownership");
    }

    /**
     * @notice ERC721 token receiver interface
     * @dev Interface for any contract that wants to support safeTransfers
     * from ERC721 asset contracts.
     */
    function onERC721Received(
        address _operator,
        address _from,
        uint256 _tokenId,
        bytes calldata _data
    )
        external
        pure
        returns (bytes4)
    {
        return ERC721_RECEIVED;
    }

    /**
     * @dev Locks a satoshible to bridge to Stacks
     * @param _tokenId The satoshible token ID
     * @param _stacksReceiver The stacks address to receive the satoshible
     */
    function _lock(
        uint256 _tokenId,
        string calldata _stacksReceiver
    )
        private
    {
        SATOSHIBLE_CONTRACT.safeTransferFrom(
            _msgSender(),
            address(this),
            _tokenId
        );

        emit Locked(
            _tokenId,
            _msgSender(),
            _stacksReceiver
        );
    }

    /**
     * @dev Releases a satoshible after bridging from Stacks
     * @param _tokenId The satoshible token ID
     * @param _receiver The eth address to receive the satoshible
     */
    function _release(
        uint256 _tokenId,
        address _receiver
    )
        private
    {
        SATOSHIBLE_CONTRACT.safeTransferFrom(
            address(this),
            _receiver,
            _tokenId
        );
    }
}