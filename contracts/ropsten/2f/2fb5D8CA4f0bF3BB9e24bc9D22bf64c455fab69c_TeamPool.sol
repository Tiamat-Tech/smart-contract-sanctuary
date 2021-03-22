// "SPDX-License-Identifier: MIT"
pragma solidity >=0.6.6;
pragma experimental ABIEncoderV2;


import "./vendors/interfaces/IERC20.sol";
import "./vendors/libraries/SafeMath.sol";
import "./vendors/libraries/SafeERC20.sol";
import "./vendors/libraries/Ownable.sol";



contract TeamPool is Ownable{
    
    using SafeMath for uint;
    using SafeERC20 for IERC20;

    event Withdraw(uint tokensAmount);

    address public _PACT;
    uint constant oneYear = 365 days;
 
    struct AnnualSupply {
        uint ulockTime;
        uint alowed;

	}

    mapping (uint => AnnualSupply) internal annualSupplyPoints;

 constructor (
        address ownerAddress,
        address PACT
    ) {
        require (PACT != address(0), "PACT ADDRESS SHOULD BE NOT NULL");
        _PACT = PACT;
        transferOwnership(ownerAddress == address(0) ? msg.sender : ownerAddress);
        annualSupplyPoints[0] = AnnualSupply(uint(block.timestamp), 25000000e18);                     
        annualSupplyPoints[1] = AnnualSupply(uint(block.timestamp).add(oneYear.mul(1)), 25000000e18); 
        annualSupplyPoints[2] = AnnualSupply(uint(block.timestamp).add(oneYear.mul(2)), 25000000e18);
        annualSupplyPoints[3] = AnnualSupply(uint(block.timestamp).add(oneYear.mul(3)), 25000000e18);
    }


    // function getReleases() external view returns(AnnualSupply[] memory) {
    //     AnnualSupply[] memory ret = new AnnualSupply[](4);
    //     for (uint i = 0; i < 4; i++) {
    //         ret[i] = annualSupplyPoints[i];
    //     }
    //     return ret;
    // }    

    function getReleases() external view returns(uint[2][4] memory ret) {
        for (uint i = 0; i < 4; i++) {
            ret[i] = [annualSupplyPoints[i].ulockTime,annualSupplyPoints[i].alowed];
        }
        return ret;
    }   

    function withdraw(address to,uint amount) external onlyOwner {
        IERC20 PACT = IERC20(_PACT);
        require (to != address(0), "ADDRESS SHOULD BE NOT NULL");
        require(amount <= PACT.balanceOf(address(this)), "NOT ENOUGH PACT TOKENS ON TEAMPOOL CONTRACT BALANCE");
        for(uint i; i < 4; i++) {
            if(annualSupplyPoints[i].alowed >= amount && block.timestamp >= annualSupplyPoints[i].ulockTime) {
               annualSupplyPoints[i].alowed = annualSupplyPoints[i].alowed.sub(amount);
               PACT.safeTransfer(to, amount);
               return ;
            }
        }
        require (false, "TokenTimelock: no tokens to release");              
    }

}