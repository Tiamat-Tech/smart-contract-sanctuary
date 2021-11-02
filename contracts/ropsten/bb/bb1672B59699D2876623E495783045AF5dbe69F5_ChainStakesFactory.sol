// SPDX-License-Identifier: MIT
pragma solidity ^0.8.1;

import  "./ChainStakePoolFactory.sol";
import "./common/Ownable.sol";

 contract ChainStakesFactory is Ownable{ 
//struct to store deployed poolfactory details;
      
        struct PoolFactory{
            address owner;
            address subAdmin;
            address factoryAddress;
            address rewardToken;
            uint256 rewardTokenPerBlock;
            uint256 initBlock;
            uint256 totalRewardSupply;
            uint256 vestingWindow;
        }

    PoolFactory[] public poolfactorys;

//address of factory
    mapping(address=>PoolFactory) public poolfactory ;

   constructor (){
       //set owner
       Ownable.init(msg.sender);
   }


    event DeployedFactoryContract(
        address indexed _owner,
        address indexed _subAdmin, 
        address indexed factoryAddress,
        address rewardToken,
        uint256 _rewardTokenPerBlock,
        uint256 initblock,
        uint256 totalRewardSupply,
        uint256  vestingWindoe

    );

function deploySmartContract(
    address _owner,
  address _rewardToken,
      address _subAdmin,
 uint256 _rewardTokenPerBlock,
 uint256 _initBlock,
 uint256 _totalRewardSupply,
 uint256 _vestingWindow
 ) public  onlyOwner returns(address){
 ChainStakePoolFactory _factoryAddress = new ChainStakePoolFactory(
            _owner,
            _rewardToken,
            _subAdmin,
            _rewardTokenPerBlock,
            _initBlock,
            _totalRewardSupply,
            _vestingWindow

        );

        // register it within a factory
        PoolFactory memory newpoolfactory = PoolFactory({
              owner:_owner,
              subAdmin: _subAdmin,
              factoryAddress: address(_factoryAddress),
              rewardToken: _rewardToken,
              rewardTokenPerBlock:_rewardTokenPerBlock,
              initBlock:_initBlock,
              totalRewardSupply:_totalRewardSupply,
              vestingWindow:_vestingWindow
        });

// add new poolfactory to array;        
         poolfactorys.push(newpoolfactory);

//mapping factoryaddress with poolfactory
     poolfactory[address(_factoryAddress)]=newpoolfactory;

  emit DeployedFactoryContract( _owner, _subAdmin,  address(_factoryAddress),
   _rewardToken, _rewardTokenPerBlock,_initBlock,_totalRewardSupply,_vestingWindow
    );

    return address(_factoryAddress);

}




}