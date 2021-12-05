// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "./Interfaces.sol";
import "./IRift.sol";

contract EnterTheRift is Ownable, IRiftQuest {

    mapping(uint64 => QuestStep) public steps;
    mapping(uint256 => BagProgress) public bagsProgress;
    uint32 private _numSteps;

    ICrystals public iCrystals;
    IRiftQuest public iRiftQuest;
    ERC20 public iMana;
    
    address riftQuest;
    address crystals;
    address mana;

    constructor(address riftQuest_, address crystals_, address mana_) Ownable() {
        iCrystals = ICrystals(crystals_);
        iRiftQuest = IRiftQuest(riftQuest_);
        iMana = ERC20(mana_);

        _numSteps = 3;
        
        steps[1].action = "Step into the Rift";
        steps[1].description = "Ever since you first picked up that bag, you've felt drawn to this place. Now you see what's beckoning you, a chaotic rip in reality. You're struck with pure fear, and yet you cannot help but step towards it.";
        steps[1].result = "You didn't venture far, a few feet maybe. You couldn't stand the tremendous force for more than a few moments. You're not ready. ~~you got a rift charge~~";
        steps[1].xp = 50;

        steps[2].action = "Distill a Crystal";
        steps[2].description = "You've returned to camp to make sense of what you experienced, when you notice that same strange force emanating from your bag.";
        steps[2].result = "You peek inside, and see the glowing force crystalize before your eyes. It's glowing with the Rift's power... ~~you found a crystal!~~";
        steps[2].xp = 100;

        steps[3].action = "Claim Mana";
        steps[3].description = "You take the Crystal out of your bag, it's heavier than it looks.";
        steps[3].result = "Its glow intensifies, and you feel a powerful energy move from the Crystal into you. ~~you gained mana~~";
        steps[3].xp = 100;
    }

    // step logic 
    
    function completeStep(uint64 step, uint256 bagId, address from) override public {
        require(_msgSender() == riftQuest, "must be interacted through RiftQuests");
        require(bagsProgress[bagId].lastCompletedStep < step, "you've completed this step already");

        if (step == 1) {
            // owner bag check performed by RiftQuests
            bagsProgress[bagId].lastCompletedStep = 1;
        } else if (step == 2) {
            // verify bag made a crystal
            require(iCrystals.bags(bagId).mintCount > 0, "Make a Crystal");
            bagsProgress[bagId].lastCompletedStep = 2;
        } else if (step == 3) {
            require(iMana.balanceOf(from) > 0, "Claim your Mana");
            bagsProgress[bagId].lastCompletedStep = 3;
            bagsProgress[bagId].completedQuest = true;
        }
    }

    //IRiftQuest

    function title() override public pure returns (string memory) {
        return "Enter the Rift";
    }

    function numSteps() override public view returns (uint64) {
        return _numSteps;
    }

    function canStartQuest(uint256 /*bagId*/) override public pure returns (bool) {
        return true;
    }

    function isCompleted(uint256 bagId) override public view returns (bool) {
        return bagsProgress[bagId].completedQuest;
    }

    function currentStep(uint256 bagId) override public view returns (QuestStep memory) {
        return steps[uint64(bagId)];
    }

    function stepAwardXP(uint64 step) external view returns (uint32) {
        return steps[step].xp;
    }

    function tokenURI(uint256 /*bagId*/) override external pure returns (string memory) {
        string memory output;
        return output;
    }

    //owner
    
    function ownerSetCrystalsAddress(address crystals_) external onlyOwner {
        iCrystals = ICrystals(crystals_);
    }

    function ownerSetRiftQuestsAddress(address riftQuests_) external onlyOwner {
        iRiftQuest = IRiftQuest(riftQuests_);
    }

    function ownerSetManaAddress(address mana_) external onlyOwner {
        iMana = ERC20(mana_);
    }
}