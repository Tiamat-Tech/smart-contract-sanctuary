pragma solidity 0.8.12;

// ===========================================================================
// © 2022 QBEIN LLC. All rights reserved. https://qbein.net/
// All codes are exclusive property of QBEIN LLC. 
// This work may not be copied or duplicated in whole or part by any means 
// without express prior agreement in writing given by QBEIN LLC.
// ===========================================================================

// SPDX-License-Identifier: UNLICENSED

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

interface IERC721 {
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
    function burn(uint256 tokenId) external;
    function tokenFullInfo(uint256 tokenId) external view returns (address owner, string memory tokenUri, string memory tokenRnd, string memory tokenItem, string memory tokenData, uint tokenSeason);
}

contract AxesRedeem is AccessControl, ReentrancyGuard, ERC721Holder {
    using SafeMath for uint256;
    using Address for address;
    using EnumerableSet for EnumerableSet.AddressSet;

    uint256 public redeemId;
    
    mapping(uint256 => uint256[]) burnedInId;

    EnumerableSet.AddressSet private contractsWhitelist;

    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    mapping (uint256 => BurnedTokenInfo) token;

    struct BurnedTokenInfo {
        bool burned;
        address owner;
        string tokenItem;
        string tokenData;
    }

    event ChangeContractWhiteList(address indexed _contract, bool indexed);
    event Redeem(uint256 indexed _id, address indexed owner, uint256[] tokens);

    function redeem(address _from, address _contract721, uint256[] memory _ids) external nonReentrant returns (uint256 _redeemId) {
        require(_ids.length < 100);
        //require(contractsWhitelist.contains(_contract721), "ERC721 contract is not in whitelist.");
        redeemId = redeemId.add(1);
        for (uint i; i < _ids.length; i++) {
            IERC721(_contract721).safeTransferFrom(_from, address(this), _ids[i]);
            burnedInId[_ids[i]].push(redeemId);
            string memory _tokenItem;
            string memory _tokenData;
            (,,,_tokenItem,_tokenData,) = IERC721(_contract721).tokenFullInfo(_ids[i]);
            token[_ids[i]] = BurnedTokenInfo(true, _from, _tokenItem, _tokenData);
            IERC721(_contract721).burn(_ids[i]);
        }
        emit Redeem(redeemId, _from, burnedInId[redeemId]);
        return redeemId;
    }

    function redeemIdInfo(uint256 _id) external view returns (uint256[] memory) {
        return burnedInId[_id];
    }

    function tokenIdInfo(uint256 _id) external view returns (bool _burned, address _owner, string memory _tokenItem, string memory _tokenData) {
        return (token[_id].burned, token[_id].owner, token[_id].tokenItem, token[_id].tokenData);
    }

    function whitelistedContracts() external view returns (address[] memory) {
        return contractsWhitelist.values();
    }

    function addToWhitelist(address _contract) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "You must have admin role to add contract to whitelist.");
        require(_contract.isContract(), "Address is not a contract.");
        require(contractsWhitelist.add(_contract), "Contact is already in whitelist.");
        emit ChangeContractWhiteList(_contract, true);
    }

    function removeFromWhitelist(address _contract) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "You must have admin role to remove contract from whitelist.");
        require(contractsWhitelist.remove(_contract), "Where is no such contract in whitelist.");
        emit ChangeContractWhiteList(_contract, false);
    }

}