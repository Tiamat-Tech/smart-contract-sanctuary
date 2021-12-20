// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

interface IERC20BurnableAndMintable {
    function burn(uint256 amount) external;

    function mint(address to, uint256 amount) external;
}

interface IMinter {
    function nonce() external view returns (uint256);

    function quorum() external view returns (uint256);

    function chainId() external view returns (uint256);

    function verify(bytes32 _hash, bytes[] calldata _signatures)
        external
        view
        returns (bool);

    function mint(
        uint256 _srcChainId,
        bytes32 _srcTxHash,
        uint256 _srcLogIdx,
        address _srcToken,
        uint256 _dstChainId,
        address _recipient,
        uint256 _amount,
        bytes[] memory _signatures
    ) external;

    function burn(
        address _token,
        address _to,
        uint256 _amount,
        uint256 _dstChain
    ) external;
}

interface IAssetLocker {
    function lock(
        address _token,
        address _to,
        uint256 _amount,
        uint256 _dstChain
    ) external;

    function lockNative(address _to, uint256 _dstChain) external payable;

    function unlock(
        uint256 _srcChainId,
        bytes32 _srcTxHash,
        uint256 _srcLogIdx,
        address _srcToken,
        uint256 _dstChainId,
        address _recipient,
        uint256 _amount,
        bytes[] memory _signatures
    ) external;
}

interface INativeWrapper {
    function deposit() external payable;

    function withdraw(uint256) external;
}

interface IQAsset {
    function updateMNTOwner(address newOwner) external;
}

