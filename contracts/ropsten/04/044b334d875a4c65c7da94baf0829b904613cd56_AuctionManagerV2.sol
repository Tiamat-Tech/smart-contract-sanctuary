// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

/** OpenZeppelin Dependencies */
import '@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol';

/** Local Interfaces */
import './interfaces/IAuctionManagerV2.sol';
import './interfaces/IAuctionV2.sol';
import '../../interfaces/IToken.sol';

import '../../abstracts/Manageable.sol';

/**
Auction MANAGER should mint up to 250bln axion and most
Auction MANAGER should send 50bln to BPD over 5years
Auction MANAGER should send up to 200bln to auction
*/

contract AuctionManagerV2 is
    IAuctionManagerV2,
    Initializable,
    AccessControlUpgradeable,
    Manageable
{
    using SafeMathUpgradeable for uint256;

    /** Events */
    event SentToAuction(uint256 indexed auctionId, uint256 indexed amount);
    event SentToBPD(uint256 indexed amount);

    /** Structs */
    struct Addresses {
        address axion;
        address auction;
        address bpd;
    }
    /** Constants */
    uint256 public constant MAX_MINT = 250000000000;

    /** Variables */
    uint256 public mintedBPD;
    uint256 public mintedAuction;
    Addresses public addresses;

    /** Inits */
    function initialize(
        address _manager,
        address _axion,
        address _auction
    ) public initializer {
        _setupRole(MANAGER_ROLE, _manager);
        _setupRole(DEFAULT_ADMIN_ROLE, _manager);
        addresses.axion = _axion;
        addresses.bpd = address(0);
        addresses.auction = _auction;
        mintedBPD = 0;
        mintedAuction = 0;
    }

    /** Main public manager functions */
    function sendToAuction(uint256 daysInFuture, uint256 amount) external onlyManager {
        _sendToAuction(daysInFuture, amount);
    }

    function sendToAuctions(uint256[] calldata daysInFuture, uint256[] calldata amounts)
        external
        onlyManager
    {
        require(
            daysInFuture.length == amounts.length,
            'AUCTION MANAGER: Array lengths must be equal'
        );

        for (uint256 i = 0; i < daysInFuture.length; i++) {
            _sendToAuction(daysInFuture[i], amounts[i]);
        }
    }

    function _sendToAuction(uint256 daysInFuture, uint256 amount) private {
        mintedAuction = mintedAuction.add(amount);
        require(
            mintedAuction.add(mintedBPD) <= MAX_MINT,
            'AUCTION MANAGER: Max mint has been reached'
        );

        // Mint the tokens send to Auction */
        uint256 actualAmount = amount.mul(1e18);
        IToken(addresses.axion).mint(addresses.auction, actualAmount);
        uint256 auctionId =
            IAuctionV2(addresses.auction).addReservesToAuction(daysInFuture, actualAmount);

        emit SentToAuction(auctionId, amount);
    }
}