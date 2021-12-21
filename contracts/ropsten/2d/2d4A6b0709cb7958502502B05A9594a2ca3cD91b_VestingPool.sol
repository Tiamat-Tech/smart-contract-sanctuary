//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.2;

import "./GTH.sol"; //todo: from old version of the project. Refactor in next iteration
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract VestingPool is OwnableUpgradeable {

    // The token being vested
    GTH public token;
    bool public initialized;
    // Category name identifiers
    bytes32 public privateCategory;
    bytes32 public platformCategory;
    bytes32 public seedCategory;
    bytes32 public foundationCategory;
    bytes32 public marketingCategory;
    bytes32 public teamCategory;
    bytes32 public advisorCategory;

    bool public isVestingStarted;
    uint256 public vestingStartDate;

    struct vestingInfo {
        uint256 limit;
        uint256 released;
        uint256[] scheme;
        mapping(address => bool) adminEmergencyFirstApprove;
        mapping(address => bool) adminEmergencySecondApprove;
        bool multiownedEmergencyFirstApprove;
        bool multiownedEmergencySecondApprove;
        uint256 initEmergencyDate;
    }

    mapping(bytes32 => vestingInfo) public vesting;


    address public admin1address;
    address public admin2address;

    event Withdraw(address _to, uint256 _amount);


    function VestingPool_init() public initializer {
        __Ownable_init();

        initialized = false;
        privateCategory = keccak256("privateCategory");
        platformCategory = keccak256("platformCategory");
        seedCategory = keccak256("seedCategory");
        foundationCategory = keccak256("foundationCategory");
        marketingCategory = keccak256("marketingCategory");
        teamCategory = keccak256("teamCategory");
         advisorCategory = keccak256("advisorCategory");

         //token = GTH(_token);
        isVestingStarted=true;
        vestingStartDate=1599686156;
        admin1address=0xe8517582FfB8B8E80fBA2388Eb3F08aea1DED4e2;
        admin2address=0x95B58643b53172Cfdd711A7F54ae8f09ED4d37Ac;

        // Setup vesting data for each category
        //_initVestingData();
        //_initVestingDataV2();
    }

    modifier isNotStarted() {
        require(!isVestingStarted, "Gath3r: Vesting is already started");
        _;
    }

    modifier isStarted() {
        require(isVestingStarted, "Gath3r: Vesting is not started yet");
        _;
    }

    modifier approvedByAdmins(bytes32 _category) {
        require(
            vesting[_category].adminEmergencyFirstApprove[admin1address],
            "Gath3r: Emergency transfer must be approved by Admin 1"
        );
        require(
            vesting[_category].adminEmergencyFirstApprove[admin2address],
            "Gath3r: Emergency transfer must be approved by Admin 2"
        );
        require(
            vesting[_category].adminEmergencySecondApprove[admin1address],
            "Gath3r: Emergency transfer must be approved twice by Admin 1"
        );
        require(
            vesting[_category].adminEmergencySecondApprove[admin2address],
            "Gath3r: Emergency transfer must be approved twice by Admin 2"
        );
        _;
    }

    modifier approvedByMultiowned(bytes32 _category) {
        require(
            vesting[_category].multiownedEmergencyFirstApprove,
            "Gath3r: Emergency transfer must be approved by Multiowned"
        );
        require(
            vesting[_category].multiownedEmergencySecondApprove,
            "Gath3r: Emergency transfer must be approved twice by Multiowned"
        );
        _;
    }

  

    // Vesting data for public sale category
    function initVestingDataV2() external {
        //require(initialized == false, "VP: already initialzed");
        // Vesting data for platform category
        vesting[platformCategory].limit = _expandToDecimals(30000000);
        vesting[platformCategory].released = _expandToDecimals(30000000);
        vesting[platformCategory].multiownedEmergencyFirstApprove = true;
        vesting[platformCategory].multiownedEmergencySecondApprove = true;
        vesting[platformCategory].initEmergencyDate = 1602496877;
        vesting[platformCategory].scheme = [
            /* initial amount */
            30000000
        ];

      

       initialized =true;   
    }

    function _expandToDecimals(uint256 _amount)
        internal
        view
        returns (uint256)
    {
        return _amount * (10**uint256(token.decimals()));
    }    
}