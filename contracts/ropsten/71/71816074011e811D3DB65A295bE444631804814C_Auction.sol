pragma solidity 0.8.4;

import '@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol';

import '@openzeppelin/contracts/token/ERC1155/IERC1155.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import '@openzeppelin/contracts/access/Ownable.sol';

contract Auction is ERC1155Holder, Ownable {
    IERC1155 public erc1155;
    IERC20 public erc20;

    uint256 public constant ONE_TOKEN_IN_WEI = 1e18;
    bytes public constant DEF_DATA = '';

    uint256 public lotsCounter = 0;
    uint256 public betsCounter = 0;

    uint256 public feeNuminator = 145;
    uint256 public feeDenuminator = 1000;

    address public addressToSendFee;

    struct Bet {
        uint256 lotId;
        uint256 bet;
        uint256 time;
        address better;
    }

    struct Lot {
        uint256 lotId;
        uint256 tokenId;
        uint256 amount;
        uint256 minBet;
        uint256 maxBet;
        uint256 currentMaxBetId;
        uint256 step;
        uint256 start;
        uint256 period;
        uint256[] betsIds;
        address owner;
        bool status;
    }

    mapping(uint256 => Lot) public lots;
    mapping(uint256 => Bet) public bets;
    mapping(address => uint256[]) public betsOfAUser;

    event LotCreation(uint256 lotId, uint256 indexed tokenId, address indexed owner);

    event BetCreation(uint256 indexed lotId);

    event Claim(uint256 indexed lotId, uint256 indexed betId);

    constructor(
        address TOKEN1155,
        address TOKEN20,
        address wallet
    ) {
        erc1155 = IERC1155(TOKEN1155);
        erc20 = IERC20(TOKEN20);
        addressToSendFee = wallet;

        transferOwnership(msg.sender);
    }

    function placeALot(
        uint256 tokenId,
        uint256 amount,
        uint256 minBet,
        uint256 maxBet,
        uint256 step,
        uint256 period
    ) external {
        require(erc1155.balanceOf(msg.sender, tokenId) >= amount, "You don't have enough tokens");
        require(amount > 0, 'Amount must be greater than zero');

        erc1155.safeTransferFrom(msg.sender, address(this), tokenId, amount, DEF_DATA);

        _createLot(tokenId, amount, minBet, maxBet, step, period);
    }

    function makeABet(uint256 lotId, uint256 betValue) external {
        require(
            erc20.balanceOf(msg.sender) >= bets[lots[lotId].currentMaxBetId].bet,
            "You don't have enough money to make a lot"
        );
        require(
            block.timestamp - bets[lots[lotId].currentMaxBetId].time > lots[lotId].step,
            'Not enough time has come since the last Bet'
        );
        require(block.timestamp - lots[lotId].start <= lots[lotId].period, 'The Lot has been selled');
        require(bets[lots[lotId].currentMaxBetId].bet < betValue, 'Current higest Bet is higher than yours');
        require(lots[lotId].maxBet >= betValue, 'You are trying to make a Bet higher than max Bet');

        erc20.transferFrom(msg.sender, address(this), betValue);

        if (betValue < lots[lotId].maxBet && lots[lotId].betsIds.length > 1) {
            erc20.transfer(bets[lots[lotId].currentMaxBetId].better, bets[lots[lotId].currentMaxBetId].bet);
        } else if (betValue == lots[lotId].maxBet) {
            erc20.transfer(msg.sender, (lots[lotId].maxBet - _calculateFee(lots[lotId].maxBet)));
            erc20.transfer(addressToSendFee, _calculateFee(lots[lotId].maxBet));
            erc1155.safeTransferFrom(address(this), msg.sender, lots[lotId].tokenId, lots[lotId].amount, DEF_DATA);
        }

        betsCounter += 1;
        lots[lotId].currentMaxBetId = betsCounter;
        lots[lotId].betsIds.push(betsCounter);

        bets[betsCounter] = Bet({lotId: lotId, bet: betValue, time: block.timestamp, better: msg.sender});

        betsOfAUser[msg.sender].push(betsCounter);

        emit BetCreation(lotId);
    }

    function claim(uint256 lotId, uint256 betId) external {
        require(block.timestamp - lots[lotId].start > lots[lotId].period, 'Auction not finished yet');
        require(bets[lots[lotId].currentMaxBetId].bet == bets[betId].bet, "Your Bet isn't last");
        require(bets[betId].better == msg.sender, 'You are not the owner of the Bet');

        if (bets[betId].better == lots[lotId].owner) {
            erc1155.safeTransferFrom(address(this), msg.sender, lots[lotId].tokenId, lots[lotId].amount, DEF_DATA);
        } else {
            //Needs logic update
            erc1155.safeTransferFrom(address(this), msg.sender, lots[lotId].tokenId, lots[lotId].amount, DEF_DATA);
            erc20.transfer(lots[lotId].owner, bets[lots[lotId].currentMaxBetId].bet - _calculateFee(bets[betId].bet));
            erc20.transfer(addressToSendFee, _calculateFee(bets[betId].bet));
        }

        lots[lotId].status = false;

        emit Claim(lotId, betId);
    }

    function _createLot(
        uint256 tokenId,
        uint256 amount,
        uint256 minBet,
        uint256 maxBet,
        uint256 step,
        uint256 period
    ) internal {
        lotsCounter += 1;
        betsCounter += 1;

        uint256[] memory betsIds;

        lots[lotsCounter] = Lot({
            lotId: lotsCounter,
            tokenId: tokenId,
            amount: amount,
            minBet: minBet,
            maxBet: maxBet,
            currentMaxBetId: betsCounter,
            start: block.timestamp,
            step: step,
            period: period,
            betsIds: betsIds,
            owner: msg.sender,
            status: true
        });

        lots[lotsCounter].betsIds.push(betsCounter);

        bets[betsCounter] = Bet({lotId: lotsCounter, bet: minBet, time: block.timestamp, better: msg.sender});

        emit LotCreation(lotsCounter, tokenId, msg.sender);
    }

    function _calculateFee(uint256 bet) internal view returns (uint256 fee) {
        fee = (bet * feeNuminator) / feeDenuminator;

        return fee;
    }

    // function allBetsForALot(uint256 lotId_)
    //     external
    //     view
    //     returns (Bet[] memory bets_, uint256[] memory ids)
    // {
    //     ids = lots[lotId_].betsIds;
    //     bets_ = new Bet[]((lots[lotId_].betsIds).length);

    //     for (uint256 i; i < (lots[lotId_].betsIds).length; i++) {
    //         bets_[i] = bets[i];
    //     }
    // }

    function allBetsForALot(uint256 lotId_)
        external
        view
        returns (
            uint256[] memory bets_,
            uint256[] memory time_,
            address[] memory betters_
        )
    {
        uint256[] memory bets__ = new uint256[](lots[lotId_].betsIds.length);
        uint256[] memory time__ = new uint256[](lots[lotId_].betsIds.length);
        address[] memory betters__ = new address[](lots[lotId_].betsIds.length);

        for (uint256 i = 0; i < lots[lotId_].betsIds.length; i++) {
            bets__[i] = bets[lots[lotId_].betsIds[i]].bet;
            time__[i] = bets[lots[lotId_].betsIds[i]].time;
            betters__[i] = bets[lots[lotId_].betsIds[i]].better;
        }

        return (bets__, time__, betters__);
    }

    function allBetsForABetter(address betterAddress)
        external
        view
        returns (
            uint256[] memory lotsIds_,
            uint256[] memory bets_,
            uint256[] memory time_
        )
    {
        uint256[] memory lotsIds__ = new uint256[](betsOfAUser[betterAddress].length);
        uint256[] memory bets__ = new uint256[](betsOfAUser[betterAddress].length);
        uint256[] memory time__ = new uint256[](betsOfAUser[betterAddress].length);

        for (uint256 i = 0; i < betsOfAUser[betterAddress].length; i++) {
            lotsIds__[i] = bets[betsOfAUser[betterAddress][i]].lotId;
            bets__[i] = bets[betsOfAUser[betterAddress][i]].bet;
            time__[i] = bets[betsOfAUser[betterAddress][i]].time;
        }

        return (lotsIds__, bets__, time__);
    }

    function getAllLots() external view returns (Lot[] memory lots) {
        Lot[] memory _lots = new Lot[](lotsCounter);

        for (uint256 i = 0; i < lotsCounter; i++) {
            // Lot storage lot = lots[i];
            _lots[i] = lots[i];
        }

        return _lots;
    }
}