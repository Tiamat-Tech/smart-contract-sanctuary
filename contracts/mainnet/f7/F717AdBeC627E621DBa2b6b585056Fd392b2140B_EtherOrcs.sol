// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.7;

import "./ERC20.sol";
import "./ERC721.sol"; 

//    ___ _   _               ___            
//  | __| |_| |_  ___ _ _   / _ \ _ _ __ ___
//  | _||  _| ' \/ -_) '_| | (_) | '_/ _(_-<
//  |___|\__|_||_\___|_|    \___/|_| \__/__/
//

interface MetadataHandlerLike {
    function getTokenURI(uint16 id, uint8 body, uint8 helm, uint8 mainhand, uint8 offhand, uint16 level, uint16 zugModifier) external view returns (string memory);
}


contract EtherOrcs is ERC721 {

    /*///////////////////////////////////////////////////////////////
                    Global STATE
    //////////////////////////////////////////////////////////////*/

    uint256 public constant  cooldown = 10 minutes;
    uint256 public constant  startingTime = 1633951800 + 4.5 hours;

    address public migrator;

    bytes32 internal entropySauce;

    ERC20 public zug;

    mapping (address => bool)     public auth;
    mapping (uint256 => Orc)      public orcs;
    mapping (uint256 => Action)   public activities;
    mapping (Places  => LootPool) public lootPools;
    
    uint256 mintedFromThis = 0;
    bool mintOpen = false;

    MetadataHandlerLike metadaHandler;

    function setAddresses(address mig, address meta) external onlyOwner {
        migrator      = mig;
        metadaHandler = MetadataHandlerLike(meta);
    }

    function setAuth(address add, bool isAuth) external onlyOwner {
        auth[add] = isAuth;
    }


    function transferOwnership(address newOwner) external  onlyOwner{
        admin = newOwner;
    }
    
    function setMintable(bool val) external onlyOwner {
        mintOpen = val;
    }


    function tokenURI(uint256 id) external view returns(string memory) {
        Orc memory orc = orcs[id];
        return metadaHandler.getTokenURI(uint16(id), orc.body, orc.helm, orc.mainhand, orc.offhand, orc.level, orc.zugModifier);
    }

    event ActionMade(address owner, uint256 id, uint256 timestamp, uint8 activity);


    /*///////////////////////////////////////////////////////////////
                DATA STRUCTURES 
    //////////////////////////////////////////////////////////////*/

    struct LootPool { 
        uint8  minLevel; uint8  minLootTier; uint16  cost;   uint16 total;
        uint16 tier_1;   uint16 tier_2;      uint16 tier_3; uint16 tier_4;
    }

    struct Orc { uint8 body; uint8 helm; uint8 mainhand; uint8 offhand; uint16 level; uint16 zugModifier; uint32 lvlProgress; }

    enum   Actions { UNSTAKED, FARMING, TRAINING }
    struct Action  { address owner; uint88 timestamp; Actions action; }

    // These are all the places you can go search for loot
    enum Places { 
        TOWN, DUNGEON, CRYPT, CASTLE, DRAGONS_LAIR, THE_ETHER, 
        TAINTED_KINGDOM, OOZING_DEN, ANCIENT_CHAMBER, ORC_GODS 
    }   

    /*///////////////////////////////////////////////////////////////
                    CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    // function initialize() public onlyOwner {
        
    // }

    /*///////////////////////////////////////////////////////////////
                    MODIFIERS 
    //////////////////////////////////////////////////////////////*/

    modifier noCheaters() {
        uint256 size = 0;
        address acc = msg.sender;
        assembly { size := extcodesize(acc)}

        require(auth[msg.sender] || (msg.sender == tx.origin && size == 0), "you're trying to cheat!");
        _;

        // We'll use the last caller hash to add entropy to next caller
        entropySauce = keccak256(abi.encodePacked(acc, block.coinbase));
    }

    modifier ownerOfOrc(uint256 id) { 
        require(ownerOf[id] == msg.sender || activities[id].owner == msg.sender, "not your orc");
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == admin);
        _;
    }


    /*///////////////////////////////////////////////////////////////
                    PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function mint() public noCheaters returns (uint256 id) {
        uint256 cost = _getMintingPrice();
        uint256 rand = _rand();
        require(address(zug) != address(0) && mintOpen);

        if (cost > 0) zug.burn(msg.sender, cost);
        return _mintOrc(rand);
    }

    // Craft an identical orc from v1!
    function craft(address owner_, uint256 id, uint8 body, uint8 helm, uint8 mainhand, uint8 offhand, uint16 level, uint32 lvlProgres) public {
        require(msg.sender == migrator);

        _mint(owner_, id);

        uint16 zugModifier = _tier(helm) + _tier(mainhand) + _tier(offhand);
        orcs[uint256(id)] = Orc({body: body, helm: helm, mainhand: mainhand, offhand: offhand, level: level, lvlProgress: lvlProgres, zugModifier:zugModifier});
    }

    function doAction(uint256 id, Actions action_) public ownerOfOrc(id) noCheaters {
       _doAction(id, msg.sender, action_);
    }

    function _doAction(uint256 id, address orcOwner, Actions action_) internal {
        Action memory action = activities[id];
        require(action.action != action_, "already doing that");

        // Picking the largest value between block.timestamp, action.timestamp and startingTime
        uint88 timestamp = uint88(block.timestamp > action.timestamp ? block.timestamp : action.timestamp);

        if (action.action == Actions.UNSTAKED)  _transfer(orcOwner, address(this), id);
     
        else {
            if (block.timestamp > action.timestamp) _claim(id);
            timestamp = timestamp > action.timestamp ? timestamp : action.timestamp;
        }

        address owner_ = action_ == Actions.UNSTAKED ? address(0) : orcOwner;
        if (action_ == Actions.UNSTAKED) _transfer(address(this), orcOwner, id);

        activities[id] = Action({owner: owner_, action: action_,timestamp: timestamp});
        emit ActionMade(orcOwner, id, block.timestamp, uint8(action_));
    }

    function doActionWithManyOrcs(uint256[] calldata ids, Actions action_) external {
        for (uint256 index = 0; index < ids.length; index++) {
            _doAction(ids[index], msg.sender, action_);
        }
    }

    function claim(uint256[] calldata ids) external {
        for (uint256 index = 0; index < ids.length; index++) {
            _claim(ids[index]);
        }
    }

    function _claim(uint256 id) internal noCheaters {
        Orc    memory orc    = orcs[id];
        Action memory action = activities[id];

        if(block.timestamp <= action.timestamp) return;

        uint256 timeDiff = uint256(block.timestamp - action.timestamp);

        if (action.action == Actions.FARMING) zug.mint(action.owner, claimableZug(timeDiff, orc.zugModifier));
       
        if (action.action == Actions.TRAINING) {
            uint256 progress = timeDiff * 3000 / 1 days;
            orcs[id].lvlProgress = uint16(progress % 1000);
            orcs[id].level      += uint16(progress / 1000);
        }

        activities[id].timestamp = uint88(block.timestamp);
    }

    function pillage(uint256 id, Places place, bool tryHelm, bool tryMainhand, bool tryOffhand) public ownerOfOrc(id) noCheaters {
        require(block.timestamp >= uint256(activities[id].timestamp), "on cooldown");
        require(place != Places.ORC_GODS,  "You can't pillage the Orc God");
        require(mintOpen);

        if(activities[id].timestamp < block.timestamp) _claim(id); // Need to claim to not have equipment reatroactively multiplying

        uint256 rand_ = _rand();
  
        LootPool memory pool = lootPools[place];
        require(orcs[id].level >= uint16(pool.minLevel), "below minimum level");

        if (pool.cost > 0) {
            require(block.timestamp - startingTime > 14 days);
            zug.burn(msg.sender, uint256(pool.cost) * 1 ether);
        } 

        uint8 item;
        if (tryHelm) {
            ( pool, item ) = _getItemFromPool(pool, _randomize(rand_,"HELM", id));
            if (item != 0 ) orcs[id].helm = item;
        }
        if (tryMainhand) {
            ( pool, item ) = _getItemFromPool(pool, _randomize(rand_,"MAINHAND", id));
            if (item != 0 ) orcs[id].mainhand = item;
        }
        if (tryOffhand) {
            ( pool, item ) = _getItemFromPool(pool, _randomize(rand_,"OFFHAND", id));
            if (item != 0 ) orcs[id].offhand = item;
        }

        if (uint(place) > 1) lootPools[place] = pool;

        // Update zug modifier
        Orc memory orc = orcs[id];
        uint16 zugModifier_ = _tier(orc.helm) + _tier(orc.mainhand) + _tier(orc.offhand);

        orcs[id].zugModifier = zugModifier_;

        activities[id].timestamp = uint88(block.timestamp + cooldown);
    } 

    function update(uint256 id) public ownerOfOrc(id) noCheaters {
        require(_tier(orcs[id].mainhand) < 10);
        require(block.timestamp - startingTime >= 14 days);
        require(mintOpen);
        
        LootPool memory pool = lootPools[Places.ORC_GODS];
        require(orcs[id].level >= pool.minLevel);

        zug.burn(msg.sender, uint256(pool.cost) * 1 ether);

        _claim(id); // Need to claim to not have equipment reatroactively multiplying

        uint8 item = uint8(lootPools[Places.ORC_GODS].total--);
        orcs[id].zugModifier = 30;
        orcs[id].body = orcs[id].helm = orcs[id].mainhand = orcs[id].offhand = item + 40;
    }

     function doActionSpecial(uint256 id, address orcOwner, uint256 timestamp, uint8 action_) external {
        require(msg.sender == migrator);
    
        _transfer(orcOwner, address(this), id);

        activities[id] = Action({owner: orcOwner, action: Actions(action_),timestamp: uint88(timestamp)});
        emit ActionMade(orcOwner, id, block.timestamp, uint8(action_));
    }

    function adjustTimestamp() external onlyOwner {
        activities[3189].timestamp = 13440136;
        activities[4211].timestamp = 13441315;
        activities[4263].timestamp = 13440520;
        activities[4307].timestamp = 13439409;
        activities[4323].timestamp = 13440672; 
        activities[4335].timestamp = 13439786; 
        activities[4338].timestamp = 13439246;
        activities[4341].timestamp = 13441829;
    }
    
    /*///////////////////////////////////////////////////////////////
                    VIEWERS
    //////////////////////////////////////////////////////////////*/

    function claimable(uint256 id) external view returns (uint256 amount) {
        uint256 timeDiff = block.timestamp > activities[id].timestamp ? uint256(block.timestamp - activities[id].timestamp) : 0;
        amount = activities[id].action == Actions.FARMING ? claimableZug(timeDiff, orcs[id].zugModifier) : timeDiff * 3000 / 1 days;
    }

    function name() external pure returns (string memory) {
        return "Ether Orcs Genesis";
    }

    function symbol() external pure returns (string memory) {
        return "Orcs";
    }


    /*///////////////////////////////////////////////////////////////
                    MINT FUNCTION
    //////////////////////////////////////////////////////////////*/

    function _mintOrc(uint256 rand) internal returns (uint16 id) {
        (uint8 body,uint8 helm,uint8 mainhand,uint8 offhand) = (0,0,0,0);

        {
            // Helpers to get Percentages
            uint256 sevenOnePct   = type(uint16).max / 100 * 71;
            uint256 eightyPct     = type(uint16).max / 100 * 80;
            uint256 nineFivePct   = type(uint16).max / 100 * 95;
            uint256 nineNinePct   = type(uint16).max / 100 * 99;
    
            id = uint16(oldSupply + minted++ + 1);
    
            // Getting Random traits
            uint16 randBody = uint16(_randomize(rand, "BODY", id));
                   body     = uint8(randBody > nineNinePct ? randBody % 3 + 25 : 
                              randBody > sevenOnePct  ? randBody % 12 + 13 : randBody % 13 + 1 );
    
            uint16 randHelm = uint16(_randomize(rand, "HELM", id));
                   helm     = uint8(randHelm < eightyPct ? 0 : randHelm % 4 + 5);
    
            uint16 randOffhand = uint16(_randomize(rand, "OFFHAND", id));
                   offhand     = uint8(randOffhand < eightyPct ? 0 : randOffhand % 4 + 5);
    
            uint16 randMainhand = uint16(_randomize(rand, "MAINHAND", id));
                   mainhand     = uint8(randMainhand < nineFivePct ? randMainhand % 4 + 1: randMainhand % 4 + 5);
        }

        _mint(msg.sender, id);

        uint16 zugModifier = _tier(helm) + _tier(mainhand) + _tier(offhand);
        orcs[uint256(id)] = Orc({body: body, helm: helm, mainhand: mainhand, offhand: offhand, level: 0, lvlProgress: 0, zugModifier:zugModifier});
    }

    /*///////////////////////////////////////////////////////////////
                    INTERNAL  HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @dev take an available item from a pool
    function _getItemFromPool(LootPool memory pool, uint256 rand) internal pure returns (LootPool memory, uint8 item) {
        uint draw = rand % pool.total--; 

        if (draw > pool.tier_1 + pool.tier_2 + pool.tier_3 && pool.tier_4-- > 0) {
            item = uint8((draw % 4 + 1) + (pool.minLootTier + 3) * 4);     
            return (pool, item);
        }

        if (draw > pool.tier_1 + pool.tier_2 && pool.tier_3-- > 0) {
            item = uint8((draw % 4 + 1) + (pool.minLootTier + 2) * 4);
            return (pool, item);
        }

        if (draw > pool.tier_1 && pool.tier_2-- > 0) {
            item = uint8((draw % 4 + 1) + (pool.minLootTier + 1) * 4);
            return (pool, item);
        }

        if (pool.tier_1-- > 0) {
            item = uint8((draw % 4 + 1) + pool.minLootTier * 4);
            return (pool, item);
        }
    }

    function claimableZug(uint256 timeDiff, uint16 zugModifier) internal pure returns (uint256 zugAmount) {
        zugAmount = timeDiff * (4 + zugModifier) * 1 ether / 1 days;
    }

    /// @dev Convert an id to its tier
    function _tier(uint16 id) internal pure returns (uint16) {
        if (id == 0) return 0;
        return ((id - 1) / 4 );
    }

    /// @dev Create a bit more of randomness
    function _randomize(uint256 rand, string memory val, uint256 spicy) internal pure returns (uint256) {
        return uint256(keccak256(abi.encode(rand, val, spicy)));
    }

    function _rand() internal view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(msg.sender, block.timestamp, block.basefee, block.timestamp, entropySauce)));
    }

    function _getMintingPrice() internal view returns (uint256) {
        uint256 supply = minted + oldSupply;
        if (supply < 4550) return 80 ether;
        return 175 ether;
    }
}