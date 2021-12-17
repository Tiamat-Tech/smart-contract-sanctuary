// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "./Administration.sol";

interface IStrip is IERC20 {
    function burnTokens(uint amount) external;
}

interface IStripperVille is IERC721 {
    function clubsCount() external view returns (uint256);
}

contract StripperVilleGameNew is Administration, Pausable {
    using Counters for Counters.Counter;
    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableSet for EnumerableSet.AddressSet;

    event Claim(address indexed caller, uint256 qty);
    event Work(uint256 tokenId, uint256 gameId);
    event BuyWorker(address indexed to, uint256 gameId, uint256 stripperId, bool isThief);

    struct Game {
        uint256 prize;
        uint256 startBlock;
        uint256 endBlock;
        uint256 price;
        uint256 maxThieves;
        uint256 availableCustomers;
        uint256 customerMultiplier;
    }

    struct Club {
        uint256 percentage;
        mapping(address => uint256) usersAndStrippersInClub;
        EnumerableSet.AddressSet addressesInClub;
        uint256 totalStrippers;
        // EnumerableSet.UintSet strippers;
        uint256 earn;
    }

    uint public thiefPrice = 100 ether;
    uint public customerPrice = 100 ether;

    IStrip public _coin;
    IStripperVille public _nft;

    Counters.Counter private _gameCounter;
    // stripperId => earnAmt
    mapping(uint256 => uint256) private _stripperEarnings;
    // gameNumber => Game
    mapping(uint256 => Game) private _games;
    // gameNumber => stripperId => hasCustomer
    mapping(uint256 => mapping(uint256 => bool)) private _gameStripperHasCustomer;
    // gameNumber => stripperId => clubId
    mapping(uint256 => mapping(uint256 => uint256)) private _gameStripperInClub;
    // gameNumber => clubId => Club
    mapping(uint => mapping (uint => Club)) private _gameClub;
    // account -> stripperId
    // Limit 1 customer per account and can only be assigned to 1 stripper
    mapping(address => uint256) private _currentGameCustomers;
    // gameNumber => top5 clubs for earn
    mapping(uint256 => uint[5]) private _gameClubRanks;
    // address => coinAmtEarned
    mapping(address => uint256) private _gameRewardsUnclaimed;

    modifier requireContractsSet() {
        require(address(_nft) != address(0) && address(_coin) != address(0), "Contracts not set");
        _;
    }
    
    modifier currentGameActive(){
        require(getCurrentGame().startBlock > 0 && getCurrentGame().endBlock == 0, "Game not active");
        _;
    }
    
    function getCurrentGame() public view returns (Game memory) {
        return _games[_gameCounter.current()];
    }

    function getEarnValue(uint256 stripperId) public view returns (uint256) {
        return _stripperEarnings[stripperId];
    }

    function isStripperCurrentlyInClub(uint256 stripperId) external view returns (bool) {
        return _gameStripperInClub[_gameCounter.current()][stripperId] >= 1000000;
    }

    function getClubOfStripper(uint256 gameId, uint256 stripperId) external view returns (uint256) {
        return _gameStripperInClub[gameId][stripperId];
    }

    function getUnclaimedGameRewards(address addr) external view returns (uint256) {
        return _gameRewardsUnclaimed[addr];
    }

    function getClubIds() external view returns (uint[] memory){
        uint[] memory ids = new uint[](_nft.clubsCount());
        uint initial = 1000000;
        for(uint i = 0; i < ids.length; i++) {
            ids[i] = i + initial;
        }
        return ids;
    }

    function getCustomerStripper() public view returns (uint256) {
        // Will return 0 if there isn't a customer purchased.
        // The game currently requires every customer purchase to instantly assign to an NFT
        return _currentGameCustomers[_msgSender()];
    }

    function claimRewards() external whenNotPaused {
        uint256 rewards = _gameRewardsUnclaimed[_msgSender()];
        require(rewards > 0, "No rewards to claim");
        _coin.transfer(_msgSender(), rewards);
        _gameRewardsUnclaimed[_msgSender()] = 0;
        emit Claim(_msgSender(), rewards);
    }
    
    function getCurrentGameId() public view returns (uint256) {
        return _gameCounter.current();
    }

    function pause() public onlyAdmin {
        _pause();
    }
    function unpause() public onlyAdmin {
        _unpause();
    }
    
    function setContracts(address coin, address nft) external onlyAdmin {
        _coin = IStrip(coin);
        _nft = IStripperVille(nft);
    }
    
    function setPrices(uint customer, uint thief) external onlyAdmin {
        thiefPrice = thief;
        customerPrice = customer;
    }

    function startNewGame(
        uint256 gamePrize,
        uint256 price,
        uint256 maxThieves,
        uint256 availableCustomers,
        uint256 customersMultiply
    ) external requireContractsSet onlyAdmin
    {
        // Increment the counter here to allow the last finished games to be accessible
        _gameCounter.increment();
        _games[_gameCounter.current()] = Game(
            gamePrize, 
            block.number, 
            0, 
            price, 
            maxThieves, 
            availableCustomers, 
            customersMultiply
        );
    }

    function endCurrentGame() external onlyAdmin {
        Game storage game = _games[_gameCounter.current()];
        game.endBlock = block.number;
        uint256[5] memory clubRanks = _gameClubRanks[_gameCounter.current()];
        for (uint256 i = 0; i < clubRanks.length; i++) {
            if(clubRanks[i] == 0) {
                continue;
            }
            Club storage club = _gameClub[_gameCounter.current()][clubRanks[i]];
            uint256 prizePercent = getPrizePercentForRank(i);
            uint256 totalClubEarning = game.prize * prizePercent / 100;
            uint256 clubOwnerReward = totalClubEarning * 10 / 100;
            uint256 rewardPerStripper = totalClubEarning * 90 / 100 / club.totalStrippers;
            _gameRewardsUnclaimed[_nft.ownerOf(clubRanks[i])] += clubOwnerReward;
            // Loop through each address that has strippers working in this club
            // This avoids high gas claiming for users
            for (uint256 j = 0; j < club.addressesInClub.length(); j++) {
                address addrCur = club.addressesInClub.at(j);
                _gameRewardsUnclaimed[addrCur] += rewardPerStripper 
                    * club.usersAndStrippersInClub[addrCur];
            }
        }
        // TODO: clean up old storage using delete keyword
    }

    function setEarns(uint256 startingId, uint256 endingId, uint256[] calldata earns) external onlyAdmin {
        require(endingId >= startingId, "Invalid chunk of ids");
        require(endingId - startingId + 1 == earns.length, "Wrong # of earn values given");
        for (uint256 i = startingId; i <= endingId; i += 1) {
            _stripperEarnings[i] = earns[i - startingId];
        }
    }
    
    function buyCustomer(uint256 stripperId) external currentGameActive {
        require(_coin.balanceOf(_msgSender()) >= customerPrice, "BALANCE: insuficient funds");
        require(getCurrentGame().availableCustomers > 0, "No customers available.");
        require(_nft.ownerOf(stripperId) == _msgSender(), "Not owner of token");
        require(_gameStripperInClub[_gameCounter.current()][stripperId] < 1000000, "Stripper cannot be in club");
        _currentGameCustomers[_msgSender()] = stripperId;
        _games[_gameCounter.current()].availableCustomers -= 1;
        emit BuyWorker(_msgSender(), _gameCounter.current(), stripperId, false);
    }

    function sortTop5(uint256 clubIdChanged, uint256 clubEarn) private {
        uint256[5] storage ranks = _gameClubRanks[_gameCounter.current()];
        uint256 shiftingClubId = clubIdChanged;
        uint256 shiftingClubEarn = clubEarn;
        for (uint256 i = 0; i < ranks.length; i++) {
            if(ranks[i] == shiftingClubId) {
                return;
            }
            uint256 currentClubEarn = _gameClub[_gameCounter.current()][ranks[i]].earn;
            if(shiftingClubEarn > currentClubEarn) {
                // Save the current clubId as the current rank
                //  and take the old current to be shifted to the next rank
                (ranks[i], shiftingClubId) = (shiftingClubId, ranks[i]);
                shiftingClubEarn = currentClubEarn;
            }
        }

    }
    
    function work(uint256[] calldata stripperIds, uint256 clubId) external currentGameActive whenNotPaused {
        require(stripperIds.length > 0, "No tokens given");
        require(clubId >= 1000000, "CLUB: token is not a club");
        // NOTE: Cannot verify that clubId exists due to lack of _exists visibility
        Game memory game = getCurrentGame();
        if(game.price > 0) {
            // Burn the number of total coins needed to send every token to a club
            require(_coin.balanceOf(_msgSender()) >= game.price * stripperIds.length, "BALANCE: insuficient funds");
            _coin.burnTokens(game.price * stripperIds.length);
        }
        uint newClubEarn;
        for (uint256 i = 0; i < stripperIds.length; i++) {
            uint256 stripperId = stripperIds[i];
            require(_gameStripperInClub[_gameCounter.current()][stripperId] < 1000000, "NFT already in club");
            require(_nft.ownerOf(stripperId) == _msgSender(), "Not owner of token");
            uint256 earn = getEarnValue(stripperId);
            // If the stripper has a customer assigned to them,
            //  increase the earn by the customer's multiplier
            if(_currentGameCustomers[_msgSender()] == stripperId) {
                earn *= game.customerMultiplier;
            }

            // Assign stripper to club
            // Increment club earn / stripper count
            Club storage club = _gameClub[_gameCounter.current()][clubId];
            club.earn += earn;
            newClubEarn = club.earn;
            club.usersAndStrippersInClub[_msgSender()]++;
            // Will only add if not present in array
            club.addressesInClub.add(_msgSender());
            club.totalStrippers++;
            _gameStripperInClub[_gameCounter.current()][stripperId] = clubId;
            emit Work(stripperId, _gameCounter.current());
        }
        sortTop5(clubId, newClubEarn);
    }

    function getPrizePercentForRank(uint256 rankIndex) internal pure returns (uint256) {
        if(rankIndex == 0) {
            return 40;
        }
        if(rankIndex == 1) {
            return 30;
        }
        if(rankIndex == 2) {
            return 15;
        }
        if(rankIndex == 3) {
            return 10;
        }
        if(rankIndex == 4) {
            return 5;
        }
        return 0;
    }
}