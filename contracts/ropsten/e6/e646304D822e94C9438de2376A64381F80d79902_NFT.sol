// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract NFT is ERC721URIStorage, ERC721Enumerable, AccessControl {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    event UpdateReward(uint256 indexed _pid, uint256 _expMinutes, uint256 _requiredPoints, bool _active);
    event Redeem(uint256 indexed tokenId, uint256 _pid, address to, string  _tokenURI);
    struct RewardInfo {
        uint256 pid;
        uint256 expMinutes;
        uint256 requiredPoints;
        bool active;
    }

    // _pid => RewardInfo
    mapping(uint256 => RewardInfo) public rewardInfo;
    // nft token ID => RewardInfo
    mapping(uint256 => RewardInfo) public nftCouponInfo;

    constructor(
        address minter,
        address burner,
        string memory name,
        string memory symbol
    ) ERC721(name, symbol) {
        _setupRole(DEFAULT_ADMIN_ROLE, minter);
        _setupRole(MINTER_ROLE, minter);
        _setupRole(BURNER_ROLE, burner);
    }

    function updateReward(uint256 _pid, uint256 _expMinutes, uint256 _requiredPoints, bool _active ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        RewardInfo storage _rewardInfo = rewardInfo[_pid];
        _rewardInfo.expMinutes = _expMinutes;
        _rewardInfo.requiredPoints = _requiredPoints;
        _rewardInfo.active = _active;
        _rewardInfo.pid = _pid;
        emit UpdateReward(_pid, _expMinutes, _requiredPoints, _active);
    }

    function mint(address customer, string memory _tokenURI, uint256 _pid)
        public
        onlyRole(MINTER_ROLE)
        returns (uint256)
    {
        RewardInfo memory _rewardInfo = rewardInfo[_pid];
        require(_rewardInfo.active, "MintError: This reward is not activated");
        _tokenIds.increment();
        uint256 newItemId = _tokenIds.current();
        _mint(customer, newItemId);
        _setTokenURI(newItemId, _tokenURI);
        _rewardInfo.expMinutes = block.timestamp + rewardInfo[_pid].expMinutes * 1 minutes;
        _rewardInfo.pid = _pid;
        nftCouponInfo[newItemId] = _rewardInfo;
        emit Redeem(newItemId, _pid, customer,  _tokenURI);
        return newItemId;
    }

    function burn(uint256 tokenId) public onlyRole(BURNER_ROLE) {
        _burn(tokenId);
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId)
        internal
        override(ERC721, ERC721Enumerable)
    {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }
    
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}