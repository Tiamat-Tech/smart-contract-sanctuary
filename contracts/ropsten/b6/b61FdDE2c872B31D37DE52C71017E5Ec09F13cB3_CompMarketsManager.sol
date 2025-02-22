// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "prb-math/contracts/PRBMathUD60x18.sol";

import {ICErc20, IComptroller} from "./interfaces/ICompound.sol";
import "./interfaces/ICompPositionsManager.sol";
import "./interfaces/ICompMarketsManager.sol";

/**
 *  @title CompPositionsManager
 *  @dev Smart contracts interacting with Compound to enable real P2P supply with cERC20 tokens as supply/borrow assets.
 */
contract CompMarketsManager is Ownable {
    using PRBMathUD60x18 for uint256;
    using Math for uint256;

    /* Storage */

    mapping(address => bool) public isListed; // Whether or not this market is listed.
    mapping(address => bool) public isCreated; // Whether or not this market is created.
    mapping(address => uint256) public p2pBPY; // Block Percentage Yield ("midrate").
    mapping(address => uint256) public mUnitExchangeRate; // current exchange rate from mUnit to underlying.
    mapping(address => uint256) public lastUpdateBlockNumber; // Last time mUnitExchangeRate was updated.
    mapping(address => uint256) public thresholds; // Thresholds below the ones suppliers and borrowers cannot enter markets.

    ICompPositionsManager public compPositionsManager;

    /* Events */

    /** @dev Emitted when a new market is created.
     *  @param _marketAddress The address of the market that has been created.
     */
    event MarketCreated(address _marketAddress);

    /** @dev Emitted when the p2pBPY of a market is updated.
     *  @param _marketAddress The address of the market to update.
     *  @param _newValue The new value of the p2pBPY.
     */
    event BPYUpdated(address _marketAddress, uint256 _newValue);

    /** @dev Emitted when the mUnitExchangeRate of a market is updated.
     *  @param _marketAddress The address of the market to update.
     *  @param _newValue The new value of the mUnitExchangeRate.
     */
    event MUnitExchangeRateUpdated(address _marketAddress, uint256 _newValue);

    /** @dev Emitted when a threshold of a market is updated.
     *  @param _marketAddress The address of the market to update.
     *  @param _newValue The new value of the threshold.
     */
    event ThresholdUpdated(address _marketAddress, uint256 _newValue);

    /* Modifiers */

    /** @dev Prevents to update a market not created yet.
     */
    modifier isMarketCreated(address _marketAddress) {
        require(isCreated[_marketAddress], "market not entered");
        _;
    }

    /* External */

    /** @dev Sets the `compPositionsManager` to interact with Compound.
     *  @param _compPositionsManager The address of compound module.
     */
    function setCompPositionsManager(ICompPositionsManager _compPositionsManager)
        external
        onlyOwner
    {
        compPositionsManager = _compPositionsManager;
    }

    /** @dev Sets the comptroller address.
     *  @param _proxyComptrollerAddress The address of Compound's comptroller.
     */
    function setComptroller(address _proxyComptrollerAddress) external onlyOwner {
        compPositionsManager.setComptroller(_proxyComptrollerAddress);
    }

    /** @dev Creates new market to borrow/supply.
     *  @param _marketAddresses The addresses of the markets to add (cToken).
     */
    function createMarkets(address[] calldata _marketAddresses) external onlyOwner {
        uint256[] memory results = compPositionsManager.createMarkets(_marketAddresses);
        for (uint256 i; i < _marketAddresses.length; i++) {
            require(results[i] == 0, "createMarkets: enter market failed on Compound");
            address _marketAddress = _marketAddresses[i];
            require(!isCreated[_marketAddress], "createMarkets: market already entered");
            isCreated[_marketAddress] = true;
            mUnitExchangeRate[_marketAddress] = 1e18;
            lastUpdateBlockNumber[_marketAddress] = block.number;
            thresholds[_marketAddress] = 1e18;
            updateBPY(_marketAddress);
            emit MarketCreated(_marketAddress);
        }
    }

    /** @dev Sets a market as listed.
     *  @param _marketAddress The address of the market to list.
     */
    function listMarket(address _marketAddress) external onlyOwner isMarketCreated(_marketAddress) {
        isListed[_marketAddress] = true;
    }

    /** @dev Sets a market as unlisted.
     *  @param _marketAddress The address of the market to unlist.
     */
    function unlistMarket(address _marketAddress)
        external
        onlyOwner
        isMarketCreated(_marketAddress)
    {
        isListed[_marketAddress] = false;
    }

    /** @dev Updates thresholds below the ones suppliers and borrowers cannot enter markets.
     *  @param _marketAddress The address of the market to change the threshold.
     *  @param _newThreshold The new threshold to set.
     */
    function updateThreshold(address _marketAddress, uint256 _newThreshold) external onlyOwner {
        require(_newThreshold > 0, "updateThreshold: new THRESHOLD must be strictly positive.");
        thresholds[_marketAddress] = _newThreshold;
        emit ThresholdUpdated(_marketAddress, _newThreshold);
    }

    /* Public */

    /** @dev Updates the Block Percentage Yield (`p2pBPY`) and calculate the current exchange rate (`mUnitExchangeRate`).
     *  @param _marketAddress The address of the market we want to update.
     */
    function updateBPY(address _marketAddress) public isMarketCreated(_marketAddress) {
        ICErc20 cErc20Token = ICErc20(_marketAddress);

        // Update p2pBPY
        uint256 supplyBPY = cErc20Token.supplyRatePerBlock();
        uint256 borrowBPY = cErc20Token.borrowRatePerBlock();
        p2pBPY[_marketAddress] = Math.average(supplyBPY, borrowBPY);

        emit BPYUpdated(_marketAddress, p2pBPY[_marketAddress]);

        // Update mUnitExhangeRate
        updateMUnitExchangeRate(_marketAddress);
    }

    /** @dev Updates the current exchange rate, taking into account the block percentage yield (p2pBPY) since the last time it has been updated.
     *  @param _marketAddress The address of the market we want to update.
     *  @return currentExchangeRate to convert from mUnit to underlying or from underlying to mUnit.
     */
    function updateMUnitExchangeRate(address _marketAddress)
        public
        isMarketCreated(_marketAddress)
        returns (uint256)
    {
        uint256 currentBlock = block.number;

        if (lastUpdateBlockNumber[_marketAddress] == currentBlock) {
            return mUnitExchangeRate[_marketAddress];
        } else {
            uint256 numberOfBlocksSinceLastUpdate = currentBlock -
                lastUpdateBlockNumber[_marketAddress];
            // Update lastUpdateBlockNumber
            lastUpdateBlockNumber[_marketAddress] = currentBlock;

            uint256 newMUnitExchangeRate = mUnitExchangeRate[_marketAddress].mul(
                (1e18 + p2pBPY[_marketAddress]).pow(
                    PRBMathUD60x18.fromUint(numberOfBlocksSinceLastUpdate)
                )
            );

            // Update currentExchangeRate
            mUnitExchangeRate[_marketAddress] = newMUnitExchangeRate;
            emit MUnitExchangeRateUpdated(_marketAddress, newMUnitExchangeRate);
            return newMUnitExchangeRate;
        }
    }
}