// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import "../interfaces/ERC165Spec.sol";
import "../interfaces/ERC20Spec.sol";
import "../utils/AccessControl.sol";

/**
 * @title Artificial Liquid Intelligence ERC20 Token (ALI) vesting
 * 
 * @notice Allows to release 10% grant immediately after vesting period starts,
 *          release 90% grant devided by total vesting months on mnthly basis 
 */
contract AliVesting is AccessControl {

    // Grant struct to hold granted and claimed amount data for recipient
    struct Grant {
        uint256 amount;
        uint256 totalClaimed;
    }

    /**
	 * @dev Fired in addTokenGrant()
	 *
	 * @param recipient an address of the recipient
	 * @param grantedAmount amount of token grant added to the recipient
	 */
    event GrantAdded(address indexed recipient, uint256 grantedAmount);
    
    /**
	 * @dev Fired in revokeTokenGrant()
	 *
	 * @param recipient an address of the recipient to whom grant is revoked
	 * @param amountVested amount of token vested by recipient till the grant is revoked
     * @param amountNotVested amount of token not vested by recipient till the grant is revoked
	 */
    event GrantRevoked(address indexed recipient, uint256 amountVested, uint256 amountNotVested);

    /**
	 * @dev Fired in release()
	 *
	 * @param recipient an address of the recipient
	 * @param amount token amount released to the recipient
	 */
    event Released(address indexed recipient, uint256 amount);

    /**
	 * @dev ALI ERC20 contract address to transfer tokens
	 */
    address public immutable aliContract;

    /**
	 * @dev Total number of seconds of 30 days month
	 */
    uint32 private constant SECONDS_PER_MONTH = 30 minutes ;//days; TEST Changes

    /**
	 * @dev Starting time from when vesting will begin
	 */
    uint32 public immutable startTimestamp;
    
    /**
	 * @notice Allows release of the tokens publicly for recipients
	 *
	 * @dev When `FEATURE_RELEASE` is enabled, recipient can release unclaimed tokens
	 */
    uint32 public constant FEATURE_RELEASE = 0x0000_0001;

    /**
	 * @notice Grant manager is responsible for adding and revoking token grants
	 *
	 * @dev Role ROLE_GRANT_MANAGER allows add/revoke token grant via addTokenGrant()/revokeTokenGrant function
	 */
    uint32 public constant ROLE_GRANT_MANAGER = 0x0001_0000;

    /**
	 * @dev Duration in months of the cliff in which tokens will begin to vest
	 */
    uint8 public immutable cliffInMonths;

    /**
	 * @dev Total vesting duration in months
	 */
    uint8 public immutable vestingDurationInMonths;

    /**
	 * @dev Mapping from recipient to `Grant` data
	 */
    mapping (address => Grant) public tokenGrants;

    /**
	 * @dev Creates/deploys AliVesting
	 *
	 * @param _ali deployed ALI ERC20 smart contract address
	 * @param _startTimestamp starting time from when vesting will begin  
	 * @param _cliffInMonths duration in months of the cliff in which tokens will begin to vest
	 * @param _vestingDurationInMonths total vesting duration in months 
	 */
    constructor(
        address _ali,
        uint32 _startTimestamp,
        uint8 _cliffInMonths,
        uint8 _vestingDurationInMonths
    ) {
		// verify inputs are set
		require(_ali != address(0), "ALI Token addr is not set");

		// verify inputs are valid smart contracts of the expected interfaces
		require(ERC165(_ali).supportsInterface(type(ERC20).interfaceId), "unexpected ALI Token type");
		
		// setup smart contract internal state
		aliContract = _ali;
		
        cliffInMonths = _cliffInMonths;

        vestingDurationInMonths = _vestingDurationInMonths;

        startTimestamp = _startTimestamp == 0 ? blockTimestamp() : _startTimestamp;

	}

    /**
	 * @dev Adds token grant to given recipient 
	 *
	 * @param _recipient address of the recipient 
	 * @param _amount token amount to be granted  
	 */
    function addTokenGrant(
        address _recipient,
        uint256 _amount    
    ) 
        external
    {
        require(isSenderInRole(ROLE_GRANT_MANAGER), "Access denied");

        require(tokenGrants[_recipient].amount == 0, "Grant already exists");
        
        // Calculate monthly vesting amount
        uint256 amountVestedPerMonth = (_amount * 9) / (vestingDurationInMonths * 10);

        require(amountVestedPerMonth > 0, "Amount not enough");

        // Transfer the grant tokens under the control of the vesting contract
        ERC20(aliContract).transferFrom(msg.sender, address(this), _amount);

        // Bind data to `Grant`
        Grant memory grant = Grant({
            amount: _amount,
            totalClaimed: 0
        });

        // Record `Grant` data for given recipient
        tokenGrants[_recipient] = grant;
        
        // Emits an event
        emit GrantAdded(_recipient, _amount);
    }

    /**
	 * @dev Revokes token grant from given recipient 
	 *
	 * @param _recipient address of the recipient to whom grant is revoked 
	 */
    function revokeTokenGrant(address _recipient) 
        external
    {
        require(isSenderInRole(ROLE_GRANT_MANAGER), "Access denied");

        // Calculate vested amount
        uint256 vested = vestedAmount(_recipient);

        // Calculated non vested amount
        uint256 notVested = tokenGrants[_recipient].amount - vested;

        // Calculate unclaimed amount from vested amount
        uint256 unclaimed = vested - tokenGrants[_recipient].totalClaimed;

        // Transfer non vested tokens to grant manager
        ERC20(aliContract).transfer(msg.sender, notVested);

        // Transfer unclaimed tokens to recipient
        ERC20(aliContract).transfer(_recipient, unclaimed);

        // Delete data to `Grant`
        Grant memory grant = Grant({
            amount: 0,
            totalClaimed: 0
        });

        // Record `Grant` data for given recipient
        tokenGrants[_recipient] = grant;

        // Emits an event
        emit GrantRevoked(_recipient, vested, notVested);

    }

    /**
	 * @dev Releases unclaimed tokens to recipient  
	 *
	 * @param _recipient address of the recipient 
	 */
    function release(address _recipient) external {
        
        require(isFeatureEnabled(FEATURE_RELEASE), "Release is disabled");

        // Calculate vested amount
        uint256 vested = vestedAmount(_recipient);

        // Calculate unclaimed amount
        uint256 unclaimed = vested - tokenGrants[_recipient].totalClaimed; 
        
        require(unclaimed > 0, "No tokens to release");

        // Add unclaimed amount to total claimed amount
        tokenGrants[_recipient].totalClaimed = tokenGrants[_recipient].totalClaimed + unclaimed;
        
        // Transfer unclaimed tokens to recipient
        ERC20(aliContract).transfer(_recipient, unclaimed);

        // Emits an event
        emit Released(_recipient, unclaimed);
    }

    /**
     * @dev Calculates the amount that has already vested for given recipient
     *
     * @param _recipient address of the recipient
     */
    function vestedAmount(address _recipient) public view returns (uint256) {
        
        // Check if vesting period started
        if (blockTimestamp() < startTimestamp) {
            return 0;
        }

        // Calculate elapsed time in seconds
        uint32 elapsedTime = blockTimestamp() - startTimestamp;
        
        // Calculate elapsed time in months
        uint32 elapsedMonths = elapsedTime / SECONDS_PER_MONTH;

        // Put thresold to elapsed months to stop vesting calculation after total vesting duartion is over
        elapsedMonths = (elapsedMonths > vestingDurationInMonths) ? vestingDurationInMonths : elapsedMonths; 

        // Check if cliff reached
        if (elapsedMonths < cliffInMonths) {
            
            return tokenGrants[_recipient].amount / 10;

        } else {
            
            uint256 vested = tokenGrants[_recipient].amount * (1 + ((9 * elapsedMonths) / vestingDurationInMonths)) / 10; 
            
            return vested;

        }

    }

    /**
     * @dev Returns current block timestamp
     */
    function blockTimestamp() public view virtual returns (uint32) {
        return uint32(block.timestamp);
    }

    /**
     * @dev Returns unclaimed amount for given recipient
     */
    function unclaimedAmount(address _recipient) public view returns (uint256) {
        return (vestedAmount(_recipient) - tokenGrants[_recipient].totalClaimed); 
    }

}