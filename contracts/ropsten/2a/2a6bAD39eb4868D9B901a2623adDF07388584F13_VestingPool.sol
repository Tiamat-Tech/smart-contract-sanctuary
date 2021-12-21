//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.2;

import "./GTH.sol"; //todo: from old version of the project. Refactor in next iteration
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract VestingPool is OwnableUpgradeable {

    // The token being vested
    GTH public token;
    bool initialized;
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
        require(!initialized, "VP: already initialzed");
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

        vesting[privateCategory].limit = _expandToDecimals(20000000);
        vesting[privateCategory].released = _expandToDecimals(30000000);
        vesting[privateCategory].multiownedEmergencyFirstApprove = false;
        vesting[privateCategory].multiownedEmergencySecondApprove = false;
        vesting[privateCategory].initEmergencyDate = 0;
        vesting[privateCategory].scheme = [
            /* initial amount */
            10500000,
            /* M+1 M+2 */
            10500000,
            9000000
        ];

        // Vesting data for seed category
        vesting[seedCategory].limit = _expandToDecimals(22522500);
        vesting[seedCategory].released = _expandToDecimals(22522500);
        vesting[seedCategory].multiownedEmergencyFirstApprove = false;
        vesting[seedCategory].multiownedEmergencySecondApprove = false;
        vesting[seedCategory].initEmergencyDate = 0;
        vesting[seedCategory].scheme = [
            /* initial amount */
            5630625,
            /* M+1 M+2 M+3 M+4 M+5 */
            3378375,
            3378375,
            3378375,
            3378375,
            3378375
        ];

                // Vesting data for foundation category
        vesting[foundationCategory].limit = _expandToDecimals(193477500);
        vesting[foundationCategory].released = _expandToDecimals(50000000);
        vesting[foundationCategory].multiownedEmergencyFirstApprove = false;
        vesting[foundationCategory].multiownedEmergencySecondApprove = false;
        vesting[foundationCategory].initEmergencyDate = 0;        
        vesting[foundationCategory].scheme = [
            /* initial amount */
            0,
            /* M+1 M+2 M+3 M+4 M+5 M+6 M+7 M+8 M+9 M+10 M+11 M+12 */
            0,
            0,
            0,
            0,
            0,
            6000000,
            6000000,
            6000000,
            6000000,
            6000000,
            6000000,
            6000000,
            /* Y+2 */
            4000000,
            4000000,
            4000000,
            4000000,
            4000000,
            4000000,
            4000000,
            4000000,
            4000000,
            4000000,
            4000000,
            4000000,
            /* Y+3 */
            4000000,
            4000000,
            4000000,
            4000000,
            4000000,
            4000000,
            4000000,
            4000000,
            4000000,
            4000000,
            4000000,
            4000000,
            /* Y+4 */
            3000000,
            3000000,
            3000000,
            3000000,
            3000000,
            3000000,
            3000000,
            3000000,
            3000000,
            3000000,
            3000000,
            3000000,
            /* Y+5 */
            19477500
        ];

        vesting[marketingCategory].limit = _expandToDecimals(50000000);
        vesting[marketingCategory].released = _expandToDecimals(23000000);
        vesting[marketingCategory].multiownedEmergencyFirstApprove = false;
        vesting[marketingCategory].multiownedEmergencySecondApprove = false;
        vesting[marketingCategory].initEmergencyDate = 0;          
        vesting[marketingCategory].scheme = [
            /* initial amount */
            0,
            /* M+1 M+2 M+3 M+4 M+5 M+6 M+7 M+8 M+9 M+10 M+11 M+12 */
            0,
            0,
            2000000,
            2000000,
            2000000,
            2000000,
            2000000,
            2000000,
            2000000,
            2000000,
            2000000,
            2000000,
            /* Y+2 */
            1500000,
            1500000,
            1500000,
            1500000,
            1500000,
            1500000,
            1500000,
            1500000,
            1500000,
            1500000,
            1500000,
            1500000,
            /* Y+3 */
            1000000,
            1000000,
            1000000,
            1000000,
            1000000,
            1000000,
            1000000,
            1000000,
            1000000,
            1000000,
            1000000,
            1000000
        ]; 

                // Vesting data for team category
        vesting[teamCategory].limit = _expandToDecimals(50000000);
        vesting[teamCategory].released = _expandToDecimals(21000000);
        vesting[teamCategory].multiownedEmergencyFirstApprove = false;
        vesting[teamCategory].multiownedEmergencySecondApprove = false;
        vesting[teamCategory].initEmergencyDate = 0;          
        vesting[teamCategory].scheme = [
            /* initial amount */
            0,
            /* M+1 M+2 M+3 M+4 M+5 M+6 M+7 M+8 M+9 M+10 M+11 M+12 */
            0,
            0,
            0,
            0,
            0,
            7000000,
            0,
            0,
            0,
            7000000,
            0,
            0,
            /* Y+2 */
            0,
            7000000,
            0,
            0,
            0,
            7000000,
            0,
            0,
            7000000,
            0,
            0,
            0,
            /* Y+3 */
            0,
            7500000,
            0,
            0,
            0,
            7500000
        ]; 

                // Vesting data for advisor category
        vesting[advisorCategory].limit = _expandToDecimals(24000000);
        vesting[advisorCategory].released = _expandToDecimals(24000000);
        vesting[advisorCategory].multiownedEmergencyFirstApprove = false;
        vesting[advisorCategory].multiownedEmergencySecondApprove = false;
        vesting[advisorCategory].initEmergencyDate = 0;  
        vesting[advisorCategory].scheme = [
            /* initial amount */
            0,
            /* M+1 M+2 M+3 M+4 M+5 M+6 M+7 M+8 M+9 */
            0,
            0,
            6000000,
            6000000,
            4500000,
            4500000,
            0,
            1500000,
            1500000
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