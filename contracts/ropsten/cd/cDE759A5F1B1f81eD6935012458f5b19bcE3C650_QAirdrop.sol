// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import "./interface/IQSettings.sol";

/**
 * @author fantasy
 */
contract QAirdrop is ContextUpgradeable, ReentrancyGuardUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    // events
    event AddWhitelistedContract(address indexed whitelisted);
    event RemoveWhitelistedContract(address indexed whitelisted);
    event SetVerifier(address indexed verifier);
    event SetFoundationWallet(address indexed owner, address wallet);
    event ClaimQStk(address indexed user, uint256 amount);

    bool public locked;
    address public verifier;
    mapping(address => bool) public whitelistedContracts;
    mapping(bytes => bool) public claimed;

    IQSettings public settings;

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyManager() {
        require(
            settings.manager() == msg.sender,
            "QAirdrop: caller is not the manager"
        );
        _;
    }

    function initialize(
        address _settings,
        address _verifier,
        address[] memory _whitelistedContracts
    ) external initializer {
        __Context_init();
        __ReentrancyGuard_init();

        settings = IQSettings(_settings);
        verifier = _verifier;
        locked = true;

        uint256 length = _whitelistedContracts.length;
        for (uint256 i = 0; i < length; i++) {
            _addWhitelistedContract(_whitelistedContracts[i]);
        }
    }

    function addWhitelistedContract(address _contract) external onlyManager {
        _addWhitelistedContract(_contract);

        emit AddWhitelistedContract(_contract);
    }

    function removeWhitelistedContract(address _contract) external onlyManager {
        _removeWhitelistedContract(_contract);

        emit RemoveWhitelistedContract(_contract);
    }

    function setVerifier(address _verifier) external onlyManager {
        verifier = _verifier;

        emit SetVerifier(_verifier);
    }

    function setLocked(bool _locked) external onlyManager {
        locked = _locked;
    }

    function claimQStk(
        address _recipient,
        uint256 _qstkAmount,
        bytes memory _signature
    ) external nonReentrant {
        require(
            _verify(_recipient, _qstkAmount, _signature),
            "QAirdrop: invalid signature"
        );

        address qstk = settings.qstk();

        require(
            IERC20Upgradeable(qstk).balanceOf(address(this)) >= _qstkAmount,
            "QAirdrop: not enough qstk balance"
        );

        require(!locked, "QAirdrop: locked");
        require(!claimed[_signature], "QAirdrop: already claimed");
        IERC20Upgradeable(qstk).safeTransfer(_recipient, _qstkAmount);

        claimed[_signature] = true;
        emit ClaimQStk(_recipient, _qstkAmount);
    }

    function withdrawLockedQStk(
        address _recipient,
        uint256 _qstkAmount,
        bytes memory _signature
    ) external nonReentrant {
        require(
            _verify(_recipient, _qstkAmount, _signature),
            "QAirdrop: invalid signature"
        );

        address qstk = settings.qstk();

        require(
            IERC20Upgradeable(qstk).balanceOf(address(this)) >= _qstkAmount,
            "QAirdrop: not enough qstk balance"
        );

        require(
            AddressUpgradeable.isContract(msg.sender),
            "QAirdrop: not contract address"
        );

        require(
            whitelistedContracts[msg.sender],
            "QAirdrop: not whitelisted contract"
        );

        require(!claimed[_signature], "QAirdrop: already claimed");

        IERC20Upgradeable(qstk).safeTransfer(msg.sender, _qstkAmount);

        claimed[_signature] = true;

        emit ClaimQStk(_recipient, _qstkAmount);
    }

    function getMessageHash(address _to, uint256 _amount)
        public
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(_to, _amount));
    }

    // internal functions

    function _addWhitelistedContract(address _contract) internal {
        require(
            AddressUpgradeable.isContract(_contract),
            "QAirdrop: not contract address"
        );

        whitelistedContracts[_contract] = true;
    }

    function _removeWhitelistedContract(address _contract) internal {
        require(
            AddressUpgradeable.isContract(_contract),
            "QAirdrop: not contract address"
        );

        whitelistedContracts[_contract] = false;
    }

    function _verify(
        address _recipient,
        uint256 _qstkAmount,
        bytes memory signature
    ) internal view returns (bool) {
        bytes32 messageHash = getMessageHash(_recipient, _qstkAmount);
        bytes32 ethSignedMessageHash = _getEthSignedMessageHash(messageHash);

        return _recoverSigner(ethSignedMessageHash, signature) == verifier;
    }

    function _getEthSignedMessageHash(bytes32 _messageHash)
        internal
        pure
        returns (bytes32)
    {
        /*
        Signature is produced by signing a keccak256 hash with the following format:
        "\x19Ethereum Signed Message\n" + len(msg) + msg
        */
        return
            keccak256(
                abi.encodePacked(
                    "\x19Ethereum Signed Message:\n32",
                    _messageHash
                )
            );
    }

    function _recoverSigner(
        bytes32 ethSignedMessageHash,
        bytes memory _signature
    ) internal pure returns (address) {
        (bytes32 r, bytes32 s, uint8 v) = _splitSignature(_signature);

        return ecrecover(ethSignedMessageHash, v, r, s);
    }

    function _splitSignature(bytes memory sig)
        internal
        pure
        returns (
            bytes32 r,
            bytes32 s,
            uint8 v
        )
    {
        require(sig.length == 65, "invalid signature length");

        assembly {
            /*
            First 32 bytes stores the length of the signature

            add(sig, 32) = pointer of sig + 32
            effectively, skips first 32 bytes of signature

            mload(p) loads next 32 bytes starting at the memory address p into memory
            */

            // first 32 bytes, after the length prefix
            r := mload(add(sig, 32))
            // second 32 bytes
            s := mload(add(sig, 64))
            // final byte (first byte of the next 32 bytes)
            v := byte(0, mload(add(sig, 96)))
        }

        // implicitly return (r, s, v)
    }
}