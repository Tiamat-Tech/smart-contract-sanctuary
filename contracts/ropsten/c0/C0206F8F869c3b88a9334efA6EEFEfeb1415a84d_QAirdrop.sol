// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import "./interface/IQSettings.sol";

/**
 * @author fantasy
 */
contract QAirdrop is ContextUpgradeable, ReentrancyGuardUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using ECDSAUpgradeable for bytes32;

    // events
    event AddWhitelistedContract(address indexed whitelisted);
    event RemoveWhitelistedContract(address indexed whitelisted);
    event SetVerifier(address indexed verifier);
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

    function splitAirdropKey(bytes memory airdropKey)
        public
        pure
        returns (uint256, bytes memory)
    {
        uint256 length = airdropKey.length;
        require(length == 80 || length == 81, "QAirdrop: invalid airdrop key");

        // first 16 bytes -> amount

        uint128 amount;
        assembly {
            amount := mload(add(add(airdropKey, 16), 0))
        }

        // rest bytes -> signature

        bytes memory signature = new bytes(length - 16);

        for (uint256 i = 16; i < length; i++) {
            signature[i - 16] = airdropKey[i];
        }

        return (amount, signature);
    }

    function verify(address _recipient, bytes memory _airdropKey)
        public
        view
        returns (bool)
    {
        (uint256 qstkAmount, bytes memory signature) =
            splitAirdropKey(_airdropKey);

        return _verify(_recipient, qstkAmount, signature);
    }

    function claimQStk(address _recipient, bytes memory _airdropKey)
        external
        nonReentrant
    {
        (uint256 qstkAmount, bytes memory signature) =
            splitAirdropKey(_airdropKey);

        require(
            _verify(_recipient, qstkAmount, signature),
            "QAirdrop: invalid signature"
        );

        address qstk = settings.qstk();

        require(
            IERC20Upgradeable(qstk).balanceOf(address(this)) >= qstkAmount,
            "QAirdrop: not enough qstk balance"
        );

        require(!locked, "QAirdrop: locked");
        require(!claimed[signature], "QAirdrop: already claimed");
        IERC20Upgradeable(qstk).safeTransfer(_recipient, qstkAmount);

        claimed[signature] = true;
        emit ClaimQStk(_recipient, qstkAmount);
    }

    function withdrawLockedQStk(address _recipient, bytes memory _airdropKey)
        external
        nonReentrant
        returns (uint256)
    {
        (uint256 qstkAmount, bytes memory signature) =
            splitAirdropKey(_airdropKey);

        require(
            _verify(_recipient, qstkAmount, signature),
            "QAirdrop: invalid signature"
        );
        address qstk = settings.qstk();

        require(
            IERC20Upgradeable(qstk).balanceOf(address(this)) >= qstkAmount,
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

        require(!claimed[signature], "QAirdrop: already claimed");

        IERC20Upgradeable(qstk).safeTransfer(msg.sender, qstkAmount);

        claimed[signature] = true;

        emit ClaimQStk(_recipient, qstkAmount);

        return qstkAmount;
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

        return
            messageHash.toEthSignedMessageHash().recover(signature) == verifier;
    }

    uint256[50] private __gap;
}