//SPDX-License-Identifier: Unlicense
pragma solidity ^0.7.0;

import "hardhat/console.sol";

// TODO: USE ZEPPLIN FOR ERC20 TOKEN
/*
OpenZeppelin Contracts features a stable API, which means your contracts won’t break unexpectedly when upgrading to a newer minor version.
*/
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/*
An ERC20 token contract keeps track of fungible tokens: any one token is exactly equal to any 
other token; no tokens have special rights or behavior associated with them. 
This makes ERC20 tokens useful for things like a medium of exchange currency, voting rights, staking, and more.

Fungible goods are equivalent and interchangeable, like Ether, fiat currencies, and voting rights.
Non-fungible goods are unique and distinct, like deeds of ownership, or collectibles.

when dealing with non-fungibles (like your house) you care about which ones you have, while in fungible assets 
(like your bank account statement) what matters is how much you have.
*/
contract Lottery is AccessControl {
  // space efficency, keep same types together for speeeed
  bytes32 public constant OWNER = keccak256("OWNER");
  bytes32 public constant MANAGER = keccak256("MANAGER");

  IERC20 public tokenERC20;

  address[] public players;

  uint256 public ticketPrice;
  uint256 public payoutBalance; // public creates getter
  uint256 public usageBalance;

  event WithdrawMoney(uint256 amount);
  event SendMoneyToWinner(address sender, address winner, uint256 amount);

  // SMART CONTRAACT HAS IT'S OWN ADDRESS - address(this)
  // each erc20 isa smart contract
  // so you have to call teh function of the erc20 smart contract
  /*
    IERC20
    Interface of the ERC20 standard as defined in the EIP.
  */
  constructor(
    uint256 price,
    address creator,
    address token
  ) public {
    _setupRole(OWNER, creator);
    ticketPrice = price; // means 10**18, assume we put in right value. if not do (* 10 ether)
    tokenERC20 = IERC20(token);
  }

  function getKeccak256Hash(string memory thing) public pure returns (bytes32) {
    // pure is like not accesinng var just returning? view is like modifying
    return keccak256(abi.encodePacked(thing));
  }

  function addManager(address manager) public {
    require(getRoleMemberCount(MANAGER) < 2, "You cannot add more than two managers."); // we extend accesscontrol soooooo

    _setupRole(MANAGER, manager);
  }

  // 18 digits for decimals, so we multiple price by 10^18
  // B/C we're not playing iwth eth, we dont need payable
  function buyTickets(uint256 numberOfTickets) public { // 
    // UM is this allowed lol?
    uint256 fullAmount = numberOfTickets * ticketPrice;

    payoutBalance += (fullAmount * 9500) / 10000;
    usageBalance += (fullAmount * 500) / 10000;

    tokenERC20.transferFrom(msg.sender, address(this), fullAmount);

    for (uint256 i = 0; i < numberOfTickets; i++) {
      players.push(msg.sender);
    }
  }

  function random(uint256 upperBound) private view returns (uint256) { // if I am returning a var, I can write the variable instead of type
    return uint256(keccak256(abi.encodePacked(block.timestamp))) % upperBound;
    // REDO: RANDOMIZER
    // oracle -> centralized comapnies that you trsut that wil call your contract and provie you data
  }

  // TODO: ADD MESAGES
  function withdraw() public {
    require(hasRole(OWNER, msg.sender), "You have to be a manager.");

    tokenERC20.transfer(msg.sender, usageBalance); // caller to someone else

    emit WithdrawMoney(usageBalance);

    usageBalance = 0;
  }

  function pickWinner() public {
    require(
      hasRole(OWNER, msg.sender) || hasRole(MANAGER, msg.sender),
      "You have to be an owner or manager."
    );

    uint256 index = random(players.length);
    address winner = players[index];
    tokenERC20.transfer(winner, payoutBalance);

    // TODO: emit an event
    emit SendMoneyToWinner(address(this), winner, payoutBalance);

    delete players;
    payoutBalance = 0;
  }

  function getPlayers() public view returns (address[] memory) { 
    return players;
  }
}