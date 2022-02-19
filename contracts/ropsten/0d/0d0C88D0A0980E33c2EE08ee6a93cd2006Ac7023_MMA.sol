//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

contract MMA is Ownable {
    struct Bounty {
        uint256 fighterId;
        uint256 poolPct;
    }

    struct FightBounty {
        mapping(uint256 => Bounty) bounties;
        uint256 numBounties;
        uint256 winnerPct;
        uint256 winnerId;
        bool openToContribute;
        uint256 bountyAmount;
    }

    struct Fighter {
        address payable fighterAddress;
        string name;
    }

    mapping(uint256 => FightBounty) public fightBounties;
    uint256 public fightBountiesCount = 1;
    mapping(uint256 => Fighter) public fighters;
    uint256 public fightersCount = 1;

    function createFightBounty(
        uint256 fighterId1,
        uint256 fighterPct1,
        uint256 fighterId2,
        uint256 fighterPct2,
        uint256 winnerPct
    ) public payable {
        require(fighterId1 != fighterId2, "");
        require(fighterPct1 + fighterPct2 + winnerPct == 100, "");
        require(fighters[fighterId1].fighterAddress != address(0), "");
        require(fighters[fighterId2].fighterAddress != address(0), "");
        require(msg.value >= 1 ether, "pay at least 1 ether");
        fightBounties[fightBountiesCount].winnerId = 0;
        fightBounties[fightBountiesCount].winnerPct = 0;
        fightBounties[fightBountiesCount].openToContribute = true;
        fightBounties[fightBountiesCount].bountyAmount = msg.value;
        fightBounties[fightBountiesCount].numBounties = 0;
        fightBounties[fightBountiesCount].bounties[
            fightBounties[fightBountiesCount].numBounties
        ] = Bounty(fighterId1, fighterPct1);
        fightBounties[fightBountiesCount].numBounties++;
        fightBounties[fightBountiesCount].bounties[
            fightBounties[fightBountiesCount].numBounties
        ] = Bounty(fighterId2, fighterPct2);
        fightBountiesCount++;
    }

    function contribute(uint256 fightBountyId) public payable {
        require(
            fightBounties[fightBountyId].openToContribute == true,
            "Fight already ended"
        );
        fightBounties[fightBountyId].bountyAmount += msg.value;
    }

    function lockContributions(uint256 fightBountyId) public onlyOwner {
        fightBounties[fightBountyId].openToContribute = false;
    }

    function completeFight(uint256 fightId, uint256 winnerId) public onlyOwner {
        lockContributions(fightId);
        FightBounty storage fight = fightBounties[fightId];
        fight.winnerId = winnerId;

        for (uint256 i = 0; i < fight.numBounties; i++) {
            if (fight.bounties[i].fighterId == winnerId) {
                fight.bounties[i].poolPct += fight.winnerPct;
            }
            fighters[fight.bounties[i].fighterId].fighterAddress.transfer(
                (fight.bounties[i].poolPct * fight.bountyAmount) / 100
            );
        }
    }

    function getFighter(uint256 fighterId)
        public
        view
        returns (address, string memory)
    {
        return (fighters[fighterId].fighterAddress, fighters[fighterId].name);
    }

    function getFight(uint256 fightBountyId)
        public
        view
        returns (
            uint256[] memory,
            uint256[] memory,
            uint256,
            uint256,
            bool,
            uint256
        )
    {
        uint256[] memory fighterIds = new uint256[](
            fightBounties[fightBountyId].numBounties
        );
        uint256[] memory fighterBounties = new uint256[](
            fightBounties[fightBountyId].numBounties
        );
        for (uint256 j = 0; j < fightBounties[fightBountyId].numBounties; j++) {
            fighterIds[j] = fightBounties[fightBountyId].bounties[j].fighterId;
            fighterBounties[j] = fightBounties[fightBountyId]
                .bounties[j]
                .poolPct;
        }
        return (
            fighterIds,
            fighterBounties,
            fightBounties[fightBountyId].winnerPct,
            fightBounties[fightBountyId].winnerId,
            fightBounties[fightBountyId].openToContribute,
            fightBounties[fightBountyId].bountyAmount
        );
    }

    function createFighter(string memory name, address payable fighterAddress)
        public
        onlyOwner
        returns (uint256)
    {
        fighters[fightersCount] = Fighter({
            name: name,
            fighterAddress: fighterAddress
        });
        fightersCount++;
        return fightersCount - 1;
    }

    function removeFighter(uint256 fighterId) public onlyOwner {
        require(fighters[fighterId].fighterAddress != address(0), "");
        fighters[fighterId] = Fighter({name: "", fighterAddress: payable(0)});
    }
}