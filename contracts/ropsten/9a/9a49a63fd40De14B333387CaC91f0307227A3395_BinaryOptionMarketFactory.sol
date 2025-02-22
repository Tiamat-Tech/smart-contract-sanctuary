pragma solidity ^0.5.16;

// Inheritance
import "synthetix-2.43.1/contracts/MinimalProxyFactory.sol";
import "synthetix-2.43.1/contracts/Owned.sol";

// Internal references
import "./BinaryOptionMarket.sol";
import "synthetix-2.43.1/contracts/interfaces/IAddressResolver.sol";

contract BinaryOptionMarketFactory is MinimalProxyFactory, Owned {
    /* ========== STATE VARIABLES ========== */
    address public binaryOptionMarketManager;
    address public binaryOptionMarketMastercopy;
    address public binaryOptionMastercopy;

    /* ========== CONSTRUCTOR ========== */

    constructor(address _owner) public MinimalProxyFactory() Owned(_owner) {}

    /* ========== MUTATIVE FUNCTIONS ========== */

    function createMarket(
        address creator,
        IAddressResolver _resolver,
        bytes32 oracleKey,
        uint strikePrice,
        uint[2] calldata times, // [maturity, expiry]
        uint initialMint,
        uint[2] calldata fees // [poolFee, creatorFee]
    ) external returns (BinaryOptionMarket) {
        require(binaryOptionMarketManager == msg.sender, "Only permitted by the manager.");

        BinaryOptionMarket bom =
            BinaryOptionMarket(
                _cloneAsMinimalProxy(binaryOptionMarketMastercopy, "Could not create a Binary Option Market")
            );
        bom.initialize(
            binaryOptionMarketManager,
            binaryOptionMastercopy,
            _resolver,
            creator,
            oracleKey,
            strikePrice,
            times,
            initialMint,
            fees
        );
        return bom;
    }

    /* ========== SETTERS ========== */
    function setBinaryOptionMarketManager(address _binaryOptionMarketManager) public onlyOwner {
        binaryOptionMarketManager = _binaryOptionMarketManager;
    }

    function setBinaryOptionMarketMastercopy(address _binaryOptionMarketMastercopy) public onlyOwner {
        binaryOptionMarketMastercopy = _binaryOptionMarketMastercopy;
    }

    function setBinaryOptionMastercopy(address _binaryOptionMastercopy) public onlyOwner {
        binaryOptionMastercopy = _binaryOptionMastercopy;
    }
}