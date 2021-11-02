// SPDX-License-Identifier: MIT
pragma solidity ^0.8.1;

import  "./ChainStakePoolFactory.sol";
import "./common/Ownable.sol";

 contract ChainStakesFactory is Ownable{ 
//struct to store deployed Factory details;
      
        struct Factory{
            address owner;
            address subAdmin;
            address factoryAddress;
            address rewardToken;
            uint256 rewardTokenPerBlock;
            uint256 initBlock;
            uint256 totalRewardSupply;
            uint256 vestingWindow;
        }

    Factory[] public factoryArray;

//address of factory
    mapping(address=>Factory) public FactoryInfo ;

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
        Factory memory newFactory = Factory({
              owner:_owner,
              subAdmin: _subAdmin,
              factoryAddress: address(_factoryAddress),
              rewardToken: _rewardToken,
              rewardTokenPerBlock:_rewardTokenPerBlock,
              initBlock:_initBlock,
              totalRewardSupply:_totalRewardSupply,
              vestingWindow:_vestingWindow
        });

// add new Factory to array;        
         factoryArray.push(newFactory);

//mapping factoryaddress with Factory
     FactoryInfo[address(_factoryAddress)]=newFactory;

  emit DeployedFactoryContract( _owner, _subAdmin,  address(_factoryAddress),
   _rewardToken, _rewardTokenPerBlock,_initBlock,_totalRewardSupply,_vestingWindow
    );

    return address(_factoryAddress);

}


function factoryLength() public view returns(uint256){
          return factoryArray.length ;   
          
          }


function getFactory(uint256 _index) public view returns(Factory memory){

return factoryArray[_index];

          }
}