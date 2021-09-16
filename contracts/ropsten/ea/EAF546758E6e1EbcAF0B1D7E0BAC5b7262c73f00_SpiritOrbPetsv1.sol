// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract SpiritOrbPetsv1 is ERC721Enumerable, Ownable {

    string _baseTokenURI;
    uint256 private _price = 0.07 ether;
    bool public _paused = false;
    address public CARE_TOKEN_ADDRESS = address(0);

    // Maximum amount of Pets in existance.
    uint256 public constant MAX_PET_SUPPLY = 7777;
    uint8 public constant MAX_PET_LEVEL = 30;

    // Events
    event Minted(address sender, uint256 numberOfPets);
    event Activated(address sender, uint16 id);
    event Deactivated(address sender, uint16 id);
    event PlayedWithPet(address sender, uint16 id);
    event FedPet(address sender, uint16 id, uint _careTokensToPay, bool levelDownEventOccurred);
    event CleanedPet(address sender,uint16 id, bool levelDownEventOccurred);
    event TrainedPet(address sender, uint16 id);
    event SentToDaycare(address sender, uint16 id, uint _weeksToPayFor);

    struct Pet {
      uint16 id; // max possible is 65535, but will only to go 7777
      uint8 level; // max possble is 255, but will only go to 30
      bool active;
      uint64 cdPlay; // in case people want to play past 2038?
      uint64 cdFeed; // sorry humans of year 2,147,485,547 AD...
      uint64 cdClean;
      uint64 cdTrain;
      uint64 cdDaycare;
    }

    Pet[7777] public pets;

    constructor() ERC721("Spirit Orb Pets v1", "SOPV1") {
      _paused = false;
    }

    function createPet(uint16 _id) internal {
      pets[_id] = Pet(_id, 1, false, 0, 0, 0, 0, 0);
    }

    /**
    * @dev Mints [numberOfPets] Pets
    */
    function mintPet(uint256 numberOfPets) public payable {
      uint256 supply = totalSupply();
      require(!_paused, "Pet adoption has not yet begun.");
      require(supply < MAX_PET_SUPPLY, "Adoption has already ended.");
      require(numberOfPets > 0, "You cannot adopt 0 Pets.");
      require(numberOfPets <= 7, "You are not allowed to adopt this many Pets at once.");
      require(supply + numberOfPets <= MAX_PET_SUPPLY, "Exceeds maximum Pets available. Please try to adopt less Pets.");
      require(_price * numberOfPets == msg.value, "Amount of Ether sent is not correct.");

      // Mint the amount of provided Pets.
      for (uint i = 0; i < numberOfPets; i++) {
          _safeMint(msg.sender, supply + i);
          createPet(uint16(supply + i));
      }

      emit Minted(msg.sender, numberOfPets);
    }

    function walletOfOwner(address _owner) public view returns(uint256[] memory) {
      uint256 tokenCount = balanceOf(_owner);

      uint256[] memory tokensId = new uint256[](tokenCount);
      for(uint256 i; i < tokenCount; i++){
          tokensId[i] = tokenOfOwnerByIndex(_owner, i);
      }
      return tokensId;
    }

    // If everything is minted this will be irrelevant.
    // This is only in case ETH decides to do a x10 before minting or
    // something crazy like that. Would only do this if the community
    // agreed as well.
    function setPrice(uint256 _newPrice) public onlyOwner {
      _price = _newPrice;
    }

    function _baseURI() internal view virtual override returns (string memory) {
      return _baseTokenURI;
    }

    function setBaseURI(string memory baseURI) public onlyOwner {
      _baseTokenURI = baseURI;
    }

    function getPrice() public view returns (uint256){
      return _price;
    }

    function setPause(bool val) public onlyOwner {
      _paused = val;
    }

    function withdraw() external onlyOwner {
      uint balance = address(this).balance;
      payable(msg.sender).transfer(balance);
    }

    /**
    * @dev Reserves the first 50 pets for giveaways and for those you helped the project
    */
    function reserveGiveaway() public onlyOwner {
      uint currentSupply = totalSupply();
      require(currentSupply < 50, "Already reserved the first pets.");
      // Reserved for people who helped this project and giveaways
      for (uint i = 0; i < 50; i++) {
          _safeMint(owner(), currentSupply + i);
          createPet(uint16(currentSupply + i));
      }
    }

    /**
    * @dev Returns a list of tokens that are owned by _owner.
    * @dev NEVER call this function inside of the smart contract itself
    * @dev because it is expensive.  Only return this from web3 calls
    */
    function tokensOfOwner(address _owner) external view returns(uint256[] memory) {
      uint256 tokenCount = balanceOf(_owner);

      if (tokenCount == 0) {
        return new uint256[](0);
      } else {
        uint256[] memory result = new uint256[](tokenCount);
        uint256 totalPets = totalSupply();
        uint256 resultIndex = 0;

        for (uint256 petId = 0; petId <= totalPets - 1; petId++) {
          if (ownerOf(petId) == _owner) {
            result[resultIndex] = petId;
            resultIndex++;
          }
        }

        return result;
      }
    }

    /** @dev Overrides ERC721's _beforeTokenTransfer so we can deactivate the pet in case of transfer to
    *  @dev another owner.  Ignores this on mint and burn
    */
    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal virtual override {
      if (from != address(0) && to != address(0)) {
        deactivatePet(uint16(tokenId));
      }
      super._beforeTokenTransfer(from, to, tokenId);
    }

    modifier notAtDaycare(uint16 _id) {
      require(pets[_id].cdDaycare <= block.timestamp, "Cannot perform action while pet is at daycare.");
      _;
    }

    function activatePet(uint16 _id) external {
      require(!_paused, "Pet adoption has not yet begun.");
      require(ownerOf(_id) == msg.sender);
      require(!pets[_id].active, "Pet is already active!");

      pets[_id].active = true;
      if (pets[_id].cdPlay == 0) pets[_id].cdPlay = uint64(block.timestamp);
      pets[_id].cdFeed = uint64(block.timestamp + 1 hours);
      pets[_id].cdClean = uint64(block.timestamp + 3 days - 1 hours);
      pets[_id].cdTrain = uint64(block.timestamp + 23 hours);

      emit Activated(msg.sender, _id);
    }

    /**
    * @dev Deactivating the pet will reduce the level to 1 unless they are at max level
    * @dev This is the only way to take a pet out of daycare as well before the time expires
    */
    function deactivatePet(uint16 _id) public {
      require(ownerOf(_id) == msg.sender);
      require(pets[_id].active, "Pet is not active yet.");

      if (pets[_id].active) {
        pets[_id].active = false;
        if (pets[_id].cdDaycare > uint64(block.timestamp)) {
          pets[_id].cdDaycare = 0;
          pets[_id].cdPlay = uint64(block.timestamp);
          // everything else is reset during reactivation
        }
        if (pets[_id].level < MAX_PET_LEVEL) {
          pets[_id].level = 1;
        }
      }

      emit Deactivated(msg.sender, _id);
    }

    function levelDown(uint16 _id) internal {
      if (pets[_id].level > 1 && pets[_id].level != 30) {
        pets[_id].level = pets[_id].level - 1;
      }
    }

    function levelUp(uint16 _id) internal {
      if (pets[_id].level < MAX_PET_LEVEL) {
        pets[_id].level = pets[_id].level + 1;
      }
    }

    /**
    * @dev Playing with your pet is the primary way to earn CARE tokens.
    */
    function playWithPet(uint16 _id) external {
      require(ownerOf(_id) == msg.sender, "Only the owner of the pet can play with it!");
      require(pets[_id].active, "Pet needs to be active to receive CARE tokens.");
      require(pets[_id].cdFeed >= uint64(block.timestamp), "Pet is too hungry to play.");
      require(pets[_id].cdClean >= uint64(block.timestamp), "Pet is too dirty to play.");
      require(pets[_id].cdPlay <= uint64(block.timestamp), "You can only redeem CARE tokens every 23 hours.");

      // send CARE tokens to owner
      require(CARE_TOKEN_ADDRESS != address(0), "CARE token variable not set.");
      require(ERC20(CARE_TOKEN_ADDRESS).balanceOf(address(this)) >= 10 * 10 ** 18, "Contract does not have enough tokens to send.");

      ERC20(CARE_TOKEN_ADDRESS).transfer(msg.sender, 10 * 10 ** 18);

      // set new time for playing with pet
      pets[_id].cdPlay = uint64(block.timestamp + 23 hours);

      emit PlayedWithPet(msg.sender, _id);
    }

    /**
    * @dev Sets the cdFeed timer when you activate it.  You MUST call approve on the
    * @dev ERC20 token AS the user before interacting with this function or it will not
    * @dev work. Pet will level down if you took too long to feed it.
    */
    function feedPet(uint16 _id, uint _careTokensToPay) external notAtDaycare(_id) {
      require(ownerOf(_id) == msg.sender, "Only the owner of the pet can feed it!");
      require(pets[_id].active, "Pet needs to be active to feed pet.");
      require(pets[_id].cdClean >= uint64(block.timestamp), "Pet is too dirty to eat.");
      require(_careTokensToPay <= 9, "You should not overfeed your pet.");
      require(_careTokensToPay >= 3, "Too little CARE sent to feed pet.");
      // We could check to see if it's too soon to feed the pet, but it would become more expensive in gas
      // And we can otherwise control this from the front end
      // Plus players can top their pet's feeding meter whenever they want this way

      // take CARE tokens from owner
      uint paymentAmount = _careTokensToPay * 10 ** 18;
      // Token must be approved from the CARE token's address by the owner
      ERC20(CARE_TOKEN_ADDRESS).transferFrom(msg.sender, address(this), paymentAmount);

      // check if the pet was fed on time, if not, level down
      bool levelDownEventOccurred = false;
      if (pets[_id].cdFeed <= uint64(block.timestamp)) {
        levelDown(_id);
        levelDownEventOccurred = true;
      }

      // set new time for feeding pet
      // if pet isn't starving yet, just add the time, otherwise set the time to now + 8hrs * tokens
      if (pets[_id].cdFeed > uint64(block.timestamp)) {
        pets[_id].cdFeed = pets[_id].cdFeed + uint64(_careTokensToPay * 8 hours);
        // Pet cannot be full for more than 3 days max
        if (pets[_id].cdFeed > uint64(block.timestamp + 3 days)) {
          pets[_id].cdFeed = uint64(block.timestamp + 3 days);
        }
      } else {
        pets[_id].cdFeed = uint64(block.timestamp + (_careTokensToPay * 8 hours)); //3 tokens per 24hrs up to 72hrs
      }

      emit FedPet(msg.sender, _id, _careTokensToPay, levelDownEventOccurred);
    }

    /**
    * @dev Cleaning your pet is a secondary way to earn CARE tokens.  If you don't clean
    * @dev your pet in time (24hrs after it reaches the timer) your pet will level down.
    */
    function cleanPet(uint16 _id) external {
      require(ownerOf(_id) == msg.sender, "Only the owner of the pet can clean it!");
      require(pets[_id].active, "Pet needs to be active to feed pet.");
      require(pets[_id].cdClean <= uint64(block.timestamp), "Pet is not dirty yet.");

      // send CARE tokens to owner
      require(CARE_TOKEN_ADDRESS != address(0), "CARE token variable not set.");
      if (ERC20(CARE_TOKEN_ADDRESS).balanceOf(address(this)) >= 10 * 10 ** 18) {
        // Don't require here because this is a necessary function for leveling
        ERC20(CARE_TOKEN_ADDRESS).transfer(msg.sender, 10 * 10 ** 18);
      }

      // check if the pet was cleaned on time, if not, level down
      bool levelDownEventOccurred = false;
      if ((pets[_id].cdClean + 1 days) <= uint64(block.timestamp)) {
        levelDown(_id);
        levelDownEventOccurred = true;
      }

      pets[_id].cdClean = uint64(block.timestamp + 3 days - 1 hours); // 3 tokens per 24hrs up to 72hrs
      emit CleanedPet(msg.sender, _id, levelDownEventOccurred);
    }

    /**
    * @dev Training your pet is the only way to level it up.  You can do it once per
    * @dev day, 23 hours after activating it.
    */
    function trainPet(uint16 _id) external notAtDaycare(_id) {
      require(ownerOf(_id) == msg.sender, "Only the owner of the pet can train it!");
      require(pets[_id].active, "Pet needs to be active to train pet.");
      require(pets[_id].cdFeed >= uint64(block.timestamp), "Pet is too hungry to train.");
      require(pets[_id].cdClean >= uint64(block.timestamp), "Pet is too dirty to train.");
      require(pets[_id].cdTrain <= uint64(block.timestamp), "Pet is too tired to train.");

      if (pets[_id].level < 30) {
        levelUp(_id);
      } else {
        // send CARE tokens to owner
        require(CARE_TOKEN_ADDRESS != address(0), "CARE token variable not set.");
        if (ERC20(CARE_TOKEN_ADDRESS).balanceOf(address(this)) >= 10 * 10 ** 18) {
          // Don't require here because this is a necessary function for leveling
          ERC20(CARE_TOKEN_ADDRESS).transfer(msg.sender, 10 * 10 ** 18);
        }
      }

      pets[_id].cdTrain = uint64(block.timestamp + (23 hours));
      emit TrainedPet(msg.sender, _id);
    }

    /**
    * @dev Sending your pet to daycare is intended to freeze your pets status if you
    * @dev plan to be away from it for a while. The only way to unfreeze them is to
    * @dev wait the duration or deactivate and thus level down your pet.  Use with caution!
    * @dev There is no refund for deactivation and you can extend your stay by directly
    * @dev interacting with the contract. Note that it won't extend the stay, just set it
    * @dev to a new value.
    */
    function sendToDaycare(uint16 _id, uint _weeksToPayFor) external notAtDaycare(_id) {
      require(ownerOf(_id) == msg.sender, "Only the owner of the pet send it to daycare!");
      require(pets[_id].active, "Pet needs to be active to send it to daycare.");
      require(_weeksToPayFor >= 1, "Minimum 1 week of daycare required.");
      require(_weeksToPayFor <= 5, "You cannot send pet to daycare for that long.");

      // take CARE tokens from owner
      // each week is 50 whole CARE tokens
      uint paymentAmount = _weeksToPayFor * 50 * 10 ** 18;
      // Token must be approved from the CARE token's address by the owner
      ERC20(CARE_TOKEN_ADDRESS).transferFrom(msg.sender, address(this), paymentAmount);

      // calculate how many weeks to send pet to daycare
      uint timeToSendPet = _weeksToPayFor * 7 days;

      // set timer for daycare and caretaking activities
      uint64 timeToSetCareCooldowns = uint64(block.timestamp + timeToSendPet);
      pets[_id].cdDaycare = timeToSetCareCooldowns;
      pets[_id].cdPlay = timeToSetCareCooldowns;
      pets[_id].cdFeed = timeToSetCareCooldowns + 3 days;
      pets[_id].cdClean = timeToSetCareCooldowns + 3 days - 1 hours;
      pets[_id].cdTrain = timeToSetCareCooldowns;

      emit SentToDaycare(msg.sender, _id, _weeksToPayFor);
    }

    /**
    * @dev sets the CARE token address.  Can only be set once!
    */
    function setCareTokenAddress(address _careTokenAddress) external onlyOwner {
      require(CARE_TOKEN_ADDRESS == address(0), "Can only set this once!");
      CARE_TOKEN_ADDRESS = _careTokenAddress;
    }

    function getCareTokensHeldByContract() external view returns(uint256) {
      return ERC20(CARE_TOKEN_ADDRESS).balanceOf(address(this));
    }

    // vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
    // CHEAT SECTION -- THIS WILL NOT BE IN THE FINAL CONTRACT
    // FOR TESTING PURPOSES ONLY!
    // vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv


    function cheatSetLevel(uint16 _id, uint8 _level) external onlyOwner {
      pets[_id].level = _level;
    }

    /**
    * @dev test function so you can test reaching level down states and
    * @dev reseting daycare, playing (for CARE collecting), and cleaning states
    */
    function cheatResetCDTimer(uint16 _id, uint256 _daysOver) external onlyOwner {
      pets[_id].cdTrain = uint64(block.timestamp - _daysOver * 1 days);
      pets[_id].cdClean = uint64(block.timestamp - _daysOver * 1 days);
      pets[_id].cdFeed = uint64(block.timestamp - _daysOver * 1 days);
      pets[_id].cdPlay = uint64(block.timestamp - _daysOver * 1 days);
      pets[_id].cdDaycare = uint64(block.timestamp - _daysOver * 1 days);
    }

}