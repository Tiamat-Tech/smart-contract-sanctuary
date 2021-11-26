// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
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

interface IQAsset {
    function updateMNTOwner(address newOwner) external;
}

contract Bridge is IMinter, IAssetLocker, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint64 public constant COMMAND_UNLOCK = 0x1;
    uint64 public constant COMMAND_MINT = 0x2;

    address[] public activeCosigners;
    mapping(address => bool) public isCosignerActive;
    mapping(bytes32 => bool) public executed;
    // Records of source chain asset address to destination chain asset
    // Mapping from chain ID + address to target address
    // We require destination chain tokens to be deployed in advance since
    // may need transfer ownership of MNT to qasset
    mapping(uint256 => mapping(address => address)) public wrapping;
    // Reverse mapping from wrapped token (on destination chain) to its canonical token
    // on source chain
    mapping(uint256 => mapping(address => address)) public canonical;

    uint256 public override quorum = 0;
    uint256 public override nonce = 0;
    uint256 public override chainId = 0;

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
        uint256 srcChainId,
        bytes32 srcTxHash,
        address indexed srcToken,
        uint256 dstChainId,
        address indexed recipient,
        uint256 amount
    );

    event Mint(
        uint256 srcChainId,
        bytes32 srcTxHash,
        address indexed srcToken,
        uint256 dstChainId,
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
                keccak256(abi.encodePacked(nonce, _token, _to)),
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
                keccak256(abi.encodePacked(nonce, _qasset, _newMNTOwner)),
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
        address _dstToken
    ) public onlyOwner {
        wrapping[_chainId][_srcToken] = _dstToken;
    }

    // Admin methods for updating canonical token mapping. Can be governance
    function updateCanonical(
        uint256 _chainId,
        address _srcToken,
        address _dstToken
    ) public onlyOwner {
        canonical[_chainId][_srcToken] = _dstToken;
    }

    // LOCK: on source chain
    function lock(
        address _token,
        address _to,
        uint256 _amount,
        uint256 _dstChain
    ) public override nonReentrant {
        require(_amount > 0, "Bridge: invalid amount");
        require(_dstChain != chainId, "Bridge: invalid dest chain");
        address dstToken = wrapping[_dstChain][_token];
        require(dstToken != address(0x0), "Bridge: token not allowed");
        // TODO: easier to handle mnt conversion. make sure our target tokens all have 18 decimals
        require(
            IERC20Metadata(_token).decimals() == 18,
            "Bridge: invalid decimals"
        );
        IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);
        emit Lock(
            chainId,
            _dstChain,
            _token,
            dstToken,
            msg.sender,
            _to,
            _amount
        );
    }

    // BURN: on dest chain
    function burn(
        address _token,
        address _to,
        uint256 _amount,
        uint256 _dstChain
    ) public override nonReentrant {
        require(_amount > 0, "Bridge: invalid amount");
        require(_dstChain != chainId, "Bridge: invalid dest chain");
        address dstToken = canonical[_dstChain][_token];
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
    ) public override withNonce {
        _unlockOrMint(
            _srcChainId,
            _srcTxHash,
            _srcLogIdx,
            _srcToken,
            _dstChainId,
            _recipient,
            _amount,
            _signatures
        );
        emit Mint(
            _srcChainId,
            _srcTxHash,
            _srcToken,
            _dstChainId,
            _recipient,
            _amount
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
    ) public override withNonce {
        _unlockOrMint(
            _srcChainId,
            _srcTxHash,
            _srcLogIdx,
            _srcToken,
            _dstChainId,
            _recipient,
            _amount,
            _signatures
        );
        emit Unlock(
            _srcChainId,
            _srcTxHash,
            _srcToken,
            _dstChainId,
            _recipient,
            _amount
        );
    }

    function _unlockOrMint(
        uint256 _srcChainId,
        bytes32 _srcTxHash,
        uint256 _srcLogIdx,
        address _srcToken,
        uint256 _dstChainId,
        address _recipient,
        uint256 _amount,
        bytes[] memory _signatures
    ) internal nonReentrant {
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
        bytes32 localEvHash = keccak256(
            abi.encodePacked(
                _srcChainId,
                _srcTxHash,
                _srcLogIdx,
                _srcToken,
                _dstChainId,
                _recipient,
                _amount,
                address(this)
            )
        );
        require(!executed[localEvHash], "Bridge: already executed");
        require(verify(localEvHash, _signatures), "Bridge: invalid sigs");
        executed[localEvHash] = true;

        // BURN path
        address _canonAsset = canonical[_srcChainId][_srcToken];
        if (_canonAsset != address(0x0)) {
            uint256 _bal = IERC20(_canonAsset).balanceOf(address(this));
            if (_bal >= _amount) {
                IERC20(_canonAsset).safeTransfer(_recipient, _amount);
                return;
            } else if (_bal != 0) {
                IERC20(_canonAsset).safeTransfer(_recipient, _bal);
                _amount -= _bal;
            }
        }

        // UNLOCK path
        address _wrappedToken = wrapping[_srcChainId][_srcToken];
        require(_wrappedToken != address(0x0), "Bridge: invalid mint");

        IERC20BurnableAndMintable(_wrappedToken).mint(_recipient, _amount);
    }
}