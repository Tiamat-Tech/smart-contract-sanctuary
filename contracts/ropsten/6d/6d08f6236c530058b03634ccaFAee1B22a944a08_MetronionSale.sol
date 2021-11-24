//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { Whitelist } from "./utils/Whitelist.sol";
import { TokenWithdrawable } from "./utils/TokenWithdrawable.sol";
import { IMetronionSale } from "./interface/IMetronionSale.sol";
import { IMetronionNFT } from "./interface/IMetronionNFT.sol";

contract MetronionSale is IMetronionSale, Whitelist, TokenWithdrawable {
    using Address for address;

    uint64 public constant CAP_OWNER_INITIAL_MINT = 500;
    uint64 public constant CAP_PER_PRIVATE_ADDRESS = 1;
    uint64 public constant CAP_PER_ADDRESS = 5;
    uint256 public constant SALE_PRICE = 1 * 10**17; // 0.1 BNB

    IMetronionNFT public immutable override nftContract;
    mapping(uint256 => SaleConfig) internal _saleConfigs; // mapping from version id to sale config
    mapping(uint256 => SaleRecord) internal _saleRecords; // mapping from version id to sale record
    mapping(uint256 => mapping(address => UserRecord)) internal _userRecords; // mapping from version id to map of user record

    event ReceiveETH(address from, uint256 amount);
    event PrivateBought(address indexed buyer, uint256 versionId, uint256 totalWeiPaid);
    event PublicBought(address indexed buyer, uint256 versionId, uint256 totalWeiPaid);
    event OwnerBought(address indexed buyer, uint256 versionId, uint256 totalWeiPaid);
    event WithdrawSaleFunds(address indexed recipient, uint256 amount);

    constructor(
        IMetronionNFT _nftContract,
        uint256 _versionId,
        uint256 _maxWhitelistSize,
        uint64 _privateTime,
        uint64 _publicTime,
        uint64 _endTime
    ) Whitelist(_versionId, _maxWhitelistSize) {
        nftContract = _nftContract;
        _saleConfigs[_versionId] = SaleConfig({
            privateTime: _privateTime,
            publicTime: _publicTime,
            endTime: _endTime
        });
    }

    /**
     * @dev withdraw BNB from sale fund
     * Only owner can call
     */
    function withdrawSaleFunds(address payable recipient, uint256 amount) external onlyOwner {
        (bool success, ) = recipient.call{ value: amount }("");
        require(success, "MetronionSale: withdraw funds failed");
        emit WithdrawSaleFunds(recipient, amount);
    }

    /**
     * @dev Buy an amount of Metronions
     * Maximum amount for private and public sale will be different
     * @param versionId Metronion version, starting at 0
     * @param amount amount of Metronions
     */
    function buy(uint256 versionId, uint64 amount) external payable override {
        address buyer = msg.sender;
        // only EOA or the owner can buy, disallow contracts to buy
        require(!buyer.isContract() || buyer == owner(), "MetronionSale: only EOA or owner");

        _validateAndUpdateBuy(versionId, buyer, amount);

        nftContract.mintMetronion(versionId, amount, buyer);
    }

    /**
     * @dev validate data if it's valid to buy
     * Cannot buy more than max supply
     * If the buyer is the owner, then in the sale period buyer can buy up to CAP_OWNER_INITIAL_MINT with price = 0
     * After sale period owner can free to buy with price = 0
     * If the buy time is in private sale time, only whitelisted user can buy up to CAP_PER_PRIVATED_ADDRESS with SALE_PRICE per Metronion
     * If the buy time is in public sale time, each buyer can buy up to CAP_PER_ADDRESS with SALE_PRICE per Metronion
     * @param versionId version id
     * @param buyer buyer address
     * @param amount amount of Metronions
     */
    function _validateAndUpdateBuy(
        uint256 versionId,
        address buyer,
        uint64 amount
    ) internal {
        IMetronionNFT.Version memory versionConfig = nftContract.versionById(versionId);
        // buy amount cannot exceed max supply
        require(
            _saleRecords[versionId].totalSold + amount <= versionConfig.maxSupply,
            "MetronionSale: exceed buy amount"
        );
        SaleConfig memory saleConfig = _saleConfigs[versionId];
        uint256 totalPaid = msg.value;
        uint256 timestamp = block.timestamp;

        if (msg.sender == owner()) {
            // owner can buy up to CAP_OWNER_INITIAL_MINT in sale time
            if (timestamp < saleConfig.endTime) {
                require(_saleRecords[versionId].ownerBought + amount <= CAP_OWNER_INITIAL_MINT, "MetronionSale: exceed owner cap");
            }
            _saleRecords[versionId].ownerBought += amount;
            _saleRecords[versionId].totalSold += amount;
            emit OwnerBought(buyer, versionId, totalPaid);
            return;
        }

        UserRecord memory userRecord = getUserRecord(versionId, buyer);
        require(timestamp >= saleConfig.privateTime, "MetronionSale: not started");
        require(timestamp <= saleConfig.endTime, "MetronionSale: sale ended");

        
        if (timestamp >= saleConfig.privateTime && timestamp < saleConfig.publicTime) {
            // only whitelisted can buy at this period
            require(isWhitelistedAddress(versionId, buyer), "MetronionSale: not whitelisted buyer");
            require(totalPaid == amount * SALE_PRICE, "MetronionSale: invalid paid value");
            require(userRecord.privateBought + amount <= CAP_PER_PRIVATE_ADDRESS, "MetronionSale: exceed private cap");
            _userRecords[versionId][buyer].privateBought += amount;
            _saleRecords[versionId].totalSold += amount;
            _saleRecords[versionId].privateSold += amount;
            emit PrivateBought(buyer, versionId, totalPaid);
            return;
        }

        if (timestamp >= saleConfig.publicTime && timestamp < saleConfig.endTime) {
            // public sale
            require(totalPaid == amount * SALE_PRICE, "MetronionSale: invalid paid value");
            require(userRecord.publicBought + amount <= CAP_PER_ADDRESS, "MetronionSale: exceed public cap");
            _userRecords[versionId][buyer].publicBought += amount;
            _saleRecords[versionId].totalSold += amount;
            _saleRecords[versionId].publicSold += amount;
            emit PublicBought(buyer, versionId, totalPaid);
        }
    }

    /**
     * @dev Return sale config for specific version
     * @param versionId Metronion version, starting at 0
     */
    function getSaleConfig(uint256 versionId) external view override returns (SaleConfig memory config) {
        config = _saleConfigs[versionId];
    }

    /**
     * @dev Return sale record for specific version
     * @param versionId Metronion version, starting at 0
     */
    function getSaleRecord(uint256 versionId) public view returns (SaleRecord memory saleRecord) {
        return _saleRecords[versionId];
    }

    /**
     * @dev get user record for buy amount in private and public sale for specific version
     * @param versionId Metronion version, starting at 0
     * @param account user address
     */
    function getUserRecord(uint256 versionId, address account) public view returns (UserRecord memory userRecord) {
        return _userRecords[versionId][account];
    }

    // callback function
    receive() external payable {
      emit ReceiveETH(msg.sender, msg.value);
    }
}