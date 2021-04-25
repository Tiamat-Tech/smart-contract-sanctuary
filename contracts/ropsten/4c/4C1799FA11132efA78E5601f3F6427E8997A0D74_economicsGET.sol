pragma solidity ^0.6.2;
pragma experimental ABIEncoderV2;

import "./utils/Initializable.sol";
import "./interfaces/IERC20.sol";

contract IGETAccessControl {
    function hasRole(bytes32, address) public view returns (bool) {}
}


/** GET Protocol CORE contract
- contract that defines for different ticketeers how much is paid in GET 'gas' per statechange type
- contract/proxy will act as a prepaid bank contract.
- contract will be called using a proxy (upgradable)
- relayers are ticketeers/integrators
- contract is still WIP
 */
contract economicsGET is Initializable {
    IGETAccessControl public GET_BOUNCER;
    IERC20 public FUELTOKEN;

    bytes32 public constant RELAYER_ROLE = keccak256("RELAYER_ROLE");
    bytes32 public constant FACTORY_ROLE = keccak256("FACTORY_ROLE");
    bytes32 public constant GET_TEAM_MULTISIG = keccak256("GET_TEAM_MULTISIG");
    bytes32 public constant GET_GOVERNANCE = keccak256("GET_GOVERNANCE");

    address public treasuryAddress;
    address public burnAddress;

    /**
    struct defines how much GET is sent from relayer to economcs per type of contract interaction
    - treasuryFee amount of wei GET that is sent to primary
    [0 setAsideMint, 1 primarySaleMint, 2 secondarySale, 3 Scan, 4 Claim, 6 CreateEvent, 7 ModifyEvent]
    - burnFee amount of wei GET that is sent to burn adres
    [0 setAsideMint, 1 primarySaleMint, 2 secondarySale, 3 Scan, 4 Claim, 6 CreateEvent, 7 ModifyEvent]
    */
    struct EconomicsConfig {
        address relayerAddress;
        uint timestampStarted; // blockheight of when the config was set
        uint timestampEnded; // is 0 if economics confis is still active
        uint256[] treasuryFee;
        uint256[] burnFee;
        bool isConfigured;
    }


    // mapping from relayer address to configs (that are active)
    mapping(address => EconomicsConfig) public allConfigs;

    // storage of old configs
    EconomicsConfig[] public oldConfigs;

    // mapping from relayer address to GET/Fuel balance
    mapping(address => uint256) public relayerBalance;

    // TODO check if it defaults to false for unknwon addresses.
    mapping(address => bool) public relayerRegistry;
    
    event ticketeerCharged(
        address indexed ticketeerRelayer, 
        uint256 indexed chargedFee
    );

    event configChanged(
        address adminAddress,
        address relayerAddress,
        uint timestamp
    );

    event feeToTreasury(
        uint256 feeToTreasury,
        uint256 remainingBalance
    );

    event feeToBurn(
        uint256 feeToTreasury,
        uint256 remainingBalance
    );

    event relayerToppedUp(
        address relayerAddress,
        uint256 amountToppedUp,
        uint timeStamp
    );

    event allFuelPulled(
        address requestAddress,
        address receivedByAddress,
        uint256 amountPulled
    );

    function initialize_economics(
        address _address_bouncer
        ) public initializer {
            GET_BOUNCER = IGETAccessControl(_address_bouncer);
            treasuryAddress = 0x0000000000000000000000000000000000000000;
            burnAddress = 0x0000000000000000000000000000000000000000;
        }
    
    function editCoreAddresses(
        address _address_burn_new,
        address _address_treasury_new
    ) external {
        // check if sender is admin
        require(GET_BOUNCER.hasRole(RELAYER_ROLE, msg.sender), "setEconomicsConfig: must have admin role to charge");

        treasuryAddress = _address_treasury_new;
        burnAddress = _address_burn_new;
    }


    function setEconomicsConfig(
        address relayerAddress,
        EconomicsConfig memory EconomicsConfigNew
    ) public {

        // check if sender is admin
        require(GET_BOUNCER.hasRole(RELAYER_ROLE, msg.sender), "setEconomicsConfig: must have admin role to charge");

        // check if relayer had a previously set economic config
        // if so, the config that is replaced needs to be stored
        // otherwise it will be lost and this will make tracking usage harder for those analysing
        if (allConfigs[relayerAddress].isConfigured == true) {  // if storage occupied
            // add the old econmic config to storage
            oldConfigs.push(allConfigs[relayerAddress]);
        }

        // store config in mapping
        allConfigs[relayerAddress] = EconomicsConfigNew;

        // set the blockheight of starting block
        allConfigs[relayerAddress].timestampStarted = block.timestamp;
        allConfigs[relayerAddress].isConfigured = true;

        emit configChanged(
            msg.sender,
            relayerAddress,
            block.timestamp
        );

    }

    function balanceOfRelayer(
        address _relayerAddress
    ) public returns (uint256 balanceRelayer) 
    {
        balanceRelayer = relayerBalance[_relayerAddress];
    }

    function balancerOfCaller() public 
    returns (uint256 balanceCaller) 
        {
            balanceCaller = relayerBalance[msg.sender];
        }
    
    // TOD) check if this works / can work
    function checkIfRelayer(
        address _relayerAddress
    ) public returns (bool isRelayer) 
    {
        isRelayer = relayerRegistry[_relayerAddress];
    }
    
    function chargePrimaryMint(
        address _relayerAddress
        ) external returns (bool) { // TODO check probably external
        
        // check if call is coming from protocol contract
        require(GET_BOUNCER.hasRole(RELAYER_ROLE, msg.sender), "chargePrimaryMint: must have factory role to charge");

        // how much GET needs to be sent to the treasury
        uint256 _feeT = allConfigs[_relayerAddress].treasuryFee[1];
        // how much GET needs to be sent to the burn
        uint256 _feeB = allConfigs[_relayerAddress].burnFee[1];

        uint256 _balance = relayerBalance[_relayerAddress];

        // check if balance sufficient
        require(
            (_feeT + _feeB) <= _balance,
        "chargePrimaryMint balance low"
        );

        if (_feeT > 0) {
            
            // deduct from balance
            relayerBalance[_relayerAddress] =- _feeT;

            require( // transfer to treasury
            FUELTOKEN.transferFrom(
                address(this),
                treasuryAddress,
                _feeT),
                "chargePrimaryMint _feeT FAIL"
            );

            emit feeToTreasury(
                _feeT,
                relayerBalance[_relayerAddress]
            );
        }

        if (_feeB > 0) {

            // deduct from balance 
            relayerBalance[_relayerAddress] =- _feeB;

            require( // transfer to treasury
            FUELTOKEN.transferFrom(
                address(this),
                burnAddress,
                _feeB),
                "chargePrimaryMint _feeB FAIL"
            );

            emit feeToBurn(
                _feeB,
                relayerBalance[_relayerAddress]
            );

        }

        return true;
    }


    // function chargeSecondaryMint(
            

    //     returns 
    // )

    // ticketeer adds GET 
    /** function that tops up the relayer account
    @dev note that _relayerAddress does not have to be msg.sender
    @dev so it is possible that an address tops up an account that is not itself
    @param _relayerAddress TODO ADD SOME TEXT
    @param amountTopped TODO ADD SOME TEXT
    
     */
    function topUpGet(
        address _relayerAddress,
        uint256 amountTopped
    ) public {

        // TODO maybe add check if msg.sender is real/known/registered

        // check if msg.sender has allowed contract to spend/send tokens
        require(
            FUELTOKEN.allowance(
                msg.sender, 
                address(this)) >= amountTopped,
            "topUpGet - ALLOWANCE FAILED - ALLOW CONTRACT FIRST!"
        );

        // tranfer tokens from msg.sender to contract
        require(
            FUELTOKEN.transferFrom(
                msg.sender, 
                address(this),
                amountTopped),
            "topUpGet - TRANSFERFROM STABLES FAILED"
        );

        // add the sent tokens to the balance
        relayerBalance[_relayerAddress] += amountTopped;

        emit relayerToppedUp(
            _relayerAddress,
            amountTopped,
            block.timestamp
        );
    }

    // emergency function pulling all GET to admin address
    function emergencyPull(address pullToAddress) 
        public {

        // check if sender is admin
        require(GET_BOUNCER.hasRole(RELAYER_ROLE, msg.sender), "emergencyPull: must have admin role to charge");

        uint256 _balanceAll = FUELTOKEN.balanceOf(address(this));

        // add loop that sets all balances to zero
        // set balance to zero

        emit allFuelPulled(
            msg.sender,
            pullToAddress,
            _balanceAll
        );

    }



}