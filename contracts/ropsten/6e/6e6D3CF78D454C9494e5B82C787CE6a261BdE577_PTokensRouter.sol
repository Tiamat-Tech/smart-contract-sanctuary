// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./interfaces/IPToken.sol";
import "./PTokensMetadataDecoder.sol";
import "./ConvertAddressToString.sol";
import "./interfaces/IOriginChainIdGetter.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/interfaces/IERC777.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/interfaces/IERC1820RegistryUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC777/IERC777RecipientUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";

interface IVault {
    function pegIn(
        uint256 _tokenAmount,
        address _tokenAddress,
        string memory _destinationAddress,
        bytes memory _userData,
        bytes4 _destinationChainId
    ) external returns (bool);
}

contract PTokensRouter is
    Initializable,
    PTokensMetadataDecoder,
    ConvertAddressToString,
    IERC777RecipientUpgradeable,
    AccessControlEnumerableUpgradeable
{
    address public SAFE_VAULT_ADDRESS;
    bytes4 public constant ORIGIN_CHAIN_ID = 0xffffffff;
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant TOKENS_RECIPIENT_INTERFACE_HASH = keccak256("ERC777TokensRecipient");
    mapping(bytes4 => address) public interimVaultAddresses;

    function initialize (
        address safeVaultAddress
    )
        public initializer
    {
        IERC1820RegistryUpgradeable(0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24).setInterfaceImplementer(
            address(this),
            TOKENS_RECIPIENT_INTERFACE_HASH,
            address(this)
        );
        _setupRole(ADMIN_ROLE, _msgSender());
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        SAFE_VAULT_ADDRESS = safeVaultAddress;
    }

    modifier onlyAdmin() {
        require(
            hasRole(DEFAULT_ADMIN_ROLE, _msgSender()) || hasRole(ADMIN_ROLE, _msgSender()),
            "Caller is not an admin!"
        );
        _;
    }

    function updateSafeVaultAddress(
        address newSafeVaultAddress
    )
        external
        onlyAdmin
        returns (bool success)
    {
        SAFE_VAULT_ADDRESS = newSafeVaultAddress;
        return true;
    }

    function addVaultAddress(
        bytes4 _chainId,
        address _vaultAddress
    )
        external
        onlyAdmin
        returns (bool success)
    {
        interimVaultAddresses[_chainId] = _vaultAddress;
        return true;
    }

    function removeVaultAddress(
        bytes4 _chainId
    )
        external
        onlyAdmin
        returns (bool success)
    {
        delete interimVaultAddresses[_chainId];
        return true;
    }

    function getOriginChainIdFromContract(
        address _contractAddress
    )
        public
        returns (bytes4)
    {
        return IOriginChainIdGetter(_contractAddress).ORIGIN_CHAIN_ID();
    }

    function safelyGetVaultAddress(
        bytes4 chainId
    )
        view
        public
        returns (address vaultAddress)
    {
        vaultAddress = interimVaultAddresses[chainId];
        if (vaultAddress == address(0)) {
            return SAFE_VAULT_ADDRESS;
        } else {
            return vaultAddress;
        }
    }

    function tokensReceived(
        address /* _operator */, // NOTE: Enclave address.
        address /* _from */, // NOTE: Enclave address.
        address /* _to */, // NOTE: This contract's address.
        uint256 _amount,
        bytes calldata _userData,
        bytes calldata /* _operatorData */
    )
        external
        override
    {
        (
            ,
            bytes memory userData,
            ,
            ,
            bytes4 destinationChainId,
            address destinationAddress,
            ,
        ) = decodeMetadataV2(_userData);
        address tokenAddress = msg.sender;
        string memory destinationAddressString = convertAddressToString(destinationAddress);
        if (getOriginChainIdFromContract(tokenAddress) == destinationChainId) {
            // NOTE: This is a full peg-out of tokens back to their native chain.
            IPToken(tokenAddress).redeem(
                _amount,
                userData,
                destinationAddressString,
                destinationChainId
            );
        } else {
            // NOTE: This is either from a peg-in, or a peg-out to a different host chain.
            address vaultAddress = safelyGetVaultAddress(destinationChainId);
            IERC20(tokenAddress).approve(vaultAddress, _amount);
            IVault(vaultAddress).pegIn(
                _amount,
                tokenAddress,
                destinationAddressString,
                userData,
                destinationChainId
            );
        }
    }
}