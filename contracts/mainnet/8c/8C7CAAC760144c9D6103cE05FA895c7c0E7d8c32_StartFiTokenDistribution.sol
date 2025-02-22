// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity 0.8.7;

import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./interface/IERC20.sol";

/**
 * @author Eman Herawy, StartFi Team
 *@title StartFiTokenDistribution
 * 
 */
contract StartFiTokenDistribution is  Ownable ,Pausable,ReentrancyGuard {
  
  /******************************************* decalrations go here ********************************************************* */
	
		address[8] public  tokenOwners =[0xAA4e7Ab6dccc1b673036B6FF78fe8af3402801c6,
			 0x438A078871C6e24663381CDcC7E85C42a0BD5a92,
			 0x0140d69F99531C10Da3094b5E5Ca758FA0F31579,
			 0x5deBAB9052E18f9E54eCECdD93Ee713d0ED64CBd,
			 0x907CB9388f6C78D1179b82A2F6Cc2aB4Ef1534E7,
			 0xcDC0b435861d452a0165dD939a8a31932055B08B,
			 0x492eC1E39724Dfc7F4d2b42083BCeb339eBaf18f,
			 0x801b877ECD8ef397F8560CbFAABd1C910BC8230E]; /* Tracks distributions mapping (iterable) */ 
	uint256 public TGEDate = 0; /* Date From where the distribution starts (TGE) */  
	
	mapping(address => DistributionStep[]) private _distributions; /* Distribution object */
	
	address public erc20;

	struct DistributionStep {
		uint256 amountAllocated;
 		uint256 unlockTime;
		bool sent;
	}

// events 




 /******************************************* constructor goes here ********************************************************* */

 	constructor(address _erc20, uint256 _time,address _owner){
			require(_erc20!=address(0)&& _owner!=address(0),"Zero addresses are not allowed");

		erc20=_erc20;
		TGEDate =	_time<block.timestamp?block.timestamp:_time;
		transferOwnership(_owner);
			uint256  month = 30 days;
	uint256  year = 365 days;

			address seedAccount =tokenOwners[0];
			address privateSaleAccount =tokenOwners[1];
			address treasuryFundAccount =tokenOwners[2];
			address liquidityAccount =tokenOwners[3];
			address communityPartnerAccount =tokenOwners[4];
			address rewardAccount =tokenOwners[5];
			address teamAccount =tokenOwners[6];
			address advisorAccount =tokenOwners[7];

/* Seed */

_setInitialDistribution(seedAccount, 1500000, 0 /* No Lock */);
_setInitialDistribution(seedAccount, 850000, 3 * month); /* After 3 Month */
_setInitialDistribution(seedAccount, 850000, 4 * month); /* After 4 Months */
_setInitialDistribution(seedAccount, 850000, 5 * month); /* After 5 Months */
_setInitialDistribution(seedAccount, 850000, 6 * month); /* After 6 Months */
_setInitialDistribution(seedAccount, 850000, 7 * month); /* After 7 Months */
_setInitialDistribution(seedAccount, 850000, 8 * month); /* After 8 Months */
_setInitialDistribution(seedAccount, 850000, 9 * month); /* After 9 Months */
_setInitialDistribution(seedAccount, 850000, 10 * month); /* After 10 Months */
_setInitialDistribution(seedAccount, 850000, 11 * month); /* After 11 Months */
_setInitialDistribution(seedAccount, 850000, 12 * month); /* After 12 Months */

/* Private Sale */
_setInitialDistribution(privateSaleAccount, 2000000, 0 /* No Lock */);
_setInitialDistribution(privateSaleAccount, 800000, 3 * month); /* After 3 Month */
_setInitialDistribution(privateSaleAccount, 800000, 4 * month); /* After 4 Months */
_setInitialDistribution(privateSaleAccount, 800000, 5 * month); /* After 5 Months */
_setInitialDistribution(privateSaleAccount, 800000, 6 * month); /* After 6 Months */
_setInitialDistribution(privateSaleAccount, 800000, 7 * month); /* After 7 Months */
_setInitialDistribution(privateSaleAccount, 800000, 8 * month); /* After 8 Months */
_setInitialDistribution(privateSaleAccount, 800000, 9 * month); /* After 9 Months */
_setInitialDistribution(privateSaleAccount, 800000, 10 * month); /* After 10 Months */
_setInitialDistribution(privateSaleAccount, 800000, 11 * month); /* After 11 Months */
_setInitialDistribution(privateSaleAccount, 800000, 12 * month); /* After 12 Months */

/* Treasury Reserve Fund */
_setInitialDistribution(treasuryFundAccount, 2500000, 2 * year); /* After Two Years */
_setInitialDistribution(treasuryFundAccount, 2500000, 2 * year+(3 * month)); /* After 3 Month */
_setInitialDistribution(treasuryFundAccount, 2500000, 2 * year+(6 * month)); /* After 6 Month */
_setInitialDistribution(treasuryFundAccount, 2500000, 2 * year+(9 * month)); /* After 9 Month */

/* Liquidity Fund */
_setInitialDistribution(liquidityAccount, 1000000, 0 /* No Lock */);
_setInitialDistribution(liquidityAccount, 2000000, 1 * month); /* After 1 Month */
_setInitialDistribution(liquidityAccount, 2000000, 2 * month); /* After 2 Months */
_setInitialDistribution(liquidityAccount, 2000000, 3 * month); /* After 3 Months */

/* Community and Partnerships */
_setInitialDistribution(communityPartnerAccount, 1000000, 1 * month); /* After 1 Month */
_setInitialDistribution(communityPartnerAccount, 1000000, 2 * month); /* After 2 Months */
_setInitialDistribution(communityPartnerAccount, 1000000, 3 * month); /* After 3 Months */
_setInitialDistribution(communityPartnerAccount, 1000000, 4 * month); /* After 4 Months */
_setInitialDistribution(communityPartnerAccount, 1000000, 5 * month); /* After 5 Months */
_setInitialDistribution(communityPartnerAccount, 1000000, 6 * month); /* After 6 Months */
_setInitialDistribution(communityPartnerAccount, 1000000, 7 * month); /* After 7 Months */
_setInitialDistribution(communityPartnerAccount, 1000000, 8 * month); /* After 8 Months */
_setInitialDistribution(communityPartnerAccount, 1000000, 9 * month); /* After 9 Months */
_setInitialDistribution(communityPartnerAccount, 1000000, 10 * month); /* After 10 Months */
_setInitialDistribution(communityPartnerAccount, 1000000, 11 * month); /* After 11 Months */
_setInitialDistribution(communityPartnerAccount, 1000000, 12 * month); /* After 12 Months */
_setInitialDistribution(communityPartnerAccount, 1000000, 13 * month); /* After 13 Month */
_setInitialDistribution(communityPartnerAccount, 1000000, 14 * month); /* After 14 Months */
_setInitialDistribution(communityPartnerAccount, 1000000, 15 * month); /* After 15 Months */
_setInitialDistribution(communityPartnerAccount, 1000000, 16 * month); /* After 16 Months */
_setInitialDistribution(communityPartnerAccount, 1000000, 17 * month); /* After 17 Months */
_setInitialDistribution(communityPartnerAccount, 1000000, 18 * month); /* After 18 Months */
_setInitialDistribution(communityPartnerAccount, 1000000, 19 * month); /* After 19 Months */
_setInitialDistribution(communityPartnerAccount, 1000000, 20 * month); /* After 20 Months */

/* Rewards & Loyalty */
_setInitialDistribution(rewardAccount, 1000000, 0 ); /* No Lock */
_setInitialDistribution(rewardAccount, 1000000, 7 * month); /* After 7 Months */
_setInitialDistribution(rewardAccount, 1000000, 8 * month); /* After 8 Months */
_setInitialDistribution(rewardAccount, 1000000, 9 * month); /* After 9 Months */
_setInitialDistribution(rewardAccount, 1000000, 10 * month); /* After 10 Months */
_setInitialDistribution(rewardAccount, 1000000, 11 * month); /* After 11 Months */
_setInitialDistribution(rewardAccount, 1000000, 12 * month); /* After 12 Months */
_setInitialDistribution(rewardAccount, 1000000, 13 * month); /* After 13 Months */
_setInitialDistribution(rewardAccount, 1000000, 14 * month); /* After 14 Months */
_setInitialDistribution(rewardAccount, 1000000, 15 * month); /* After 15 Months */
_setInitialDistribution(rewardAccount, 1000000, 16 * month); /* After 16 Months */
_setInitialDistribution(rewardAccount, 1000000, 17 * month); /* After 17 Month */
_setInitialDistribution(rewardAccount, 1000000, 18 * month); /* After 18 Months */
_setInitialDistribution(rewardAccount, 1000000, 19 * month); /* After 19 Months */
_setInitialDistribution(rewardAccount, 1000000, 20 * month); /* After 20 Months */
_setInitialDistribution(rewardAccount, 1000000, 21 * month); /* After 21 Months */
_setInitialDistribution(rewardAccount, 1000000, 22 * month); /* After 22 Months */
_setInitialDistribution(rewardAccount, 1000000, 23 * month); /* After 23 Months */
_setInitialDistribution(rewardAccount, 1000000, 24 * month); /* After 24 Months */
_setInitialDistribution(rewardAccount, 1000000, 25 * month); /* After 25 Months */
_setInitialDistribution(rewardAccount, 1000000, 26 * month); /* After 26 Months */
_setInitialDistribution(rewardAccount, 1000000, 27 * month); /* After 27 Months */
_setInitialDistribution(rewardAccount, 1000000, 28 * month); /* After 28 Months */
_setInitialDistribution(rewardAccount, 1000000, 29 * month); /* After 29 Months */
_setInitialDistribution(rewardAccount, 1000000, 30 * month); /* After 30 Months */

/* Team */
_setInitialDistribution(teamAccount, 2000000, 6 * month); /* After 6 Months */
_setInitialDistribution(teamAccount, 2000000, 9 * month); /* After 9 Months */
_setInitialDistribution(teamAccount, 2000000, 12 * month); /* After 12 Months */
_setInitialDistribution(teamAccount, 2000000, 15 * month); /* After 15 Months */
_setInitialDistribution(teamAccount, 2000000, 18 * month); /* After 18 Months */

/* Advisors */
_setInitialDistribution(advisorAccount, 1000000, 3 * month); /* After 3 Months */
_setInitialDistribution(advisorAccount, 1000000, 6 * month); /* After 6 Months */
_setInitialDistribution(advisorAccount, 1000000, 9 * month); /* After 9 Months */
_setInitialDistribution(advisorAccount, 1000000, 12 * month); /* After 12 Months */
_setInitialDistribution(advisorAccount, 1000000, 15 * month); /* After 15 Months */
_setInitialDistribution(advisorAccount, 1000000, 18 * month); /* After 18 Months */
_setInitialDistribution(advisorAccount, 1000000, 21 * month); /* After 21 Months */
	

	}

  /******************************************* modifiers go here ********************************************************* */
  
  
  /******************************************* rescue function ********************************************************* */

	function safeGuardAllTokens(address _address) external onlyOwner whenPaused  { /* In case of needed urgency for the sake of contract bug */
		require(IERC20(erc20).transfer(_address, IERC20(erc20).balanceOf(address(this))));
	}


  /******************************************* read state functions go here ********************************************************* */

function getBeneficiaryPoolLength(address beneficary) view public returns (uint256 arrayLneght) {
	return _distributions[beneficary].length;
}
function getBeneficiaryPoolInfo(address beneficary, uint256 index) view external returns (	uint256 amountAllocated,
	    uint256 unlockTime,
		bool sent) {
			amountAllocated= _distributions[beneficary][index]. amountAllocated;
			unlockTime= _distributions[beneficary][index]. unlockTime;
			sent= _distributions[beneficary][index].sent;
}
  /******************************************* state functions go here ********************************************************* */



    /**
     * @dev Pauses contract.
     *
     * 
     *
     * Requirements:
     *
     * - the caller must be the owner.
     */
    function pause() external virtual onlyOwner whenNotPaused {
        _pause();
    }

    /**
     * @dev Unpauses contract.
     *
     * 
     *
     * Requirements:
     *
     * - the caller must be the owner.
     */
    function unpause() external virtual onlyOwner whenPaused {
        _unpause();
    }
	/**
	*   Should allow any address to trigger it, but since the calls are atomic it should do only once per day
	 */

	function triggerTokenSend() external whenNotPaused nonReentrant {
	
		/* TGE has not started */
		require(block.timestamp > TGEDate, "TGE still has not started");
	
		/* Go thru all tokenOwners */
		for(uint i = 0; i < tokenOwners.length; i++) {
			/* Get Address Distribution */
			DistributionStep[] memory d = _distributions[tokenOwners[i]];
			/* Go thru all distributions array */
			for(uint j = 0; j < d.length; j++){
				if(!d[j].sent && d[j].unlockTime< block.timestamp) 
              {
					_distributions[tokenOwners[i]][j].sent = true;
					require(IERC20(erc20).transfer(tokenOwners[i],_distributions[tokenOwners[i]][j]. amountAllocated));
				}
			}
		}   
	}

	function _setInitialDistribution(address _address, uint256 _tokenAmount, uint256 _unlockDays) private  {
	
		/* Create DistributionStep Object */
		DistributionStep memory distributionStep = DistributionStep(_tokenAmount*1 ether , block.timestamp+ _unlockDays, false);
		/* Attach */
		_distributions[_address].push(distributionStep);

	}
}