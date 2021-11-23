// SPDX-License-Identifier: MIT
pragma solidity ^0.8.1;

import "./ChainStakePoolFactory.sol";
import "./common/Ownable.sol";

contract ChainStakesFactory is Ownable {
    //struct to store deployed Factory details;
    struct Factory {
        address owner;
        address subAdmin;
        address factoryAddress;
        address rewardToken;
        uint256 rewardTokenPerBlock;
        uint256 initBlock;
        uint256 totalRewardSupply;
        uint256 vestingWindow;
    }

    //Array hold the deployed factory information.
    Factory[] public factoryArray;

    //Mapping factory address with factory Information
    mapping(address => Factory) public FactoryInfo;

    /**
     * @dev Fired in deploySmartContract
     *
     * @param _owner an address which performed an operation
     * @param _subAdmin subadmin assigned to factory contract being deployed
     * @param factoryAddress deployed factory address
     * @param rewardToken address of reward token
     * @param _rewardTokenPerBlock reward token per block value for factory
     * @param initblock initialblock of deployed contract
     * @param totalRewardSupply total reward supplied to factoryAddress
     * @param vestingWindow vesting window for factory contract

     */
    event DeployedFactoryContract(
        address indexed _owner,
        address indexed _subAdmin,
        address indexed factoryAddress,
        address rewardToken,
        uint256 _rewardTokenPerBlock,
        uint256 initblock,
        uint256 totalRewardSupply,
        uint256 vestingWindow
    );

    constructor() {
        //set owner
        Ownable.init(msg.sender);
    }

    /**
     * @dev deploy ChainStakePoolFactory
     *
     * @param _owner an address which performed an operation
     * @param _subAdmin subadmin assigned to factory contract being deployed
     * @param _rewardToken address of reward token
     * @param _rewardTokenPerBlock reward token per block value for factory
     * @param _initBlock initialblock of deployed contract
     * @param _totalRewardSupply total reward supplied to factoryAddress
     * @param _vestingWindow vesting window for factory contract
     */
    function deploySmartContract(
        address _owner,
        address _rewardToken,
        address _subAdmin,
        uint256 _rewardTokenPerBlock,
        uint256 _initBlock,
        uint256 _totalRewardSupply,
        uint256 _vestingWindow
    ) public onlyOwner returns (address) {
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
            owner: _owner,
            subAdmin: _subAdmin,
            factoryAddress: address(_factoryAddress),
            rewardToken: _rewardToken,
            rewardTokenPerBlock: _rewardTokenPerBlock,
            initBlock: _initBlock,
            totalRewardSupply: _totalRewardSupply,
            vestingWindow: _vestingWindow
        });

        // add new Factory to array;
        factoryArray.push(newFactory);

        //mapping factoryaddress with Factory
        FactoryInfo[address(_factoryAddress)] = newFactory;

        emit DeployedFactoryContract(
            _owner,
            _subAdmin,
            address(_factoryAddress),
            _rewardToken,
            _rewardTokenPerBlock,
            _initBlock,
            _totalRewardSupply,
            _vestingWindow
        );

        return address(_factoryAddress);
    }

    /**
     * @dev provide length of factoryArray
     */
    function factoryLength() public view returns (uint256) {
        return factoryArray.length;
    }

    /**
     * @dev provide information of factory of specific index
     *
     * @param _index index of Array
     */
    function getFactory(uint256 _index) public view returns (Factory memory) {
        return factoryArray[_index];
    }
}