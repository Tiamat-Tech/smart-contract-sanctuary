// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import "./StakeableDailyReward.sol";

contract StakingV1 is ERC20Pausable, AccessControl, StakeableDailyReward {

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    constructor()  ERC20("StakingV1 Token", "StakingV1") {
        _setupRole(MINTER_ROLE,  msg.sender);
        _setupRole(BURNER_ROLE,  msg.sender);
        _setupRole(PAUSER_ROLE,  msg.sender);
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender); 
    }

    function decimals() public view virtual override returns (uint8) {
        return 8;
    }

    function mint(address to, uint256 amount) public {
        require(hasRole(MINTER_ROLE, msg.sender), "Caller is not a minter");
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) public {
        require(hasRole(BURNER_ROLE, msg.sender), "Caller is not a burner");
        _burn(from, amount);
    }

    function pause() public {
        require(hasRole(PAUSER_ROLE, msg.sender), "Caller is not a pauser");
        _pause();
    }

    function unpause() public {
        require(hasRole(PAUSER_ROLE, msg.sender), "Caller is not a pauser");
        _unpause();
    }

    
    /**
    * Add functionality like burn to the _stake afunction
    *
     */
    function stake(uint256 _amount) public {
      // Make sure staker actually is good for it
      require(_amount <= balanceOf(msg.sender), "Cannot stake more than you own");

        _stake(_amount);
                // Burn the amount of tokens on the sender
        _burn(msg.sender, _amount);
    }

    /**
    * @notice withdrawStake is used to withdraw stakes from the account holder
     */
    function withdrawStake(uint256 amount, uint256 stake_index)  public {

        require(!paused(), "ERC20Pausable: token transfer while paused");

      uint256 amount_to_mint = _withdrawStake(amount, stake_index);
      // Return staked tokens to user
      _mint(msg.sender, amount_to_mint);
    }
    

    function withdrawAllStakes() public {

        require(!paused(), "ERC20Pausable: token transfer while paused");

         // Grab user_index which is the index to use to grab the Stake[]
        uint256 user_index = stakes[msg.sender]; 
        uint256 amount_to_mint = 0;
        StakingSummary memory summary = hasStake(msg.sender);
 
        require( summary.total_amount > 0 , "No current stake");

        Stake[] memory current_stakes = stakeholders[user_index].address_stakes;

        for (uint256 s = 0; s < current_stakes.length; s += 1){ 
           amount_to_mint +=  _withdrawStake(current_stakes[s].amount, s); 
       } 

      // Return staked tokens to user
      _mint(msg.sender, amount_to_mint);

    }



}