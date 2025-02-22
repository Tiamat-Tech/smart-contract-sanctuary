// SPDX-License-Identifier: MIT
// Votium Address Registry

pragma solidity ^0.8.0;

import "./Ownable.sol";

contract AddressRegistry is Ownable {
  struct Registry {
    uint256 start;      // when first registering, there is a delay until the next vlCVX voting epoch starts
    address to;         // forward rewards to alternate address OR 0x0 address for OPT OUT of rewards
    uint256 expiration; // when ending an active registration, expiration is set to the next vlCVX voting epoch
												// an active registration cannot be changed until after it is expired (one vote round delay when changing active registration)
  }
  mapping(address => Registry) public registry;

  mapping(address => bool) public inOptOutHistory;
  address[] public optOutHistory;

  // to start, we won't allow address forwarding, only opt-out of all rewards
  bool optOutOnly = true;

  // address changes do not take effect until the next vote starts
  uint256 public constant eDuration = 86400 * 14;

  // team can enable address forwarding once off-chain logic is ready
  // once enabled it cannot be disabled
  function enableForwards() external onlyOwner {
    optOutOnly = false;
  }

  // Set forwarding address or OPT OUT of rewards by setting to 0x0 address
  // Registration is active until setToExpire() is called, and then remains active until the next reward period
  function setRegistry(address _to) public {
    if(optOutOnly) { require(_to == address(0),"Forwarding not yet enabled"); }
    uint256 current = currentEpoch();
    require(registry[msg.sender].start == 0 || registry[msg.sender].expiration < current,"Registration is still active");
    registry[msg.sender].start = current+eDuration;
    registry[msg.sender].to = _to;
    registry[msg.sender].expiration = 0xfffffffff;
    if(_to == address(0)) {
      // prevent duplicate entry in optOutHistory array
      if(!inOptOutHistory[msg.sender]) {
        optOutHistory.push(msg.sender);
				inOptOutHistory[msg.sender] = true;
      }
    }
		emit setReg(msg.sender, _to, registry[msg.sender].start);
  }

  // Sets a registration to expire on the following epoch (cannot change registration during an epoch)
  function setToExpire() public {
    uint256 next = nextEpoch();
    require(registry[msg.sender].start > 0 && registry[msg.sender].expiration > next,"Not registered or expiration already pending");
    // if not started yet, nullify instead of setting expiration
    if(next == registry[msg.sender].start) {
      registry[msg.sender].start = 0;
      registry[msg.sender].to = address(0);
    } else {
      registry[msg.sender].expiration = next;
    }
		emit expReg(msg.sender, next);
  }

  // supply an array of addresses, returns their destination (same address for no change, 0x0 for opt-out, different address for forwarding)
  function batchAddressCheck(address[] memory accounts) external view returns (address[] memory) {
    uint256 current = currentEpoch();
    for(uint256 i=0; i<accounts.length; i++) {
      // if registration active return "to", otherwise return checked address (no forwarding)
      if(registry[accounts[i]].start <= current && registry[accounts[i]].start != 0 && registry[accounts[i]].expiration > current) {
        accounts[i] = registry[accounts[i]].to;
      }
    }
    return accounts;
  }

	// length of optOutHistory - needed for retrieving paginated results from optOutPage()
  function optOutLength() public view returns (uint256) {
    return optOutHistory.length;
  }

	// returns list of actively opted-out addresses using pagination 
	function optOutPage(uint256 size, uint256 page) public view returns (address[] memory) {
		page = size*page;
		uint256 current = currentEpoch();
		uint256 n = 0;
		for(uint256 i=page; i<optOutHistory.length; i++) {
			if(registry[optOutHistory[i]].start <= current && registry[optOutHistory[i]].expiration > current && registry[optOutHistory[i]].to == address(0)) {
				n++;
				if(n == size) { break; }
			}
		}
		address[] memory optOuts = new address[](n);
		n = 0;
		for(uint256 i=page; i<optOutHistory.length; i++) {
			if(registry[optOutHistory[i]].start <= current && registry[optOutHistory[i]].expiration > current && registry[optOutHistory[i]].to == address(0)) {
				optOuts[n] = optOutHistory[i];
				n++;
				if(n == size) { break; }
			}
		}
		return optOuts;
	}

  // returns start of current Epoch
  function currentEpoch() public view returns (uint256) {
    return block.timestamp/eDuration*eDuration;
  }

  // returns start of next Epoch
  function nextEpoch() public view returns (uint256) {
    return block.timestamp/eDuration*eDuration+eDuration;
  }

  // only used for rescuing mistakenly sent funds or other unexpected needs
  function execute(address _to, uint256 _value, bytes calldata _data) external onlyOwner returns (bool, bytes memory) {
    (bool success, bytes memory result) = _to.call{value:_value}(_data);
    return (success, result);
  }

	event setReg(address indexed _from, address indexed _to, uint256 indexed _start);
	event expReg(address indexed _from, uint256 indexed _end);

}