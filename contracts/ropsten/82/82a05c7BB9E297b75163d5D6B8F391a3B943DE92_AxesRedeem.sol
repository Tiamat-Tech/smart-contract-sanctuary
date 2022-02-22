pragma solidity 0.8.12;

// ===========================================================================
// © 2022 QBEIN LLC. All rights reserved. https://qbein.net/
// All codes are exclusive property of QBEIN LLC. 
// This work may not be copied or duplicated in whole or part by any means 
// without express prior agreement in writing given by QBEIN LLC.
// ===========================================================================

// SPDX-License-Identifier: UNLICENSED

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

interface IERC721 {
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
    function burn(uint256 tokenId) external;
    function tokenFullInfo(uint256 tokenId) external view returns (address owner, string memory tokenUri, string memory tokenRnd, string memory tokenItem, string memory tokenData, uint tokenSeason);
}

contract AxesRedeem is ReentrancyGuard, ERC721Holder, AccessControl {
    using SafeMath for uint256;

    uint256 public redeemId;
    address public contract721;
    bool public running;
    
    mapping(uint256 => uint256[]) burnedInId;

    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        contract721 = 0x1672F0b49adcBBF393Ae3270D6544eAE02b1fec7;
        running = true;
    }

    mapping (uint256 => BurnedTokenInfo) token;

    struct BurnedTokenInfo {
        bool burned;
        uint256 redeemId;
        uint256 redeemAmount;
        address owner;
        string tokenItem;
        string tokenData;
    }

    event Redeem(uint256 indexed _id, address indexed owner, uint256[] tokens);
    event Running(bool indexed running);

    function redeem(address _from, uint256[] memory _ids) external nonReentrant returns (uint256 _redeemId) {
        require(running, "Contract stopped.");
        require(_ids.length <= 10, "Decrease tokens amount. <=10");
        redeemId = redeemId.add(1);
        for (uint i; i < _ids.length; i++) {
            IERC721(contract721).safeTransferFrom(_from, address(this), _ids[i]);
            burnedInId[redeemId].push(_ids[i]);
            string memory _tokenItem;
            string memory _tokenData;
            (,,,_tokenItem,_tokenData,) = IERC721(contract721).tokenFullInfo(_ids[i]);
            token[_ids[i]] = BurnedTokenInfo(true, redeemId, _ids.length, _from, _tokenItem, _tokenData);
            IERC721(contract721).burn(_ids[i]);
        }
        emit Redeem(redeemId, _from, burnedInId[redeemId]);
        return redeemId;
    }

    function redeemIdInfo(uint256 _id) external view returns (uint256[] memory tokens, address owner) {
        require(burnedInId[_id].length > 0, "Nonexistent redeem ID.");
        return (burnedInId[_id],token[burnedInId[_id][0]].owner);
    }

    function tokenIdInfo(uint256 _id) external view returns (bool _burned, uint256 _redeemId, uint256 _redeemAmount, address _owner, string memory _tokenItem, string memory _tokenData) {
        return (token[_id].burned, token[_id].redeemId, token[_id].redeemAmount, token[_id].owner, token[_id].tokenItem, token[_id].tokenData);
    }

    function startStop() external {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "You must have admin role to start/stop contract.");
        running = !running;
        emit Running(running);
    }
}