contract Bridge is IMinter, IAssetLocker, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    address[] public activeCosigners;
    mapping(address => bool) public isCosignerActive;
    mapping(bytes32 => bool) public executed;

    // Mapping from local assets to different assets on different chains
    mapping(address => mapping(uint256 => address))
        public wrappingLocalToRemote;
    mapping(address => mapping(uint256 => address))
        public canonicalLocalToRemote;
    // Mapping from a remote chain's asset to local asset
    mapping(uint256 => mapping(address => address))
        public wrappingRemoteToLocal;
    mapping(uint256 => mapping(address => address))
        public canonicalRemoteToLocal;

    uint256 public override quorum = 0;
    uint256 public override nonce = 0;
    uint256 public override chainId = 0;

    // WETH, WBNB, etc.
    address public nativeWrapper;

    struct UnlockOrMintPayload {
        uint256 srcChainId;
        bytes32 srcTxHash;
        uint256 srcLogIdx;
        address srcToken;
        uint256 dstChainId;
        address recipient;
        uint256 amount;
        bytes[] signatures;
    }

    event Lock(
        uint256 srcChain,
        uint256 dstChain,
        address indexed srcToken,
        address indexed dstToken,
        address indexed from,
        address recipient,
        uint256 amount
    );

    event Unlock(
        uint256 srcChain,
        uint256 dstChain,
        address indexed srcToken,
        address indexed dstToken,
        bytes32 srcTxHash,
        address indexed recipient,
        uint256 amount
    );

    event Mint(
        uint256 srcChain,
        uint256 dstChain,
        address indexed srcToken,
        address indexed dstToken,
        bytes32 srcTxHash,
        address indexed recipient,
        uint256 amount
    );

    event Burn(
        uint256 srcChain,
        uint256 dstChain,
        address indexed srcToken,
        address indexed dstToken,
        address indexed from,
        address recipient,
        uint256 amount
    );

    constructor(
        uint256 _quorum,
        uint256 _nonce,
        uint256 _chainId,
        address[] memory _signers
    ) {
        for (uint256 i = 0; i < _signers.length; i++) {
            isCosignerActive[_signers[i]] = true;
        }
        quorum = _quorum;
        nonce = _nonce;
        chainId = _chainId;
        activeCosigners = _signers;
    }

    function setNativeWrapper(address _nativeWrapper) public onlyOwner {
        require(nativeWrapper == address(0x0), "Bridge: wrapper already set");
        nativeWrapper = _nativeWrapper;
    }

    modifier withNonce() {
        _;

        nonce++;
    }

    function getActiveCosigners()
        public
        view
        returns (address[] memory, uint256)
    {
        return (activeCosigners, quorum);
    }

    function setActiveCosigners(
        address[] memory _set,
        uint256 _quorum,
        bytes[] memory _signatures
    ) public withNonce {
        require(
            verify(
                keccak256(
                    abi.encodePacked(
                        nonce,
                        address(this),
                        chainId,
                        _set,
                        _quorum
                    )
                ),
                _signatures
            ),
            "Bridge: invalid sigs"
        );
        require(
            _quorum > 0 && _quorum <= _set.length,
            "Bridge: invalid quorum"
        );
        for (uint256 i = 0; i < activeCosigners.length; i++) {
            isCosignerActive[activeCosigners[i]] = false;
        }

        for (uint256 i = 0; i < _set.length; i++) {
            isCosignerActive[_set[i]] = true;
        }

        activeCosigners = _set;
        quorum = _quorum;
    }

    function collectOwnership(
        address _token,
        address _to,
        bytes[] memory _signatures
    ) public withNonce {
        require(
            verify(
                keccak256(
                    abi.encodePacked(nonce, address(this), chainId, _token, _to)
                ),
                _signatures
            ),
            "Bridge: invalid sigs"
        );
        Ownable(_token).transferOwnership(_to);
    }

    function updateQAssetMNTOwner(
        address _qasset,
        address _newMNTOwner,
        bytes[] memory _signatures
    ) public withNonce {
        require(
            verify(
                keccak256(
                    abi.encodePacked(
                        nonce,
                        address(this),
                        chainId,
                        _qasset,
                        _newMNTOwner
                    )
                ),
                _signatures
            ),
            "Bridge: invalid sigs"
        );
        IQAsset(_qasset).updateMNTOwner(_newMNTOwner);
    }

    function verify(bytes32 _hash, bytes[] memory _signatures)
        public
        view
        override
        returns (bool)
    {
        if (_signatures.length < quorum) {
            return false;
        }

        bytes32 h = keccak256(abi.encodePacked("Unibridge:", _hash));
        address lastSigner = address(0x0);
        address currentSigner;
        uint256 success = 0;

        for (uint256 i = 0; i < _signatures.length; i++) {
            currentSigner = ECDSA.recover(h, _signatures[i]);
            if (currentSigner <= lastSigner) {
                return false;
            }
            if (isCosignerActive[currentSigner]) {
                success += 1;
            }
            lastSigner = currentSigner;
        }

        return success >= quorum;
    }

    // Admin methods for updating wrapped token mapping. Can be governance
    function updateWrapping(
        uint256 _chainId,
        address _srcToken,
        address _dstToken,
        bool _localToRemote
    ) public onlyOwner {
        if (_localToRemote)
            wrappingLocalToRemote[_srcToken][_chainId] = _dstToken;
        else wrappingRemoteToLocal[_chainId][_srcToken] = _dstToken;
    }

    // Admin methods for updating canonical token mapping. Can be governance
    function updateCanonical(
        uint256 _chainId,
        address _srcToken,
        address _dstToken,
        bool _localToRemote
    ) public onlyOwner {
        if (_localToRemote)
            canonicalLocalToRemote[_srcToken][_chainId] = _dstToken;
        else canonicalRemoteToLocal[_chainId][_srcToken] = _dstToken;
    }

    // LOCK: on source chain
    function lock(
        address _token,
        address _to,
        uint256 _amount,
        uint256 _dstChain
    ) public override {
        _lock(msg.sender, _token, _to, _amount, _dstChain, true);
    }

    function lockNative(address _to, uint256 _dstChain)
        public
        payable
        override
    {
        INativeWrapper(nativeWrapper).deposit{ value: msg.value }();
        _lock(msg.sender, nativeWrapper, _to, msg.value, _dstChain, false);
    }

    receive() external payable {
        // To receive withdrawal from WETH
        require(msg.sender == nativeWrapper, "Bridge: native wrapper only");
    }

    // BURN: on dest chain
    function burn(
        address _token,
        address _to,
        uint256 _amount,
        uint256 _dstChain
    ) public override nonReentrant {
        require(_amount > 0, "Bridge: invalid amount");
        address dstToken = canonicalLocalToRemote[_token][_dstChain];
        // It's possible this wrapped token only has another wrapping on a third chain
        if (dstToken == address(0x0)) {
            dstToken = wrappingLocalToRemote[_token][_dstChain];
        }
        require(dstToken != address(0x0), "Bridge: token not allowed");
        IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);
        IERC20BurnableAndMintable(_token).burn(_amount);
        emit Burn(
            chainId,
            _dstChain,
            _token,
            dstToken,
            msg.sender,
            _to,
            _amount
        );
    }

    // MINT: on destination chain with aggregated signatures
    function mint(
        uint256 _srcChainId,
        bytes32 _srcTxHash,
        uint256 _srcLogIdx,
        address _srcToken,
        uint256 _dstChainId,
        address _recipient,
        uint256 _amount,
        bytes[] memory _signatures
    ) public override {
        _unlockOrMint(
            UnlockOrMintPayload(
                _srcChainId,
                _srcTxHash,
                _srcLogIdx,
                _srcToken,
                _dstChainId,
                _recipient,
                _amount,
                _signatures
            )
        );
    }

    // UNLOCK: on source chain with aggregated signatures
    function unlock(
        uint256 _srcChainId,
        bytes32 _srcTxHash,
        uint256 _srcLogIdx,
        address _srcToken,
        uint256 _dstChainId,
        address _recipient,
        uint256 _amount,
        bytes[] memory _signatures
    ) public override {
        _unlockOrMint(
            UnlockOrMintPayload(
                _srcChainId,
                _srcTxHash,
                _srcLogIdx,
                _srcToken,
                _dstChainId,
                _recipient,
                _amount,
                _signatures
            )
        );
    }

    function _unlockOrMint(UnlockOrMintPayload memory payload)
        internal
        nonReentrant
    {
        require(payload.dstChainId == chainId, "Bridge: invalid dest chain");
        // Replay attack prevention:
        // There are two kinds of replay attack:
        // 1, The event is replayed to different contracts on different chains.
        //    This can avoided by encoding dest chain id || dest contract addr
        // 2, The event is replayed twice on the contract, where the second event can be
        //    a. the same event; or
        //    b. a event generated by different contracts on different chains.
        //    This can be avoided by making sure that the source event hash is unique
        //    E.g., hash(source chain id || txhash || log index) or
        //          hash(source chain id || source contract addr || nonce)
        bytes32 hash = keccak256(
            abi.encodePacked(
                payload.srcChainId,
                payload.srcTxHash,
                payload.srcLogIdx,
                payload.srcToken,
                payload.dstChainId,
                payload.recipient,
                payload.amount,
                address(this)
            )
        );
        bytes32 prefixedHash = keccak256(abi.encodePacked("Unibridge:", hash));
        require(!executed[prefixedHash], "Bridge: already executed");
        require(
            verify(hash, payload.signatures),
            "Bridge: invalid sigs"
        );
        executed[prefixedHash] = true;

        uint256 amount = payload.amount;
        // UNLOCK path
        address canonAsset = canonicalRemoteToLocal[payload.srcChainId][
            payload.srcToken
        ];
        if (canonAsset != address(0x0)) {
            {
                uint256 decimals = IERC20Metadata(canonAsset).decimals();
                require(decimals <= 18, "Bridge: invalid decimals");
                // Convert decimals as we always treat source token as 18 decimals
                amount /= 10**(18 - decimals);

                {
                    uint256 bal = IERC20(canonAsset).balanceOf(address(this));
                    uint256 canonTransfer = Math.min(bal, amount);
                    if (canonTransfer != 0) {
                        if (canonAsset != nativeWrapper) {
                            IERC20(canonAsset).safeTransfer(
                                payload.recipient,
                                canonTransfer
                            );
                        } else {
                            INativeWrapper(nativeWrapper).withdraw(
                                canonTransfer
                            );
                            payable(payload.recipient).transfer(canonTransfer);
                        }
                        emit Unlock(
                            payload.srcChainId,
                            payload.dstChainId,
                            payload.srcToken,
                            canonAsset,
                            payload.srcTxHash,
                            payload.recipient,
                            canonTransfer
                        );
                    }
                    amount -= canonTransfer;
                }

                if (amount == 0) {
                    return;
                }

                // Revert decimal change as our minted tokens will always be 18 decimals
                amount *= 10**(18 - decimals);
            }
        }

        // MINT path
        address wrappedToken = wrappingRemoteToLocal[payload.srcChainId][
            payload.srcToken
        ];
        require(wrappedToken != address(0x0), "Bridge: invalid mint");
        emit Mint(
            payload.srcChainId,
            payload.dstChainId,
            payload.srcToken,
            wrappedToken,
            payload.srcTxHash,
            payload.recipient,
            amount
        );
        IERC20BurnableAndMintable(wrappedToken).mint(payload.recipient, amount);
    }

    function _lock(
        address _from,
        address _token,
        address _to,
        uint256 _amount,
        uint256 _dstChain,
        bool _shouldTransfer
    ) private nonReentrant {
        require(_amount > 0, "Bridge: invalid amount");
        address dstToken = wrappingLocalToRemote[_token][_dstChain];
        // One chain's canonical can also unlock another chain's canonical token
        if (dstToken == address(0x0)) {
            dstToken = canonicalLocalToRemote[_token][_dstChain];
        }
        require(dstToken != address(0x0), "Bridge: token not allowed");

        // If called from the contract itself (ETH <=> WETH), no need to transfer
        if (_shouldTransfer) {
            IERC20(_token).safeTransferFrom(_from, address(this), _amount);
        }

        uint256 decimals = IERC20Metadata(_token).decimals();
        require(decimals <= 18, "Bridge: invalid decimals");
        // Destination tokens should always be of decimals 18
        _amount *= 10**(18 - decimals);
        emit Lock(chainId, _dstChain, _token, dstToken, _from, _to, _amount);
    }
}