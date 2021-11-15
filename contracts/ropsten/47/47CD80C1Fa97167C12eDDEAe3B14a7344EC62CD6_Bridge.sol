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
        address _token,
        address _to,
        uint256 _amount,
        bytes32 _evtHash,
        bytes[] calldata _signatures
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
        address _token,
        address _to,
        uint256 _amount,
        uint256 _dstChain,
        bytes[] memory _signatures
    ) external;
}

contract Bridge is IMinter, IAssetLocker, ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint64 public constant COMMAND_UNLOCK = 0x1;
    uint64 public constant COMMAND_MINT = 0x2;

    address[] public activeCosigners;
    mapping(address => bool) public isCosignerActive;
    mapping(bytes32 => bool) public executed;

    uint256 public override quorum = 0;
    uint256 public override nonce = 0;
    uint256 public override chainId = 0;

    event Lock(
        uint256 srcChain,
        uint256 dstChain,
        address indexed token,
        address indexed from,
        address recipient,
        uint256 amount
    );

    event Unlock(
        address indexed token,
        address indexed recipient,
        uint256 amount
    );

    event Mint(
        address indexed token,
        address indexed recipient,
        uint256 amount
    );

    event Burn(
        uint256 srcChain,
        uint256 dstChain,
        address indexed token,
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
            "Bridge: invalid signatures for setActiveCosigners"
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
            "Bridge: invalid signatures for collectOwnership"
        );
        Ownable(_token).transferOwnership(_to);
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

        bytes32 h = ECDSA.toEthSignedMessageHash(_hash);
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

        if (success < quorum) {
            return false;
        }

        return true;
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
        // TODO: easier to handle mnt conversion. make sure our target tokens all have 18 decimals
        require(
            IERC20Metadata(_token).decimals() == 18,
            "Bridge: invalid decimals"
        );
        IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);
        emit Lock(chainId, _dstChain, _token, msg.sender, _to, _amount);
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
        IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);
        IERC20BurnableAndMintable(_token).burn(_amount);
        emit Burn(chainId, _dstChain, _token, msg.sender, _to, _amount);
    }

    // MINT: on destination chain with aggregated signatures
    function mint(
        address _token,
        address _to,
        uint256 _amount,
        bytes32 _txHash,
        bytes[] memory _signatures
    ) public override withNonce {
        bytes32 hash = keccak256(
            abi.encodePacked(_token, _to, _amount, _txHash)
        );
        require(!executed[hash], "Bridge: already minted");
        require(
            verify(hash, _signatures),
            "Bridge: invalid signatures for mint"
        );

        IERC20BurnableAndMintable(_token).mint(_to, _amount);
        emit Mint(_token, _to, _amount);
        executed[hash] = true;
    }

    // UNLOCK: on source chain with aggregated signatures
    function unlock(
        address _token,
        address _to,
        uint256 _amount,
        uint256 _dstChain,
        bytes[] memory _signatures
    ) public override withNonce {
        bytes32 hash = keccak256(
            abi.encodePacked(_token, _to, _amount, _dstChain)
        );
        require(!executed[hash], "Bridge: event has been executed");
        require(
            verify(hash, _signatures),
            "Bridge: invalid signatures for unlock"
        );

        IERC20(_token).safeTransfer(_to, _amount);
        emit Unlock(_token, _to, _amount);
        executed[hash] = true;
    }
}