// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.9;

import "../../Shared/libraries/SafeMath.sol";
import "../../Shared/libraries/Strings.sol";
import "../libraries/LibRaffleModifiers.sol";
import "../../NFT/libraries/LibERC721.sol";
import "hardhat/console.sol";
import "../../VRF/libraries/LibVRF.sol";

/**
 * @title BeepBoopRaffleFacet contract
 */
contract BeepBoopRaffleFacet is LibRaffleModifiers, LibVRF {
    using SafeMath for uint256;
    using Strings for uint256;

    event BeepBoopRaffleEnded(uint numberOfEntries, uint numberOfWinners);
    event BeepBoopRaffleStarted(uint startTime, uint endTime);
    event BeepBoopRaffleWinner(address addr);

    /***************************************
     *                                     *
     *           Contract Logic            *
     *                                     *
     ***************************************/

    function setWatermelonAward(uint award) public onlyOwner {
        BeepBoopRaffleStorage storage s = LibBeepBoopRaffleStorage.diamondStorage();
        s.wmToAward = award;
    }

    /**
    * Enter in the raffle if you don't have one of our NFT's
    */
    function submitEntry(uint amount) public payable {
        BeepBoopRaffleStorage storage s = LibBeepBoopRaffleStorage.diamondStorage();
        ERC721Storage storage sNFT = LibERC721Storage.diamondStorage();

        require(!s.raffles[s.numberOfRaffles].PAUSED, "Entries are currently paused. Check later.");
        if (s.maxEntriesPerTransaction > 0) {
            require(amount <= s.maxEntriesPerTransaction, string(abi.encodePacked("Can only submit ", s.maxEntriesPerTransaction.toString(), " entries at a time.")));
        }
        if (s.maxEntries > 0) {
            require(s.raffles[s.numberOfRaffles].entryCount + amount <= s.maxEntries, "Purchase exceeds max entries allowed.");
        }
        require(!s.raffles[s.numberOfRaffles].IN_TRANSITION, 'Raffle is being initialized, wait a few seconds and try again.');
        require(s.entryFee.mul(amount) <= sNFT.watermelonToken.balanceOf(msg.sender), "You don't have enough $WM to submit your entry.");

        if (block.timestamp > s.raffles[s.numberOfRaffles].endTime) {
            awardRaffle();
        }

        for (uint i = 0; i < amount; i++) {
            s.raffles[s.numberOfRaffles].addressPerEntry[s.raffles[s.numberOfRaffles].entryCount++] = msg.sender;
        }
        s.raffles[s.numberOfRaffles].entriesPerAddress[msg.sender] += amount;
        sNFT.watermelonToken.burnTokensWithClaimable(msg.sender, s.entryFee.mul(amount));
    }

    function myEntryCount() public view returns (uint) {
        BeepBoopRaffleStorage storage s = LibBeepBoopRaffleStorage.diamondStorage();
        return s.raffles[s.numberOfRaffles].entriesPerAddress[msg.sender];
    }

    function totalEntryCount() public view returns (uint) {
        BeepBoopRaffleStorage storage s = LibBeepBoopRaffleStorage.diamondStorage();
        return s.raffles[s.numberOfRaffles].entryCount;
    }

    function addressForEntry(uint entry) public view returns (address) {
        BeepBoopRaffleStorage storage s = LibBeepBoopRaffleStorage.diamondStorage();
        return s.raffles[s.numberOfRaffles].addressPerEntry[entry];
    }

    function entryCountForAddress(address submitter) public view returns (uint) {
        BeepBoopRaffleStorage storage s = LibBeepBoopRaffleStorage.diamondStorage();
        return s.raffles[s.numberOfRaffles].entriesPerAddress[submitter];
    }

    function raffleCountSoFar() public view returns (uint) {
        BeepBoopRaffleStorage storage s = LibBeepBoopRaffleStorage.diamondStorage();
        return s.numberOfRaffles;
    }

    function getLast30Raffles() public view returns (UIBeepBoopRaffleData[] memory) {
        BeepBoopRaffleStorage storage s = LibBeepBoopRaffleStorage.diamondStorage();

        uint size = s.numberOfRaffles.add(1);
        if (size > 30) {
            size = 30;
        }

        UIBeepBoopRaffleData[] memory raffles = new UIBeepBoopRaffleData[](size);

        uint pusher = 0;
        for (uint i = s.numberOfRaffles; i > 0 && int(i) >= int(s.numberOfRaffles) - 30; i--) {
            bool amIWinner = false;
            for (uint x = 0; x <= s.raffles[i].numberOfAwardsPerRaffle; x++) {
                uint randomEntrySelection;
                if (s.raffles[i].awards[x].randomNumber == 0) {
                    randomEntrySelection = s.raffles[i].awards[x].randomNumber;
                } else {
                    randomEntrySelection = s.raffles[i].awards[x].randomNumber.mod(s.raffles[i].entryCount);
                }
                address winner = s.raffles[i].addressPerEntry[randomEntrySelection];

                if (msg.sender == winner) {
                    amIWinner = true;
                    break;
                }
            }

            raffles[pusher++] = UIBeepBoopRaffleData(
                s.raffles[i].entryCount,
                s.raffles[i].PAUSED,
                s.raffles[i].IN_TRANSITION,
                s.raffles[i].AWARDED,
                amIWinner,
                s.raffles[i].startTime,
                s.raffles[i].endTime,
                s.raffles[i].wmToAward,
                s.raffles[i].numberOfAwardsPerRaffle
            );
        }

        return raffles;
    }

    function getRaffle(uint raffleId) public view returns (UIBeepBoopRaffleData memory) {
        BeepBoopRaffleStorage storage s = LibBeepBoopRaffleStorage.diamondStorage();

        bool amIWinner = false;
        for (uint x = 0; x <= s.raffles[raffleId].numberOfAwardsPerRaffle; x++) {
            uint randomEntrySelection;

            if (s.raffles[raffleId].entryCount > 0) {
                if (s.raffles[raffleId].awards[x].randomNumber == 0) {
                    randomEntrySelection = s.raffles[raffleId].awards[x].randomNumber;
                } else {
                    randomEntrySelection = s.raffles[raffleId].awards[x].randomNumber.mod(s.raffles[raffleId].entryCount);
                }
                address winner = s.raffles[raffleId].addressPerEntry[randomEntrySelection];

                if (msg.sender == winner) {
                    amIWinner = true;
                    break;
                }
            }
        }

        return UIBeepBoopRaffleData(
            s.raffles[raffleId].entryCount,
            s.raffles[raffleId].PAUSED,
            s.raffles[raffleId].IN_TRANSITION,
            s.raffles[raffleId].AWARDED,
            amIWinner,
            s.raffles[raffleId].startTime,
            s.raffles[raffleId].endTime,
            s.raffles[raffleId].wmToAward,
            s.raffles[raffleId].numberOfAwardsPerRaffle
        );
    }

    function getPrizesForRaffle(uint raffleId) public view returns (UIRaffleAwardData[] memory) {
        BeepBoopRaffleStorage storage s = LibBeepBoopRaffleStorage.diamondStorage();

        require(s.raffles[raffleId].IN_TRANSITION, "This raffle was not yet finished");
        require(s.raffles[raffleId].entryCount > 0, "This raffle has no entries, therefore no winners.");

        UIRaffleAwardData[] memory awards = new UIRaffleAwardData[](s.raffles[raffleId].numberOfAwardsPerRaffle);
        uint pusher = 0;

        for (uint i = 0; i < s.raffles[raffleId].numberOfAwardsPerRaffle; i++) {
            uint randomEntrySelection;
            if (s.raffles[raffleId].awards[i].randomNumber == 0) {
                randomEntrySelection = s.raffles[raffleId].awards[i].randomNumber;
            } else {
                randomEntrySelection = s.raffles[raffleId].awards[i].randomNumber.mod(s.raffles[raffleId].entryCount);
            }
            address winner = s.raffles[raffleId].addressPerEntry[randomEntrySelection];

            awards[pusher++] = UIRaffleAwardData(
                winner,
                s.raffles[raffleId].awards[i].AWARDED
            );
        }

        return awards;
    }

    function wasIAwardedInRaffle(uint raffleId) public view returns (bool) {
        BeepBoopRaffleStorage storage s = LibBeepBoopRaffleStorage.diamondStorage();

        for (uint i = 0; i <= s.raffles[raffleId].numberOfAwardsPerRaffle; i++) {
            uint randomEntrySelection;
            if (s.raffles[raffleId].awards[i].randomNumber == 0) {
                randomEntrySelection = s.raffles[raffleId].awards[i].randomNumber;
            } else {
                randomEntrySelection = s.raffles[raffleId].awards[i].randomNumber.mod(s.raffles[raffleId].entryCount);
            }
            address winner = s.raffles[raffleId].addressPerEntry[randomEntrySelection];

            if (msg.sender == winner) {
                return true;
            }
        }

        return false;
    }

    function fulfillRandomness(uint raffleId, uint randomness) public {
        require(msg.sender == address(this), "Can only be called by itself");

        BeepBoopRaffleStorage storage s = LibBeepBoopRaffleStorage.diamondStorage();
        s.raffles[raffleId].awards[s.raffles[raffleId].randEntry++] = RaffleAwardData(randomness, false);
    }

    function collectAward(uint raffleId) public {
        BeepBoopRaffleStorage storage s = LibBeepBoopRaffleStorage.diamondStorage();
        ERC721Storage storage sNFT = LibERC721Storage.diamondStorage();

        require(s.raffles[raffleId].IN_TRANSITION, "This raffle was not yet finished");
        require(s.raffles[raffleId].AWARDED == false, "This raffle was already awarded");

        for (uint i = 0; i < s.raffles[raffleId].numberOfAwardsPerRaffle; i++) {
            RaffleAwardData storage award = s.raffles[raffleId].awards[i];

            if (award.AWARDED == false) {
                uint randomEntrySelection;
                if (award.randomNumber == 0) {
                    randomEntrySelection = award.randomNumber;
                } else {
                    randomEntrySelection = award.randomNumber.mod(s.raffles[raffleId].entryCount);
                }
                address winner = s.raffles[raffleId].addressPerEntry[randomEntrySelection];

                if (msg.sender == winner) {
                    s.raffles[raffleId].numberOfAwardedAddresses++;

                    if (s.raffles[raffleId].wmToAward > 0) {
                        sNFT.watermelonToken.issueTokens(winner, s.raffles[raffleId].wmToAward);
                    } else {
                        // Award NTF
                        LibERC721.safeMint(winner, 1);
                    }
                    s.raffles[raffleId].awards[i].AWARDED = true;

                    if (s.raffles[raffleId].numberOfAwardedAddresses >= s.raffles[raffleId].numberOfAwardsPerRaffle) {
                        s.raffles[raffleId].AWARDED = true;
                    }
                }
            }
        }
    }

    function airdropAward(uint raffleId) public {
        BeepBoopRaffleStorage storage s = LibBeepBoopRaffleStorage.diamondStorage();
        ERC721Storage storage sNFT = LibERC721Storage.diamondStorage();

        require(s.raffles[raffleId].IN_TRANSITION, "This raffle was not yet finished");
        require(s.raffles[raffleId].AWARDED == false, "This raffle was already awarded");

        for (uint i = 0; i < s.raffles[raffleId].numberOfAwardsPerRaffle; i++) {
            RaffleAwardData storage award = s.raffles[raffleId].awards[i];

            if (award.AWARDED == false) {
                uint randomEntrySelection;
                if (award.randomNumber == 0) {
                    randomEntrySelection = award.randomNumber;
                } else {
                    randomEntrySelection = award.randomNumber.mod(s.raffles[raffleId].entryCount);
                }
                address winner = s.raffles[raffleId].addressPerEntry[randomEntrySelection];

                s.raffles[raffleId].numberOfAwardedAddresses++;

                if (s.raffles[raffleId].wmToAward > 0) {
                    sNFT.watermelonToken.issueTokens(winner, s.raffles[raffleId].wmToAward);
                } else {
                    // Award NTF
                    LibERC721.safeMint(winner, 1);
                }
                s.raffles[raffleId].awards[i].AWARDED = true;

                if (s.raffles[raffleId].numberOfAwardedAddresses >= s.raffles[raffleId].numberOfAwardsPerRaffle) {
                    s.raffles[raffleId].AWARDED = true;
                }
            }
        }
    }

    function startNewRaffle() internal {
        BeepBoopRaffleStorage storage s = LibBeepBoopRaffleStorage.diamondStorage();

        s.numberOfRaffles++;
        s.raffles[s.numberOfRaffles].PAUSED = false;
        s.raffles[s.numberOfRaffles].IN_TRANSITION = false;
        s.raffles[s.numberOfRaffles].numberOfAwardsPerRaffle = s.numberOfAwardsPerRaffle;
        s.raffles[s.numberOfRaffles].wmToAward = s.wmToAward;

        s.raffles[s.numberOfRaffles].startTime = block.timestamp;
        s.raffles[s.numberOfRaffles].endTime = block.timestamp + s.durationInSeconds;

        emit BeepBoopRaffleStarted(s.raffles[s.numberOfRaffles].startTime, s.raffles[s.numberOfRaffles].endTime);
    }

    /***************************************
     *                                     *
     *             Time Logic              *
     *                                     *
     ***************************************/

    /**
     * To be used only in case the contract get's stuck for any reason.
     */
    function forceStartNewRaffle() public onlyOwner {
        startNewRaffle();
    }

    function awardRaffle() internal {
        BeepBoopRaffleStorage storage s = LibBeepBoopRaffleStorage.diamondStorage();
        s.raffles[s.numberOfRaffles].IN_TRANSITION = true;

        for (uint i = 0; i < s.raffles[s.numberOfRaffles].numberOfAwardsPerRaffle; i++) {
            requestRandomness(0, "BeepBoopRaffleFacet", s.numberOfRaffles);
        }

        emit BeepBoopRaffleEnded(s.raffles[s.numberOfRaffles].entryCount, s.raffles[s.numberOfRaffles].numberOfAwardsPerRaffle);

        startNewRaffle();
    }

    /***************************************
     *                                     *
     *          Emergency settings         *
     *                                     *
     ***************************************/

    function togglePauseBeepBoopRaffle() public onlyOwner {
        BeepBoopRaffleStorage storage s = LibBeepBoopRaffleStorage.diamondStorage();
        s.raffles[s.numberOfRaffles].PAUSED = !s.raffles[s.numberOfRaffles].PAUSED;
    }

    function setEntryFee(uint entryFeeParam) public onlyOwner {
        BeepBoopRaffleStorage storage s = LibBeepBoopRaffleStorage.diamondStorage();
        s.entryFee = entryFeeParam;
    }

    function setMaxEntriesPerTransaction(uint maxEntriesPerTransactionParam) public onlyOwner {
        BeepBoopRaffleStorage storage s = LibBeepBoopRaffleStorage.diamondStorage();
        s.maxEntriesPerTransaction = maxEntriesPerTransactionParam;
    }

    function setMaxEntries(uint maxEntriesParam) public onlyOwner {
        BeepBoopRaffleStorage storage s = LibBeepBoopRaffleStorage.diamondStorage();
        s.maxEntries = maxEntriesParam;
    }

    function setDurationInSeconds(uint durationInSecondsParam) public onlyOwner {
        BeepBoopRaffleStorage storage s = LibBeepBoopRaffleStorage.diamondStorage();
        s.durationInSeconds = durationInSecondsParam;
    }

    function setNumberOfAwardsPerRaffle(uint numberOfAwardsPerRaffleParam) public onlyOwner {
        BeepBoopRaffleStorage storage s = LibBeepBoopRaffleStorage.diamondStorage();
        s.numberOfAwardsPerRaffle = numberOfAwardsPerRaffleParam;
    }

}