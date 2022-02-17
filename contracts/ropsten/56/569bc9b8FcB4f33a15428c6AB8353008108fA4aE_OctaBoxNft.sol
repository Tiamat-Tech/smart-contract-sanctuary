// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155SupplyUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract OctaBoxNft is Initializable, ERC1155Upgradeable, OwnableUpgradeable, PausableUpgradeable, ERC1155BurnableUpgradeable, ERC1155SupplyUpgradeable {
    /// @custom:oz-upgrades-unsafe-allow constructor

    /// rarity => 0 common, 1 rare, 2 epic, 3 legendary, 4 

    using Counters for Counters.Counter;
    Counters.Counter public boxTypeIds;
    //mapping(uint256 => Counters.Counter) public boxTypeIds;  // tokenId => boxTypeIds

    address private adminAddress;

    address[] private whitelistAddress;
    mapping(address => uint256) private whitelistBoxTypeId;  // ownerWhitelist => box Type Id
    mapping(address => uint256) private whitelistBoxQuota;  // ownerWhitelist => box Quota
    mapping(address => bool) private isWhitelistAddress;  // ownerWhitelist => is whitelist
    mapping(address => bool) private isClaimed;  // ownerWhitelist => Claimed

    uint256[] public allBoxTypeIds;  
    mapping(uint => uint) private allBoxTypeIdsIndex; //index must be -1

    function setWhitelist(address[] memory _whitelistList, uint256[] memory _boxTypeIdList, uint256[] memory _boxQuotaList) external onlyAdmin {
        uint256 _whitelistCount = _whitelistList.length;
        require(_whitelistCount > 0, "Whitelist address is Empty");
        uint256 _boxTypeIdListCount = _boxTypeIdList.length;
        require(_boxTypeIdListCount > 0, "Box type id is Empty");
        uint256 _boxQuotaListCount = _boxQuotaList.length;
        require(_boxQuotaListCount > 0, "Box Quota is Empty");
        require((_whitelistCount == _boxTypeIdListCount) && (_whitelistCount == _boxTypeIdListCount) && (_whitelistCount == _boxQuotaListCount), "All List missmatch");

        for (uint256 idx = 0; idx < _whitelistList.length; idx++) {
            whitelistAddress.push(_whitelistList[idx]);
            isWhitelistAddress[_whitelistList[idx]] = true;
            whitelistBoxTypeId[_whitelistList[idx]] = _boxTypeIdList[idx];
            whitelistBoxQuota[_whitelistList[idx]] = _boxQuotaList[idx];
        }
    }

    function removeWhitelist(address[] memory _whitelistList, uint256[] memory _boxTypeIdList) external onlyAdmin {
        uint256 _whitelistCount = _whitelistList.length;
        require(_whitelistCount > 0, "Whitelist address is Empty");
        uint256 _boxTypeIdListCount = _boxTypeIdList.length;
        require(_boxTypeIdListCount > 0, "Box type id is Empty");

        for (uint256 idx = 0; idx < _whitelistList.length; idx++) {
            delete isWhitelistAddress[_whitelistList[idx]];
            delete whitelistBoxTypeId[_whitelistList[idx]];
            delete whitelistBoxQuota[_whitelistList[idx]];
            delete isClaimed[_whitelistList[idx]];
        }
    }

    function getWhitelistByAccount(address _address) external view returns (bool _isWhl, bool _isClm, uint256 _boxType, uint256 _boxQuota) {
        _isWhl = isWhitelistAddress[_address];
        _isClm = isClaimed[_address];
        _boxType = whitelistBoxTypeId[_address];
        _boxQuota = whitelistBoxQuota[_address];
       return (_isWhl, _isClm, _boxType, _boxQuota);
    }

    event claimedAirdropWhitelistEvent(address indexed to, uint256 _boxType, uint256 _boxQuota);

    function claimedAirdropWhitelist() public {
        uint256 _boxType = whitelistBoxTypeId[msg.sender];
        uint256 _boxQuota = whitelistBoxQuota[msg.sender];
        uint256 boxBalance = this.balanceOf(owner(), _boxType);

        require(isWhitelistAddress[msg.sender] == true, "Do not have whitelist");
        require(isClaimed[msg.sender] == false, "You have claimed all rights.");
        require(boxBalance >= _boxQuota, "NFT not enough.");

        _safeTransferFrom(owner(), msg.sender, _boxType, _boxQuota, toBytes(_boxQuota));

        isClaimed[msg.sender] = true;

        emit claimedAirdropWhitelistEvent(msg.sender, _boxType, _boxQuota);
    }

    function getAllBoxTypeIds() public view returns (uint256[] memory) {
        uint256[] memory _arr = new uint256[](allBoxTypeIds.length);
        for (uint256 i = 0; i < allBoxTypeIds.length; i++) {
            _arr[i] = allBoxTypeIds[i];
        }
        return _arr;
    }

    function toBytes(uint256 x) private pure returns (bytes memory b) {
         b = new bytes(32);
         assembly { mstore(add(b, 32), x) }
    }

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    function mint(address account, uint256 id, uint256 amount, bytes memory data)
        public onlyOwner
    {
        _mint(account, id, amount, data);

        if (allBoxTypeIdsIndex[id] <= 0) {
            allBoxTypeIds.push(id);
            allBoxTypeIdsIndex[id] = allBoxTypeIds.length;
        }
    }

    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data)
        public onlyOwner
    {
        _mintBatch(to, ids, amounts, data);

        for (uint256 i = 0; i < ids.length; i++) {
            if (allBoxTypeIdsIndex[ids[i]] <= 0) {
                allBoxTypeIds.push(ids[i]);
                allBoxTypeIdsIndex[ids[i]] = allBoxTypeIds.length;
            }
        }
    }

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

//    constructor() initializer {}

    function initialize() initializer public {
        __ERC1155_init("https://nfts.octa.games/");
        __Ownable_init();
        __Pausable_init();
        __ERC1155Burnable_init();
        __ERC1155Supply_init();
    }

    modifier onlyAdmin() {
        require(msg.sender == adminAddress, "only Admin");
        _;
    }

    function setAdmin(address _newAdmin) external onlyOwner {
        adminAddress = _newAdmin;
    }

    function isAdminAddress(address _chkAdmin) external view returns (bool) {
        return adminAddress == _chkAdmin;
    }

    function setURI(string memory newuri) public onlyOwner {
        _setURI(newuri);
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function _beforeTokenTransfer(address operator, address from, address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data)
        internal whenNotPaused override(ERC1155Upgradeable, ERC1155SupplyUpgradeable)
    {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }
}