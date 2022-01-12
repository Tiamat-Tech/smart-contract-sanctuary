// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.11;

import "./ISLPContract.sol";
import "./HasTaxiOracle.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "solidity-bytes-utils/contracts/BytesLib.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract Taxi is Initializable, HasTaxiOracle {
    using SafeMath for uint256;
    using BytesLib for bytes;

    ISLPContract SLP = ISLPContract(0xa8754b9Fa15fc18BB59458815510E40a12cD2014);

    // The highest possible fee we can set, but allow us to still set low/0 fee.
    // In case our keys are compromised, the worst a malicious attacker
    // could do is raise the fee up to this value
    uint256 public maxPossibleFee = 5;

    // optional.
    // When not set, the claimer can specify any scholar payout address.
    // This makes it easy to for either scholar or any manager to  change payout address without approval from the guild wallet.
    // But this also means a malicious claimer could pass in their own address as the scholar address
    // when making a claim.
    // If all the claimers are not trusted, an allowed address can be explicitly set instead
    mapping(address => address) public scholarPayoutAddress;

    address public guildAddress;
    address public feeAddress;
    uint256 public fee;

    struct Claim {
        address owner;
        uint256 amount;
        uint256 createdAt;
        bytes signature;
        address scholar;
        uint256 scholarAmount;
    }

    struct Whitelist {
        address team;
        address scholar;
    }

    function initialize(
        address _guildAddress,
        address _feeAddress,
        uint256 _fee,
        address _oracle
    ) public initializer {
        feeAddress = _feeAddress;
        fee = _fee;
        oracle = _oracle;
        guildAddress = _guildAddress;
    }

    // set to 0 address to remove whitelist requirement
    function whitelistScholarPayoutAddress(address owner, address scholar)
        public
    {
        require(msg.sender == guildAddress || msg.sender == owner);
        scholarPayoutAddress[owner] = scholar;
    }

    function whitelistScholarPayoutAddressBatch(Whitelist[] calldata batch)
        external
    {
        for (uint256 i = 0; i < batch.length; i++) {
            whitelistScholarPayoutAddress(batch[i].team, batch[i].scholar);
        }
    }

    function makeClaim(
        address owner,
        uint256 amount,
        uint256 createdAt,
        bytes memory signature,
        address scholarPayout,
        uint256 scholarAmount
    ) public onlyTaxi {
        if (scholarPayoutAddress[owner] != address(0)) {
            require(
                scholarPayoutAddress[owner] == scholarPayout,
                "Scholar payout address does not match whitelisted"
            );
        }
        (uint256 prevBalance, ) = SLP.getCheckpoint(owner);
        SLP.checkpoint(owner, amount, createdAt, signature);
        (uint256 newBalance, ) = SLP.getCheckpoint(owner);
        uint256 newSlp = newBalance.sub(prevBalance);
        uint256 feeAmount = newSlp.mul(fee).div(100);
        uint256 guildAmount = newSlp.sub(feeAmount).sub(scholarAmount);
        SLP.transferFrom(owner, guildAddress, guildAmount);
        if (feeAmount > 0) {
            SLP.transferFrom(owner, feeAddress, feeAmount);
        }
        if (scholarAmount > 0) {
            SLP.transferFrom(owner, scholarPayout, scholarAmount);
        }
    }

    // batching lets us do all claims + transfers for a guild in 1 transaction
    function makeClaims(Claim[] memory claims) external onlyTaxi {
        for (uint256 i = 0; i < claims.length; i++) {
            Claim memory claim = claims[i];
            makeClaim(
                claim.owner,
                claim.amount,
                claim.createdAt,
                claim.signature,
                claim.scholar,
                claim.scholarAmount
            );
        }
    }

    function setFee(uint256 _fee) external onlyTaxi {
        require(_fee <= maxPossibleFee, "Fee cannot exceed maxPossibleFee");
        fee = _fee;
    }

    function setFeeAddress(address _feeAddress) external onlyTaxi {
        feeAddress = _feeAddress;
    }
}