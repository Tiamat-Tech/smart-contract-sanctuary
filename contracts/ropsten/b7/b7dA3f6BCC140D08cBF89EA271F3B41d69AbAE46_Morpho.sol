// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "prb-math/contracts/PRBMathUD60x18.sol";

import {ICErc20, IComptroller} from "./interfaces/ICompound.sol";
import "./interfaces/ICompoundModule.sol";
import "./interfaces/IMorpho.sol";

/**
 *  @title CompoundModule
 *  @dev Smart contracts interacting with Compound to enable real P2P lending with cERC20 tokens as lending/borrowing assets.
 */
contract Morpho is Ownable {
    using PRBMathUD60x18 for uint256;
    using Math for uint256;

    enum Threshold {
        Underlying,
        CToken,
        MUnit,
        CdUnit
    }

    /* Storage */

    mapping(address => bool) public isListed; // Whether or not this market is listed.
    mapping(address => uint256) public BPY; // Block Percentage Yield ("midrate").
    mapping(address => uint256) public closeFactor; // Multiplier used to calculate the maximum repayAmount when liquidating a borrow.
    mapping(address => uint256) public collateralFactor; // Multiplier representing the most one can borrow against their collateral in this market (0.9 => borrow 90% of collateral value max). Between 0 and 1.
    mapping(address => uint256) public mUnitExchangeRate; // current exchange rate from mUnit to underlying.
    mapping(address => uint256) public liquidationIncentive; // Incentive for liquidators in percentage (110% at the beginning).
    mapping(address => uint256) public lastUpdateBlockNumber; // Last time mUnitExchangeRate was updated.
    mapping(address => mapping(Threshold => uint256)) public thresholds; // Thresholds below the ones we remove lenders and borrowers from the lists. 0 -> Underlying, 1 -> cToken, 2 -> mUnit

    IComptroller public comptroller;
    ICompoundModule public compoundModule;

    /* Events */

    /** @dev Emitted when a new market is created.
     *  @param _marketAddress The address of the market that has been created.
     */
    event CreateMarket(address _marketAddress);

    /** @dev Emitted when the BPY of a market is updated.
     *  @param _marketAddress The address of the market to update.
     *  @param _newValue The new value of the BPY.
     */
    event UpdateBPY(address _marketAddress, uint256 _newValue);

    /** @dev Emitted when the collateral factor of a market is updated.
     *  @param _marketAddress The address of the market to update.
     *  @param _newValue The new value of the collateral factor.
     */
    event UpdateCollateralFactor(address _marketAddress, uint256 _newValue);

    /** @dev Emitted when the mUnitExchangeRate of a market is updated.
     *  @param _marketAddress The address of the market to update.
     *  @param _newValue The new value of the mUnitExchangeRate.
     */
    event UpdateMUnitExchangeRate(address _marketAddress, uint256 _newValue);

    /** @dev Emitted when a threshold of a market is updated.
     *  @param _marketAddress The address of the market to update.
     *  @param _thresholdType The threshold type to update.
     *  @param _newValue The new value of the threshold.
     */
    event UpdateThreshold(address _marketAddress, Threshold _thresholdType, uint256 _newValue);

    /** @dev Emitted when the close factor of a market is changed.
     *  @param _marketAddress The address of the market to update.
     *  @param _newValue The new value of the close factor.
     */
    event NewCloseFactor(address _marketAddress, uint256 _newValue);

    /** @dev Emitted when the liquidation incentive of a market is changed.
     *  @param _marketAddress The address of the market to update.
     *  @param _newValue The new value of the liquidation incentive.
     */
    event NewLiquidationIncentive(address _marketAddress, uint256 _newValue);

    /* Constructor */

    constructor(address _proxyComptrollerAddress) {
        comptroller = IComptroller(_proxyComptrollerAddress);
    }

    /* External */

    /** @dev Sets the compound module to interact with Compound.
     *  @param _compoundModule The address of compound module.
     */
    function setCompoundModule(ICompoundModule _compoundModule) external onlyOwner {
        compoundModule = _compoundModule;
    }

    /** @dev Creates new market to borrow/lend.
     *  @param _cTokensAddresses The addresses of the markets to add.
     */
    function createMarkets(address[] calldata _cTokensAddresses) external onlyOwner {
        uint256[] memory results = compoundModule.enterMarkets(_cTokensAddresses);
        for (uint256 i; i < _cTokensAddresses.length; i++) {
            require(results[i] == 0, "Enter market failed on Compound");
            address cTokenAddress = _cTokensAddresses[i];
            closeFactor[cTokenAddress] = 0.5e18;
            liquidationIncentive[cTokenAddress] = 1e18;
            mUnitExchangeRate[cTokenAddress] = 1e18;
            lastUpdateBlockNumber[cTokenAddress] = block.number;
            thresholds[cTokenAddress][Threshold.Underlying] = 1e18;
            thresholds[cTokenAddress][Threshold.CToken] = 1e7;
            thresholds[cTokenAddress][Threshold.MUnit] = 1e18;
            thresholds[cTokenAddress][Threshold.CdUnit] = 1e16;
            updateBPY(cTokenAddress);
            updateCollateralFactor(cTokenAddress);
            emit CreateMarket(cTokenAddress);
        }
    }

    /** @dev Sets a market as listed.
     *  @param _marketAddress The address of the market to list.
     */
    function listMarket(address _marketAddress) external onlyOwner {
        isListed[_marketAddress] = true;
    }

    /** @dev Sets a market as unlisted.
     *  @param _marketAddress The address of the market to unlist.
     */
    function unlistMarket(address _marketAddress) external onlyOwner {
        isListed[_marketAddress] = false;
    }

    /** @dev Updates thresholds below the ones lenders and borrowers are removed from lists.
     *  @param _marketAddress The address of the market to change the threshold.
     *  @param _thresholdType Which threshold must be updated. 0 -> Underlying, 1 -> cToken, 2 -> mUnit
     *  @param _newThreshold The new threshold to set.
     */
    function updateThreshold(
        address _marketAddress,
        Threshold _thresholdType,
        uint256 _newThreshold
    ) external onlyOwner {
        require(_newThreshold > 0, "New THRESHOLD must be strictly positive.");
        thresholds[_marketAddress][_thresholdType] = _newThreshold;
        emit UpdateThreshold(_marketAddress, _thresholdType, _newThreshold);
    }

    /** @dev Sets a new liquidation incentive to a market.
     *  @param _marketAddress The address of the market to modify.
     *  @param _liquidationIncentive The new liquidation incentive to set. 1e18 means no incentive, 1.1e18 means a 10% bonus on the amount seized.
     */
    function setLiquidationIncentive(address _marketAddress, uint256 _liquidationIncentive)
        external
        onlyOwner
    {
        liquidationIncentive[_marketAddress] = _liquidationIncentive;
        emit NewLiquidationIncentive(_marketAddress, _liquidationIncentive);
    }

    /** @dev Sets a new close factor to a market.
     *  @param _marketAddress The address of the market to modify.
     *  @param _closeFactor The new close factor to set.
     */
    function setCloseFactor(address _marketAddress, uint256 _closeFactor) external onlyOwner {
        closeFactor[_marketAddress] = _closeFactor;
        emit NewCloseFactor(_marketAddress, _closeFactor);
    }

    /* Public */

    /** @dev Updates the collateral factor related to cToken.
     *  @param _marketAddress The address of the market we want to update.
     */
    function updateCollateralFactor(address _marketAddress) public {
        (, uint256 collateralFactorMantissa, ) = comptroller.markets(_marketAddress);
        collateralFactor[_marketAddress] = collateralFactorMantissa;
        emit UpdateCollateralFactor(_marketAddress, collateralFactorMantissa);
    }

    /** @dev Updates the Block Percentage Yield (`BPY`) and calculate the current exchange rate (`currentExchangeRate`).
     *  @param _marketAddress The address of the market we want to update.
     */
    function updateBPY(address _marketAddress) public {
        ICErc20 cErc20Token = ICErc20(_marketAddress);

        // Update BPY
        uint256 lendBPY = cErc20Token.supplyRatePerBlock();
        uint256 borrowBPY = cErc20Token.borrowRatePerBlock();
        BPY[_marketAddress] = Math.average(lendBPY, borrowBPY);

        emit UpdateBPY(_marketAddress, BPY[_marketAddress]);

        // Update currentExchangeRate
        updateMUnitExchangeRate(_marketAddress);
    }

    /** @dev Updates the current exchange rate, taking into account the block percentage yield (BPY) since the last time it has been updated.
     *  @param _marketAddress The address of the market we want to update.
     *  @return currentExchangeRate to convert from mUnit to underlying or from underlying to mUnit.
     */
    function updateMUnitExchangeRate(address _marketAddress) public returns (uint256) {
        uint256 currentBlock = block.number;

        if (lastUpdateBlockNumber[_marketAddress] == currentBlock) {
            return mUnitExchangeRate[_marketAddress];
        } else {
            uint256 numberOfBlocksSinceLastUpdate = currentBlock -
                lastUpdateBlockNumber[_marketAddress];

            uint256 newMUnitExchangeRate = mUnitExchangeRate[_marketAddress].mul(
                (1e18 + BPY[_marketAddress]).pow(
                    PRBMathUD60x18.fromUint(numberOfBlocksSinceLastUpdate)
                )
            );

            emit UpdateMUnitExchangeRate(_marketAddress, newMUnitExchangeRate);

            // Update currentExchangeRate
            mUnitExchangeRate[_marketAddress] = newMUnitExchangeRate;

            // Update lastUpdateBlockNumber
            lastUpdateBlockNumber[_marketAddress] = currentBlock;

            return newMUnitExchangeRate;
        }
    }
}