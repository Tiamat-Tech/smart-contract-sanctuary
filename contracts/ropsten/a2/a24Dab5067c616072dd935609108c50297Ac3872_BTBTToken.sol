// SPDX-License-Identifier: MIT
// Author: BITBIT Financial Team
pragma solidity >= 0.8.0;

import "../openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "../openzeppelin-contracts/contracts/access/Ownable.sol";
import "../openzeppelin-contracts/contracts/utils/math/SafeMath.sol";
import "./interfaces/IBTBTStakingContract.sol";

contract BTBTToken is ERC20, Ownable {
  using SafeMath for uint256;

  mapping (address => bool) private isMinter;
  bool private isInitialized = false;

  IBTBTStakingContract private stakingContract;
  address private stakingConAddr;


  modifier onlyMinter {
    require(isMinter[msg.sender]);
    _;
  }

  /**
  *  ERC20 name of the token
  *  ERC20 symbol (ticker) of the token
  */
  constructor()
  ERC20("BTBT Token", "BTBT")
  {
    isMinter[msg.sender] = true;
  }

  /**
  * Initialize the the dedicated minters and reference to the BTBT staking contract 
  *
  * @param _minterAddresses: list of addresses to receive minter roles
  * @param _stakingContractAddr: address of the staking contract, needs to support IStakingContract
  */
  function init(
    address[] calldata _minterAddresses,
    address _stakingContractAddr
  )
  external
  onlyOwner
  {
    require(_stakingContractAddr != address(0), "Staking contract cannot be zero address");
    require(!isInitialized, "Minters are already set");
    require(_minterAddresses.length > 0, "Trying to initialize with no minters");
    
    for (uint8 i=0; i<_minterAddresses.length; i++) {
      require(_minterAddresses[i]  != address(0), "BTBTToken: Trying to init with a zero address minter");
      isMinter[_minterAddresses[i]] = true;
    }
    stakingContract = IBTBTStakingContract(_stakingContractAddr);
    isInitialized = true;
    stakingConAddr = _stakingContractAddr;
  }

  /**
  * Minting wrapper for the privileged role
  */
  function mint(address _account, uint256 _amount) public onlyMinter {
    require(_account != address(0), "BTBTToken: Trying to mint to zero address");
    require(_amount > 0, "BTBTToken: Trying to mint zero tokens");
    _mint(_account, _amount);
  }

  /**
  * Total supply that includes "virtual" tokens which will be minted by staking, to date
  */
  function totalSupplyVirtual() public view returns (uint256) {
    return totalSupply().add(stakingContract.totalUnmintedInterest());
  }

  function getStAddress() public view returns(address ret) {
    return stakingConAddr;
  }
}