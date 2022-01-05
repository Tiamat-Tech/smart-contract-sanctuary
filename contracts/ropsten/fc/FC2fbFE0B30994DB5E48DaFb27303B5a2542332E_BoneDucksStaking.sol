// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./Ownable.sol";
import "./SafeMath.sol";
import "./IERC721Receiver.sol";
import "./BoneDucks.sol";
import "./Snail.sol";

contract BoneDucksStaking is Ownable, IERC721Receiver {
    using SafeMath for uint256;
    
    // Establish interface for BoneDucks
    BoneDucks public boneDucks;
    
    // Establish interface for $Snail
    Snail public snail;

    event BoneDuckStolen(address previousOwner, address newOwner, uint256 tokenId);
    event BoneDuckStaked(address owner, uint256 tokenId, uint256 status);
    event BoneDuckClaimed(address owner, uint256 tokenId);
    
    // Maps tokenId to owner
    mapping(uint256 => address) public ownerById;
    /* Maps Status to tokenId
       Status is as follows:
        0 - Unstaked
        1 - Scavenger
        2 - Guardian
        3 - Apex
    */
    mapping(uint256 => uint256) public statusById;
    // Maps tokenId to time staked
    mapping(uint256 => uint256) public timeStaked;
    // Amount of $Snail stolen by Guardian while staked
    mapping(uint256 => uint256) public snailStolen;
    
    // Daily $Snail earned by Scavenger
    uint256 public scavengeringSnailRate = 100 ether;
    // Total number of Scavenger staked
    uint256 public totalScavengersStaked = 0;
    // Percent of $Snail earned by Scavenger that is kept
    uint256 public scavengerShare = 50;
    
    // Percent of $Snail earned by Scavenger that is stolen by guardians
    uint256 public guardianShare = 50;
    // 5% chance a Guardian gets lost each time it is unstaked
    uint256 public chanceGuardianGetsLost = 5; // 5%
    
    // Store tokenIds of all guardians staked
    uint256[] public guardiansStaked;
    // Store tokenIds of all apexes staked
    uint256[] public apexesStaked;
    
    // 1 day lock on staking
    uint256 public minStakeTime = 1 days;
    
    bool public staking = false;
    
    constructor() {}
    
    //-----------------------------------------------------------------------------//
    //------------------------------Staking----------------------------------------//
    //-----------------------------------------------------------------------------//
    
    modifier checkStakingIsActive {
        require (
            staking,
            "Public Staking is not active"
        );
        _;
    }

    /* Sends any number of BoneDucks to the Staking, should be approve to staking contract as first
        ids -> list of Boneduck ids to stake
        Status == 1 -> Scavenger
        Status == 2 -> Guardian
        Status == 3 -> Apex
    */
    function stakeDucks(uint256[] calldata ids, uint256 status) external checkStakingIsActive {
        for( uint256 i = 0; i < ids.length; i += 1){
            require(boneDucks.ownerOf(ids[i]) == msg.sender, "Not your BoneDuck");
            
            statusById[ids[i]] = status;
            ownerById[ids[i]] = msg.sender;
            timeStaked[ids[i]] = block.timestamp;

            emit BoneDuckStaked(msg.sender, ids[i], status);
            boneDucks.transferFrom(msg.sender, address(this), ids[i]);

            if (status == 1) { // Scavenger
                totalScavengersStaked += 1;
            } else if (status == 2){ // Guardian
                guardiansStaked.push(ids[i]);
            } else if (status == 3){ // Apex
                apexesStaked.push(ids[i]);
            }
        }
    }
    
    function unstakeDucks(uint256[] calldata ids) external checkStakingIsActive {
        for(uint256 i = 0; i < ids.length; i += 1) {
            require(ownerById[ids[i]] == msg.sender, "Not your BoneDuck");
            require(boneDucks.ownerOf(ids[i]) == address(this), "BoneDuck must be staked in order to claim");
            require(block.timestamp - timeStaked[ids[i]] >= minStakeTime, "At least 1 day stake lock");

            _claim(msg.sender, ids[i]);

            if (statusById[ids[i]] == 1) { // Scavenger
                totalScavengersStaked -= 1;
            } else if (statusById[ids[i]] == 2) { // Guardian
                for (uint256 j = 0; j < guardiansStaked.length; j++) {
                    if (guardiansStaked[j] == ids[i]){
                        guardiansStaked[j] = guardiansStaked[guardiansStaked.length - 1];
                        guardiansStaked.pop();
                    }
                }                
            } else if (statusById[ids[i]] == 3) { // Apex
                for (uint256 j = 0; j < apexesStaked.length; j++){
                    if (apexesStaked[j] == ids[i]){
                        apexesStaked[j] = apexesStaked[apexesStaked.length - 1];
                        apexesStaked.pop();
                    }
                } 
            }

            statusById[ids[i]] = 0;
            boneDucks.safeTransferFrom(address(this), ownerById[ids[i]], ids[i]);

            emit BoneDuckClaimed(ownerById[ids[i]], ids[i]);
        }
    }

    function claimDucks(uint256[] calldata ids) external checkStakingIsActive {
        for (uint256 i = 0; i < ids.length; i += 1) {
            require(ownerById[ids[i]] == msg.sender, "Not your BoneDuck");
            require(boneDucks.ownerOf(ids[i]) == address(this), "BoneDuck must be staked in order to claim");
            
            _claim(msg.sender, ids[i]);
            emit BoneDuckClaimed(address(this), ids[i]);
        }
    }
    
    function _claim(address owner, uint256 tokenId) internal {
        if (statusById[tokenId] == 1) { // Scavenger
            if (guardiansStaked.length > 0) {
                snail.mint(owner, getPendingSnail(tokenId).mul(scavengerShare).div(100));
                distributeAmongstGuardians(getPendingSnail(tokenId).mul(guardianShare).div(100));
            } else {
                snail.mint(owner, getPendingSnail(tokenId));
            }            
        } else if (statusById[tokenId] == 2) { // Guardian
            uint256 roll = randomIntInRange(tokenId, 100);
            if(roll > chanceGuardianGetsLost || apexesStaked.length == 0){
                snail.mint(owner, snailStolen[tokenId]);
                snailStolen[tokenId] = 0;
            } else {
                getNewOwnerForGuardian(roll, tokenId);
            }
        }
        timeStaked[tokenId] = block.timestamp;
    }
    
    // Passive earning of $Snail, 100 $Snail per day
    function getPendingSnail(uint256 id) internal view returns(uint256) {
        return (block.timestamp - timeStaked[id]) * 100 ether / 1 days;
    }
    
    // Distribute stolen $Snail accross all staked Guardians
    function distributeAmongstGuardians(uint256 amount) internal {
        for (uint256 i = 0; i < guardiansStaked.length; i++){
            snailStolen[guardiansStaked[i]] += amount.div(guardiansStaked.length);
        }
    }
    
    // Returns a pseudo-random integer between 0 - max
    function randomIntInRange(uint256 seed, uint256 max) internal view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(
            tx.origin,
            blockhash(block.number - 1),
            block.timestamp,
            seed
        ))) % max;
    }
    
    
    // Return new owner of lost guardian from current apexes
    function getNewOwnerForGuardian(uint256 seed, uint256 tokenId) internal {
        uint256 roll = randomIntInRange(seed, apexesStaked.length);
        ownerById[tokenId] = ownerById[apexesStaked[roll]];
        snail.mint(ownerById[tokenId], snailStolen[tokenId]);
        snailStolen[tokenId] = 0;

        emit BoneDuckStolen(ownerById[tokenId], ownerById[apexesStaked[roll]], tokenId);
    }
      
    function getTotalGuardiansStaked() public view returns (uint256) {
        return guardiansStaked.length;
    }

    function getTotalApexesStaked() public view returns (uint256) {
        return apexesStaked.length;
    }

    // Set address for BoneDucks
    function setBoneDucksAddress(address boneDucksAddress) external onlyOwner {
        boneDucks = BoneDucks(boneDucksAddress);
    }
    
    // Set address for $Snail
    function setSnailAddress(address snailAddress) external onlyOwner {
        snail = Snail(snailAddress);
    }
    
    //Start/Stop staking
    function toggleStaking() public onlyOwner {
        staking = !staking;
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
      return IERC721Receiver.onERC721Received.selector;
    }
}