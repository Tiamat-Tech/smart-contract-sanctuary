//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

// import "hardhat/console.sol";

contract Miner is
    ReentrancyGuard,
    AccessControl,
    Pausable
{
    using SafeERC20 for IERC20;

    /*** Events ***/
    event SkuInfoAdded(uint256 indexed skuId, uint256 unitPrice, uint256 stockSize, address paymentToken, address pRewardToken, address xRewardToken, uint256 lifeTime);
    event SkuInfoUpdated(uint256 indexed skuId, uint256 unitPrice, uint256 stockSize);
    event Purchased(address indexed user, uint256 indexed skuId, uint256 size, uint256 cost, uint256 tokenId);
    event WithdrawFund(address indexed to, address indexed tokenAddr, uint256 amount);
    event Claimed(address indexed user, uint256 skuId, uint256 pRewardAmount, uint256 xRewardAmount, uint256 prevRewardIndex, uint256 curRewardIndex, uint256 tm);

    /*** Constants ***/

    /*** Storage Properties ***/

    struct SkuInfo {
        uint256 unitPrice;
        uint256 stockSize;
        address paymentToken;
        address pRewardToken;
        address xRewardToken;
        uint256 lifeTime;
    }

    mapping(uint256 => SkuInfo) public skus;
    mapping(address => mapping(uint256 => uint256)) public userPrevClaimedRewardIndexes;
    mapping(uint256 => uint256) public maxClaimedRewardIndexes;

    address public pNftToken;
    address public sNftToken;
    address public maintainer;

    /*** Contract Logic Starts Here ***/

    constructor(
        address _admin,
        address _pNftToken,
        address _maintainer
    ) {
        _setupRole(DEFAULT_ADMIN_ROLE, _admin);

        pNftToken = _pNftToken;
        maintainer = _maintainer;
    }

    // ---------------------------------------------------------
    // User operations

    function purchase(uint256 skuId, uint256 size) external nonReentrant whenNotPaused returns (uint256) {
        require(skus[skuId].pRewardToken != address(0), "SkuId not existed");
        require(size > 0, "Invalid size param");
        uint256 currentStockSize = skus[skuId].stockSize;
        require(currentStockSize >= size, "Insufficient stock");

        address user = _msgSender();

        // Transfer
        uint256 cost = size * skus[skuId].unitPrice;
        IERC20(skus[skuId].paymentToken).safeTransferFrom(user, address(this), cost);

        // Mint
        uint256 tokenId = IPNFT(pNftToken).mintPNFT(user, skuId, size);

        // Update
        skus[skuId].stockSize = currentStockSize - size;

        // Event
        emit Purchased(user, skuId, size, cost, tokenId);

        return tokenId;
    }

    function claim(
        uint256 _skuId,
        address _pRewardToken,
        uint256 _pRewardAmount,
        address _xRewardToken,
        uint256 _xRewardAmount,
        uint256 _prevRewardIndex,
        uint256 _curRewardIndex,
        bytes memory _signature
    ) external nonReentrant whenNotPaused {

        SkuInfo memory skuInfo = skus[_skuId];
        require(skuInfo.pRewardToken != address(0), "Invalid skuId");
        require(skuInfo.pRewardToken == _pRewardToken && skuInfo.xRewardToken == _xRewardToken, "Mismatched setting");
        require(_pRewardAmount > 0 || _xRewardAmount > 0, "Nothing to claim");

        address user = _msgSender();

        // Check rewardIndex
        require(_curRewardIndex > _prevRewardIndex, "Bad curRewardIndex");
        require(_curRewardIndex >= maxClaimedRewardIndexes[_skuId], "Invalid curRewardIndex");
        require(_prevRewardIndex == userPrevClaimedRewardIndexes[user][_skuId], "Invalid prevRewardIndex");
        
        // Check sig
        bytes32 data = keccak256(
            abi.encodePacked(
                user, 
                _skuId, 
                _pRewardToken, 
                _pRewardAmount, 
                _xRewardToken, 
                _xRewardAmount, 
                _prevRewardIndex,
                _curRewardIndex)
        );
        require(ECDSA.recover(ECDSA.toEthSignedMessageHash(data), _signature) == maintainer, "Invalid signer");

        // Update
        if (_curRewardIndex > maxClaimedRewardIndexes[_skuId]) {
            maxClaimedRewardIndexes[_skuId] = _curRewardIndex;
        }
        userPrevClaimedRewardIndexes[user][_skuId] = _curRewardIndex;

        // Transfer
        IERC20(_pRewardToken).safeTransfer(user, _pRewardAmount);
        IERC20(_xRewardToken).safeTransfer(user, _xRewardAmount);

        // Event
        emit Claimed(user, _skuId, _pRewardAmount, _xRewardAmount, _prevRewardIndex, _curRewardIndex, block.timestamp);
    }

    // ---------------------------------------------------------
    // Manage

    function addSku(
        uint256 skuId, 
        uint256 unitPrice,
        uint256 stockSize,
        address paymentToken,
        address pRewardToken,
        address xRewardToken,
        uint256 lifeTime
        ) external onlyRole(DEFAULT_ADMIN_ROLE) {

        require(paymentToken != address(0), "Bad paymentToken param");
        require(skus[skuId].pRewardToken == address(0), "SkuID already existed");

        skus[skuId] = SkuInfo(unitPrice, stockSize, paymentToken, pRewardToken, xRewardToken, lifeTime);

        emit SkuInfoAdded(skuId, unitPrice, stockSize, paymentToken, pRewardToken, xRewardToken, lifeTime);
    }

    function updateSku(uint256 skuId, uint256 unitPrice, uint256 stockSize) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(skus[skuId].pRewardToken != address(0), "SkuID not existed");
        require(unitPrice > 0, "Invalid unitPrice param");

        skus[skuId].unitPrice = unitPrice;
        skus[skuId].stockSize = stockSize;

        emit SkuInfoUpdated(skuId, unitPrice, stockSize);
    }

    function setMaintainer(address _maintainer) external onlyRole(DEFAULT_ADMIN_ROLE) {
        maintainer = _maintainer;
    }

    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    function withdrawFund(address token, address to, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {

        IERC20(token).safeTransfer(to, amount);

        emit WithdrawFund(to, token, amount);
    }

    // ---------------------------------------------------------
    // MISC

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}

interface IPNFT {
    function mintPNFT(address to, uint256 skuID, uint256 size) external returns (uint256);
}