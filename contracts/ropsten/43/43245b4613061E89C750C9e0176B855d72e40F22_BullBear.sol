// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/Address.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";


contract BullBear {
    using Address for address;

    enum BetDirection {Unknown, Bear, Chop, Bull}
    enum BetDuration {None, OneMinute, FiveMinutes, FifteenMinutes, OneHour, OneDay, OneWeek, OneQuarter}

    struct Bet {
        address oracle;
        BetDuration duration;
        uint startsAt;
        uint total;
        uint remaining;
        mapping(BetDirection => uint) totals;
        mapping(BetDirection => mapping(address => uint)) balances;
        BetDirection outcome;
        address resolver;
    }

    uint public constant BETS_PER_BETTOR = 10;
    uint public constant BETS_PER_INSTRUMENT = 2;

    address public owner;
    address public feeRecipient;
    uint public feeBasispoints;
    string public version;
    mapping(address => uint) public balances;
    mapping(bytes32 => Bet) public bets; // betId => Bet
    mapping(address => bytes32[BETS_PER_BETTOR]) public bettorBets; // account => betIds
    mapping(address => mapping(bytes32 => bool)) public bettorBetsIsOccupied; // account => betId => bool
    mapping(address => mapping(BetDuration => uint[BETS_PER_INSTRUMENT])) public instrumentBets; // oracle => duration => startsAt[]
    mapping(BetDuration => uint) public durations;

    constructor(address _owner, address _feeRecipient, uint _feeBasispoints, string memory _version) {
        owner = _owner;
        feeRecipient = _feeRecipient;
        version = _version;
        feeBasispoints = _feeBasispoints;
        durations[BetDuration.OneMinute] = 1 * 60;
        durations[BetDuration.FiveMinutes] = 5 * 60;
        durations[BetDuration.FifteenMinutes] = 15 * 60;
        durations[BetDuration.OneHour] = 1 * 60 * 60;
        durations[BetDuration.OneDay] = 24 * 60 * 60;
        durations[BetDuration.OneWeek] = 7 * 24 * 60 * 60;
        durations[BetDuration.OneQuarter] = 91 * 24 * 60 * 60;
    }

    receive() external payable {
        balances[msg.sender] += msg.value;
    }

    function getBetId(address oracle, BetDuration duration, uint startsAt) public pure returns (bytes32) {
        return keccak256(abi.encode(oracle, duration, startsAt));
    }

    function resolveThenPlaceBets(
        bytes32[] memory resolveBetIds, uint80[] memory lockedRoundIdsToResolve, uint80[] memory resolvedRoundIdsToResolve,
        address[] memory oraclesToBet, BetDuration[] memory durationsToBet, BetDirection[] memory directionsToBet, uint[] memory sizesToBet
    ) external payable {
        balances[msg.sender] += msg.value;
        resolveBets(resolveBetIds, lockedRoundIdsToResolve, resolvedRoundIdsToResolve);
        placeBets(oraclesToBet, durationsToBet, directionsToBet, sizesToBet);
    }

    function placeBets(
        address[] memory oraclesToBet, BetDuration[] memory durationsToBet, BetDirection[] memory directionsToBet, uint[] memory sizesToBet
    ) private {
        require(
            oraclesToBet.length <= BETS_PER_BETTOR &&
            oraclesToBet.length == durationsToBet.length &&
            oraclesToBet.length == directionsToBet.length &&
            oraclesToBet.length == sizesToBet.length,
            "all to-bet parameter arrays must be of same length"
        );
        for (uint i = 0; i < oraclesToBet.length; i++) _placeBet(oraclesToBet[i], durationsToBet[i], directionsToBet[i], sizesToBet[i]);
    }

    function placeBet(address oracle, BetDuration duration, BetDirection direction, uint size) external payable {
        balances[msg.sender] += msg.value;
        _placeBet(oracle, duration, direction, size);
    }

    function _placeBet(address oracle, BetDuration duration, BetDirection direction, uint size) private {
        require(duration != BetDuration.None, "Invalid bet duration");
        require(direction != BetDirection.Unknown, "Invalid bet direction");
        require(size > 0, "Size must be greater than zero");

        claimResolvedBets();
        require(balances[msg.sender] >= size, "Bet size exceeds available balance");

        uint startsAt = block.timestamp - block.timestamp % durations[duration] + durations[duration];
        bytes32 id = getBetId(oracle, duration, startsAt);
        if (!bettorBetsIsOccupied[msg.sender][id]) {
            uint bettorSlot = getFirstAvailableBetSlotForBettor();
            require(bettorSlot < BETS_PER_BETTOR, "Cannot place a bet; exceeded max allowed unresolved bets per bettor");
            bettorBets[msg.sender][bettorSlot] = id;
            bettorBetsIsOccupied[msg.sender][id] = true;
        }
        uint instrumentSlot = getFirstAvailableBetSlotForInstrument(oracle, duration, startsAt);
        require(instrumentSlot < BETS_PER_INSTRUMENT, "Cannot place a bet; exceeded max allowed bets per instrument");
        balances[msg.sender] -= size;
        Bet storage bet = bets[id];
        if (bet.oracle == address(0x0)) {
            bet.oracle = oracle;
            bet.duration = duration;
            bet.startsAt = startsAt;
        }

        bet.total += size;
        bet.totals[direction] += size;
        bet.balances[direction][msg.sender] += size;
        instrumentBets[oracle][duration][instrumentSlot] = startsAt;
    emit BetPlaced(msg.sender, oracle, symbol(oracle), duration, startsAt, direction, size);
    }
    event BetPlaced(address account, address oracle, string symbol, BetDuration duration, uint startsAt, BetDirection kind, uint size);

    function getFirstAvailableBetSlotForBettor() private view returns (uint) {
        for (uint i = 0; i < BETS_PER_BETTOR; i++) if (bettorBets[msg.sender][i] == 0) return i;
        return BETS_PER_BETTOR;
    }

    function symbol(address oracle) private view returns (string memory) {
        require(oracle.isContract(), "Oracle must be a contract address");
        try AggregatorV3Interface(oracle).description() returns (string memory description) {
            return description;
        } catch (bytes memory) {
            return "Oracle must be an AggregatorV3Interface contract";
        }
    }

    function canPlaceBet(address account) external view returns (bool) {
        return countUnresolvedBetsForBettor(account) < BETS_PER_BETTOR || countResolvableNowBetsForBettor(account) > 0 ;
    }

    function countUnresolvedBetsForBettor(address account) public view returns (uint result) {
        for (uint i = 0; i < BETS_PER_BETTOR; i++) {
            bytes32 id = bettorBets[account][i];
            if (id != 0 && !_isResolvedBet(id)) result += 1;
        }
    }

    function countUnresolvedBetsForInstrument(address oracle, BetDuration duration) external view returns (uint result) {
        for (uint i = 0; i < BETS_PER_INSTRUMENT; i++) {
            bytes32 id = getBetId(oracle, duration, instrumentBets[oracle][duration][i]);
            if (isUnresolvedBet(id)) result += 1;
        }
    }

    function getFirstAvailableBetSlotForInstrument(address oracle, BetDuration duration, uint startsAt) private view returns (uint) {
        for (uint i = 0; i < BETS_PER_INSTRUMENT; i++) {
            uint start = instrumentBets[oracle][duration][i];
            if (start == 0 || start == startsAt) return i;
        }
        return BETS_PER_INSTRUMENT;
    }

    function getStartAtOfUnresolvedBetsForInstrument(address oracle, BetDuration duration) external view returns (uint[BETS_PER_INSTRUMENT] memory result) {
        for (uint i = 0; i < BETS_PER_INSTRUMENT; i++) {
            uint start = instrumentBets[oracle][duration][i];
            bytes32 id = getBetId(oracle, duration, start);
            if (isUnresolvedBet(id)) result[i] = start;
        }
    }

    function countResolvableNowBetsForBettor(address account) private view returns (uint result) {
        for (uint i = 0; i < BETS_PER_BETTOR; i++) {
            bytes32 id = bettorBets[account][i];
            if (isResolvableNowBet(id)) result += 1;
        }
    }

    function resolveBets(
        bytes32[] memory resolveBetIds, uint80[] memory lockedRoundIdsToResolve, uint80[] memory resolvedRoundIdsToResolve
    ) private {
        require(
            resolveBetIds.length <= BETS_PER_BETTOR &&
            resolveBetIds.length == lockedRoundIdsToResolve.length &&
            resolveBetIds.length == resolvedRoundIdsToResolve.length,
            "all to-resolve parameter arrays must be of same length"
        );
        for (uint i = 0; i < resolveBetIds.length; i++) if (isResolvableNowBet(resolveBetIds[i])) resolveBet(resolveBetIds[i], lockedRoundIdsToResolve[i], resolvedRoundIdsToResolve[i]);
    }

    function resolveBet(bytes32 betId, uint80 lockedRoundId, uint80 resolvedRoundId) private {
        Bet storage bet = bets[betId];
        uint endsAt = bet.startsAt + durations[bet.duration];
        require(bet.total > 0, "Bet does not exist");
        require(endsAt < block.timestamp, "Too early to resolve bet");

        // resolve outcome
        AggregatorV3Interface priceFeed = AggregatorV3Interface(bet.oracle);
        (,,,uint latestUpdatedAt,) = priceFeed.latestRoundData();
        uint lockedPrice = getValidRoundPrice(priceFeed, bet.startsAt, lockedRoundId, latestUpdatedAt);
        uint resolvedPrice = getValidRoundPrice(priceFeed, endsAt, resolvedRoundId, latestUpdatedAt);
        bet.outcome = (resolvedPrice == lockedPrice) ?
            BetDirection.Chop :
            (resolvedPrice > lockedPrice) ?
                BetDirection.Bull :
                BetDirection.Bear;
        bet.resolver = msg.sender;
        uint fee = (bet.total * feeBasispoints) / 10000;
        emit BetResolved(bet.resolver, bet.oracle, bet.duration, bet.startsAt, bet.total, bet.totals[BetDirection.Bear], bet.totals[BetDirection.Chop], bet.totals[BetDirection.Bull], bet.outcome, fee, lockedPrice, resolvedPrice);

        // compensate the resolver
        bet.total -= fee;
        bet.remaining = bet.total;
        balances[feeRecipient] += fee;

        tidyUpBetQueuePerInstrument(bet.oracle, bet.duration);

        // if there are no winners, the "house" wins
        if (bet.totals[bet.outcome] == 0) balances[feeRecipient] += bet.total;
    }
    event BetResolved(address resolver, address oracle, BetDuration duration, uint startsAt, uint total, uint Bear, uint Chop, uint Bull, BetDirection outcome, uint fee, uint lockedPrice, uint resolvedPrice);

    function tidyUpBetQueuePerInstrument(address oracle, BetDuration duration) private {
        uint available = 0;
        for (uint i = 0; i < BETS_PER_INSTRUMENT; i++) {
            uint startsAt = instrumentBets[oracle][duration][i];
            if (isUnresolvedBet(getBetId(oracle, duration, startsAt))) {
                if (i > available) {
                    instrumentBets[oracle][duration][available] = startsAt;
                    instrumentBets[oracle][duration][i] = 0;
                }
                available += 1;
            } else instrumentBets[oracle][duration][i] = 0;
        }
    }

    function getValidRoundPrice(AggregatorV3Interface priceFeed, uint boundaryTimestamp, uint80 roundId, uint latestUpdatedAt) private view returns (uint) {
        ( ,int price, , uint thisRoundUpdatedAt, ) = priceFeed.getRoundData(roundId);
        require(thisRoundUpdatedAt <= boundaryTimestamp, "Round timestamp beyond boundary");

        if (thisRoundUpdatedAt == latestUpdatedAt) /* no price change */ return uint(price);

        bool isBoundaryBeforeNextRound = latestUpdatedAt == thisRoundUpdatedAt;
        if (!isBoundaryBeforeNextRound) {
            ( , , , uint nextRoundUpdatedAt, ) = priceFeed.getRoundData(roundId + 1);
            isBoundaryBeforeNextRound = nextRoundUpdatedAt > boundaryTimestamp;
        }
        require(isBoundaryBeforeNextRound, "Stale round id");
        return uint(price);
    }

    function isUnresolvedBet(bytes32 id) public view returns (bool) {
        return bets[id].startsAt != 0 && !_isResolvedBet(id);
    }

    function isResolvableNowBet(bytes32 id) public view returns (bool) {
        return isUnresolvedBet(id) && /* is not open */ bets[id].startsAt + durations[bets[id].duration] <= block.timestamp;
    }

    function isResolvedBet(address oracle, BetDuration duration, uint startsAt) external view returns (bool) {
        return _isResolvedBet(getBetId(oracle, duration, startsAt));
    }

    function _isResolvedBet(bytes32 id) private view returns (bool) {
        return bets[id].outcome != BetDirection.Unknown;
    }

    function claimResolvedBets() private {
        for (uint i = 0; i < BETS_PER_BETTOR; i++) {
            bytes32 id = bettorBets[msg.sender][i];
            if (!_isResolvedBet(id) || id==0) continue;
            claimBet(id);
            bettorBets[msg.sender][i] = 0;
            delete (bettorBetsIsOccupied[msg.sender][id]);
        }
    }

    function claimBet(bytes32 id) private {
        require(_isResolvedBet(id), "Cannot claim unresolved bet");
        Bet storage bet = bets[id];
        uint size = bet.balances[bet.outcome][msg.sender];
        if (size > 0) {
            delete bet.balances[bet.outcome][msg.sender];
            uint winning = size * bet.total / bet.totals[bet.outcome];
            bet.remaining -= winning;
            balances[msg.sender] += winning;
            emit BetClaimed(msg.sender, bet.oracle, bet.duration, bet.startsAt, bet.outcome, winning);
        }
        reclaimBetStorage(id);
    }
    event BetClaimed(address account, address oracle, BetDuration duration, uint startsAt, BetDirection outcome, uint winning);

    function reclaimBetStorage(bytes32 id) private {
        for (uint i = uint(BetDirection.Bear); i <= uint(BetDirection.Bull); ++i) delete bets[id].balances[BetDirection(i)][msg.sender];
        if (bets[id].remaining == 0) {
            delete bets[id];
            // delete does not cascade to mappings
            for (uint i = uint(BetDirection.Bear); i <= uint(BetDirection.Bull); ++i) delete bets[id].totals[BetDirection(i)];
        }
    }

    function getBetTotals(address oracle, BetDuration duration, uint startsAt) external view returns (uint total, uint Bear, uint Chop, uint Bull) {
        Bet storage bet = bets[getBetId(oracle, duration, startsAt)];
        total = bet.total;
        Bear = bet.totals[BetDirection.Bear];
        Chop = bet.totals[BetDirection.Chop];
        Bull = bet.totals[BetDirection.Bull];
    }

    function getBettorBetTotals(address oracle, BetDuration duration, uint startsAt, address account) external view returns (uint Bear, uint Chop, uint Bull) {
        Bet storage bet = bets[getBetId(oracle, duration, startsAt)];
        Bear = bet.balances[BetDirection.Bear][account];
        Chop = bet.balances[BetDirection.Chop][account];
        Bull = bet.balances[BetDirection.Bull][account];
    }

    function getAvailableBalance(address account) external view returns (uint) {
        uint result = balances[account];
        for (uint i = 0; i < BETS_PER_BETTOR; i++) {
            bytes32 id = bettorBets[account][i];
            if (!_isResolvedBet(id) || id == 0) continue;
            Bet storage bet = bets[id];
            uint size = bet.balances[bet.outcome][account];
            uint winning = size * bet.total / bet.totals[bet.outcome];
            result += winning;
        }
        return result;
    }

    function withdraw(uint amount) external {
        claimResolvedBets();
        require(balances[msg.sender] >= amount, 'Insufficient balance');
        balances[msg.sender] -= amount;
        payable(msg.sender).transfer(amount);
    }

    modifier onlyOwner { require(msg.sender == owner, "invalid sender; must be owner"); _; }

    function changeOwner(address _owner) external onlyOwner {
        emit OwnerChanged(owner, _owner);
        owner = _owner;
    }
    event OwnerChanged(address from, address to);

    function changeFeeRecipient(address _feeRecipient) external onlyOwner {
        emit FeeRecipientChanged(feeRecipient, _feeRecipient);
        feeRecipient = _feeRecipient;
    }
    event FeeRecipientChanged(address from, address to);

}