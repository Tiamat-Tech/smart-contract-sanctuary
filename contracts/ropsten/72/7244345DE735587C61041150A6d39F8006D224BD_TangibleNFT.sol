// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.7;

import "./interfaces/ITangibleNFT.sol";
import "./interfaces/IFactory.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "./abstract/AdminAndFactoryAccess.sol";

contract TangibleNFT is AdminAndFactoryAccess, ERC1155, ITangibleNFT {
    using SafeERC20 for IERC20;

    mapping(uint256 => uint256) public override storageEndTime;
    mapping(uint256 => uint256) public override storageStartTime;
    mapping(uint256 => string) public override tokenBrand;

    uint256 public override storagePricePerYear;
    address public factory;

    constructor(address _factory) ERC1155("") {
        require(_factory != address(0), "ZFA");
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(FACTORY_ROLE, _factory);

        factory = _factory;
    }

    /// @inheritdoc ITangibleNFT
    function mint(uint256 tokenId, uint256 count, address to) external override onlyFactory() {
        ERC1155._mint(to, tokenId, count, "");
    }

    /// @inheritdoc ITangibleNFT
    function burn(uint256 tokenId, uint256 count, address from) external override onlyFactory() {
        ERC1155._burn(from, tokenId, count);
    }

    /// @inheritdoc ITangibleNFT
    function isStorageFeePaid(uint256 tokenId) public view override returns (bool) {
        return storageEndTime[tokenId] > block.timestamp;
    }

    function setStoragePricePerYear(uint256 _storagePricePerYear) external onlyAdmin() {
        if (storagePricePerYear != _storagePricePerYear) {
            emit StoragePricePerYearSet(storagePricePerYear, _storagePricePerYear);
            storagePricePerYear = _storagePricePerYear;
        }
    }

    /// @inheritdoc ITangibleNFT
    function payForStorage(uint256 tokenId, uint256 _years) external override {
        if (storageStartTime[tokenId] == 0) {
            storageStartTime[tokenId] = block.timestamp;
        }

        uint256 endTime = storageEndTime[tokenId];
        storageEndTime[tokenId] = endTime == 0 ? block.timestamp + 365 days : endTime + 365 days;

        uint256 amount = storagePricePerYear * _years;

        emit StorageFeePaid(tokenId, _years, amount);
        IFactory(factory).USDC().safeTransferFrom(msg.sender, address(this), amount);
    }

    /// @inheritdoc ITangibleNFT
    function setBrand(uint256 tokenId, string calldata brand) external override onlyFactory() {
        tokenBrand[tokenId] = brand;
    }

    function withdraw() external onlyAdmin() {
        IERC20 usdc = IFactory(factory).USDC();
        uint256 balance = usdc.balanceOf(address(this));
        usdc.safeTransfer(msg.sender, balance);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(AccessControl, ERC1155, IERC165) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal override {
        // Allow operations if operator is admin
        if (isAdmin(operator)) { return; }
        uint256 length = ids.length;
        for (uint256 i = 0; i < length; i++) {
            // Disable all transfers if storage fee not paid
            if (!isStorageFeePaid(ids[i])) {
                revert("SFNP");
            }
        }
    }
}