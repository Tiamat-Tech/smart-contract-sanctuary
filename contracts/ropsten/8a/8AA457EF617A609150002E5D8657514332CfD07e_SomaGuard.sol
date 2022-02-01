// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";

import "../SomaNetwork/utils/NetworkAccessUpgradeable.sol";

import "./ISomaGuard.sol";

contract SomaGuard is ISomaGuard, NetworkAccessUpgradeable {
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;

    mapping(address => bytes32) private _access;
    EnumerableSetUpgradeable.AddressSet private _approvedContracts;
    EnumerableSetUpgradeable.AddressSet private _accounts;

    bytes32 public constant OPERATOR_ROLE = keccak256("SomaGuard:operator");
    bytes32 public constant override DEFAULT_ACCESS = bytes32(uint256(2 ** 64 - 1));
    bytes32 public constant override NETWORK_KEY = bytes32('SomaGuard');

    function initialize(address networkAddress) external initializer {
        __NetworkAccess_init(networkAddress);
    }

    function VERSION() public pure virtual override returns (bytes32) {
        return bytes32('v1.0.0');
    }

    function switchOn(uint256[] memory ids, bytes32 base) public pure override returns (bytes32 result) {
        result = base;
        for (uint i = 0; i < ids.length; i++) {
            result = result | bytes32(2**ids[i]);
        }
    }

    function switchOff(uint256[] memory ids, bytes32 base) public pure override returns (bytes32 result) {
        result = base;
        for (uint i = 0; i < ids.length; i++) {
            result = result & bytes32(type(uint256).max - 2**ids[i]);
        }
    }

    function merge(bytes32 access1, bytes32 access2) public pure override returns (bytes32) {
        return access1 | access2;
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(ISomaGuard).interfaceId || super.supportsInterface(interfaceId);
    }

    function approvedContract(address account) public view override returns (bool) {
        return _approvedContracts.contains(account);
    }

    function check(address account, bytes32 query) public view override returns (bool) {
        return access(account) & query == query;
    }

    function has(address account, uint256[] memory ids) external view override returns (bool) {
        return check(account, switchOn(ids, 0));
    }

    function access(address account) public override virtual view returns (bytes32) {
        // this is to protect against addresses that are considered a contract.
        // they have to be manually approved, preventing someone from creating a proxy contract.
//        if (AddressUpgradeable.isContract(account) && !_approvedContracts.contains(account)) { // TODO confirm this
//            return bytes32(uint256(3));
//        } else
        if (_accounts.contains(account)) {
            return _access[account];
        }

        return DEFAULT_ACCESS;
    }

    function totalAccounts() public view override returns (uint256) {
        return _accounts.length();
    }

    function totalApprovedContracts() public view returns (uint256) {
        return _approvedContracts.length();
    }

    function listAccounts(uint256 _currentIndex, uint256 totalToTake)
    external
    view
    override
    onlyRole(OPERATOR_ROLE)
    returns (
        uint256 totalRecords,
        uint256 currentIndex,
        address[] memory accounts_,
        bytes32[] memory access_,
        bool[] memory contractApprovals_
    ) {
        currentIndex = _currentIndex;
        totalRecords = totalAccounts();

        uint256 remaining = totalRecords - currentIndex;
        uint256 maxLength = totalToTake > remaining ? remaining : totalToTake;

        accounts_ = new address[](maxLength);
        access_ = new bytes32[](maxLength);
        contractApprovals_ = new bool[](maxLength);

        for (uint i = 0; i < maxLength; i++) {
            accounts_[i] = _accounts.at(i);
            access_[i] = _access[accounts_[i]];
            contractApprovals_[i] = _approvedContracts.contains(accounts_[i]);
        }
    }

    function listApprovedContracts(uint256 _currentIndex, uint256 totalToTake)
    external
    view
    onlyRole(OPERATOR_ROLE)
    returns (
        uint256 totalRecords,
        uint256 currentIndex,
        address[] memory contracts_
    ) {
        currentIndex = _currentIndex;
        totalRecords = totalApprovedContracts();

        uint256 remaining = totalRecords - currentIndex;
        uint256 maxLength = totalToTake > remaining ? remaining : totalToTake;

        contracts_ = new address[](maxLength);

        for (uint i = 0; i < maxLength; i++) {
            contracts_[i] = _approvedContracts.at(i);
        }
    }

    function batchContractUpdate(
        address[] calldata approveContracts,
        address[] calldata rejectContracts
    ) external override onlyRole(OPERATOR_ROLE) returns (bool) {
        address account;

        for (uint i = 0; i < approveContracts.length; i++) {
            account = approveContracts[i];

            if (!_approvedContracts.contains(account)) {
                emit ContractApproved(_msgSender(), account);
            }

            _approvedContracts.add(account);
        }

        for (uint i = 0; i < rejectContracts.length; i++) {
            account = rejectContracts[i];

            if (_approvedContracts.contains(account)) {
                emit ContractUnapproved(_msgSender(), account);
            }

            _approvedContracts.remove(account);
        }

        emit BatchContractUpdate(_msgSender(), approveContracts, rejectContracts);

        return true;
    }

    function batchAccessUpdate(
        address[][] calldata accounts_,
        bytes32[] calldata access_
    ) external override onlyRole(OPERATOR_ROLE) returns (bool) {
        require(accounts_.length == access_.length, 'SomaGuard: accounts and access must have the same length');

        for (uint i = 0; i < accounts_.length; i++) {
            bytes32 newAccess = access_[i];

            for (uint j = 0; j < accounts_[i].length; j++) {
                address account = accounts_[i][j];

                emit AccessUpdated(_msgSender(), _access[account], newAccess, account);

                _access[account] = newAccess;
                if (newAccess == DEFAULT_ACCESS) {
                    _accounts.remove(account);
                } else {
                    _accounts.add(account);
                }
            }
        }

        emit BatchAccessUpdate(_msgSender(), accounts_, access_);

        return true;
    }
}