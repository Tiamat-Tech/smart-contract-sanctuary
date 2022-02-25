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
    event UpdateReward(
        uint256 indexed pid,
        uint256 expMinutes,
        uint256 requiredPoints,
        string tokenURI,
        uint256 limit,
        bool active,
        address updater
    );
    event AddReward(
        uint256 indexed pid,
        uint256 expMinutes,
        uint256 requiredPoints,
        string tokenURI,
        uint256 limit,
        bool active,
        address updater
    );
    event Redeem(
        uint256 indexed tokenId,
        uint256 pid,
        address to,
        string tokenURI
    );
    struct RewardInfo {
        uint256 pid;
        uint256 expMinutes;
        uint256 requiredPoints;
        string tokenURI;
        uint256 limit;
        uint256 redeemed;
        bool active;
    }

    struct NftCouponInfo {
        uint256 pid;
        uint256 expMinutes;
        uint256 requiredPoints;
        uint256 tokenId;
        bool isRedeemed;
    }

    // _pid => RewardInfo
    RewardInfo[] public rewardInfo;
    // nft token ID => RewardInfo
    mapping(uint256 => NftCouponInfo) public nftCouponInfo;

    constructor(
        address minter,
        address burner,
        address admin,
        string memory name,
        string memory symbol
    ) ERC721(name, symbol) {
        _setupRole(DEFAULT_ADMIN_ROLE, admin);
        _setupRole(MINTER_ROLE, minter);
        _setupRole(BURNER_ROLE, burner);
    }

    function rewardLength() public view returns (uint256) {
        return rewardInfo.length;
    }

    function addReward(
        uint256 _expMinutes,
        uint256 _requiredPoints,
        string memory _tokenURI,
        uint256 _limit
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 _rewardLength = rewardLength();
        rewardInfo.push(
            RewardInfo({
                limit: _limit,
                redeemed: 0,
                expMinutes: _expMinutes,
                requiredPoints: _requiredPoints,
                active: true,
                pid: _rewardLength,
                tokenURI: _tokenURI
            })
        );
        emit AddReward(
            _rewardLength,
            _expMinutes,
            _requiredPoints,
            _tokenURI,
            _limit,
            true,
            _msgSender()
        );
    }

    function updateReward(
        uint256 _pid,
        uint256 _expMinutes,
        uint256 _requiredPoints,
        string memory _tokenURI,
        uint256 _limit,
        bool _active
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        RewardInfo storage _rewardInfo = rewardInfo[_pid];
        _rewardInfo.expMinutes = _expMinutes;
        _rewardInfo.active = _active;
        _rewardInfo.tokenURI = _tokenURI;
        _rewardInfo.requiredPoints = _requiredPoints;
        _rewardInfo.limit = _limit;
        emit UpdateReward(
            _pid,
            _expMinutes,
            _requiredPoints,
            _tokenURI,
            _limit,
            _active,
            _msgSender()
        );
    }

    function mint(address customer, uint256 _pid)
        public
        onlyRole(MINTER_ROLE)
        returns (uint256)
    {
        RewardInfo memory _rewardInfo = rewardInfo[_pid];
        require(_rewardInfo.active, "ERROR: This reward is not activated");
        _tokenIds.increment();
        uint256 newItemId = _tokenIds.current();
        _mint(customer, newItemId);
        _setTokenURI(newItemId, _rewardInfo.tokenURI);

        nftCouponInfo[newItemId] = NftCouponInfo({
            pid: _pid,
            expMinutes: block.timestamp +
                rewardInfo[_pid].expMinutes *
                1 minutes,
            requiredPoints: _rewardInfo.requiredPoints,
            tokenId: newItemId,
            isRedeemed: false
        });

        rewardInfo[_pid].redeemed++;

        emit Redeem(newItemId, _pid, customer, _rewardInfo.tokenURI);
        return newItemId;
    }

    function burn(uint256 tokenId) public onlyRole(BURNER_ROLE) {
        nftCouponInfo[tokenId].isRedeemed = true;
        _burn(tokenId);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function _burn(uint256 tokenId)
        internal
        override(ERC721, ERC721URIStorage)
    {
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