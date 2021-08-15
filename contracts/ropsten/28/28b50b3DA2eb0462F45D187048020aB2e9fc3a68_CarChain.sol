pragma solidity 0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./Staker.sol";
import "./CarNCToken.sol";


/**
 * @title Carchain main contract
 * @notice Handles all core functions
 * @dev This is CarchainV1
 */
contract CarChain {
    using SafeMath for uint256;

    /*---------Constants----------*/

    bytes32 constant EIP712DOMAIN_TYPEHASH =
    keccak256(
        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
    );
    /*---------Variables & constructor----------*/

    /* address => state */
    mapping(address => User) public passengers;
    mapping(address => User) public drivers;

    mapping(uint256 => Trip) public trips;
    uint256 private trip_count;

    mapping(address => Provider) public SPs;
    mapping(address => Provider) public UPs;

    mapping(address => uint256) public sp_active_trips;
    mapping(address => uint256) public up_active_trips;

    mapping(string => address[]) private sp_cities;
    mapping(string => address[]) private up_cities;

    mapping(address => uint256) public balances;

    address public staker;
    address public carNc;
    uint256 public min_stake;
    bytes32 DOMAIN_SEPARATOR;


    constructor(address _carNC) {

        //todo plan for this
        carNc = _carNC;

        staker = address(new Staker(_carNC));


        //todo plan for this
        min_stake = 100 * (10 ** 18);

        DOMAIN_SEPARATOR = hash(
            EIP712Domain({
            name : "Carchain",
            version : "1",
            chainId : block.chainid,
            verifyingContract : address(this)
            })
        );
    }

    /*---------Modifiers----------*/
    function onlyProvider() private {
        require(SPs[msg.sender].exists || UPs[msg.sender].exists);

    }

    function onlySP () private{
        require(SPs[msg.sender].exists);

    }

    function onlyUP() private {
        require(UPs[msg.sender].exists);

    }

    function onlyStakedSP() private {
        require(SPs[msg.sender].stake >= min_stake);

    }

    function onlyStakedUP() private {
        require(UPs[msg.sender].stake >= min_stake);

    }


    /*---------Methods----------*/

    /*-----Managment----*/

    /**
     * @notice the function responsible for validation of service providers request then register.
     * @param _name : Name of the user provider
     * @param _url : Introduction url of the provider
     * @param _api_url : API URL of the provider for client connection
     * @param _fixed_fee : The fee (percent) for making a trip, 2 decimals
     */
    function sp_register(string memory _name, string memory _url, string memory _api_url, uint16 _fixed_fee) public {
        require(!SPs[msg.sender].exists);
        require(_fixed_fee >= 0);
        require(_fixed_fee <= 10000);

        SPs[msg.sender].name = _name;
        SPs[msg.sender].url = _url;
        SPs[msg.sender].api_url = _api_url;
        SPs[msg.sender].fixed_fee = _fixed_fee;
        SPs[msg.sender].exists = true;
        SPs[msg.sender].enabled = true;
    }

    /**
     * @notice the function responsible for validation of user providers request then register.
     * @param _name : Name of the user provider
     * @param _url : Introduction url of the provider
     * @param _api_url : API URL of the provider for client connection
     * @param _fixed_fee : The fee (percent) for making a trip, 2 decimals
     */
    function up_register(string memory _name, string memory _url, string memory _api_url, uint16 _fixed_fee) public {
        require(!UPs[msg.sender].exists);
        require(_fixed_fee >= 0);
        require(_fixed_fee <= 10000);

        UPs[msg.sender].name = _name;
        UPs[msg.sender].url = _url;
        UPs[msg.sender].api_url = _api_url;
        UPs[msg.sender].fixed_fee = _fixed_fee;
        UPs[msg.sender].exists = true;
        UPs[msg.sender].enabled = true;
    }

    /**
     * @notice Registration of passengers(users) by their provider. Means they are verified(activated)
     * @dev we should verify signature
     * @param _passenger : address of the passenger
     * @param _v : v part of signature
     * @param _r : r part of signature
     * @param _s : s part of signature
     */
    function p_register(address _passenger, uint8 _v, bytes32 _r, bytes32 _s) public  {
        onlyStakedUP();
        require(!passengers[_passenger].exists);
        require(verify_register(RegisterProposal(msg.sender), _passenger, _v, _r, _s));

        User memory _newPass;
        _newPass.exists = true;
        _newPass.active = true;
        _newPass.provider = msg.sender;
        passengers[_passenger] = _newPass;
    }

    /**
     * @notice Registration of driver by their provider. Means they are verified(activated)
     * @dev we should verify signature
     * @param _driver : address of the driver
     * @param _v : v part of signature
     * @param _r : r part of signature
     * @param _s : s part of signature
     */
    function d_register(address _driver, uint8 _v, bytes32 _r, bytes32 _s) public  {
        onlyStakedSP();
        require(!drivers[_driver].exists);
        require(verify_register(RegisterProposal(msg.sender), _driver, _v, _r, _s));

        User memory _newDriver;
        _newDriver.exists = true;
        _newDriver.active = true;
        _newDriver.provider = msg.sender;
        drivers[_driver] = _newDriver;
    }

    /**
     * @notice Adding a city to Service provider.
     * @dev //todo discuss whether is it necessary to call this only by stakedSps because of spam?
     * @param _city : city name
     */
    function sp_add_city(string memory _city) public  {
        onlySP();
        //prevents adding duplicate addresses in sp_cities
        require(SPs[msg.sender].city_indexes[_city] == 0);

        if (sp_cities[_city].length == 0) {
            //Push an empty address to index 0
            //because default uint value for city_indexes is 0 in provider struct
            sp_cities[_city].push(address(0));
        }

        sp_cities[_city].push(msg.sender);
        //array index = length-1

        SPs[msg.sender].city_indexes[_city] = sp_cities[_city].length - 1;
    }

    /**
     * @notice Adding a city to user provider.
     * @dev //todo discuss whether is it necessary to call this only by stakedUps because of spam?
     * @param _city : city name
     */
    function up_add_city(string memory _city) public  {
        onlyUP();
        //prevents adding duplicate addresses in sp_cities
        require(UPs[msg.sender].city_indexes[_city] == 0);

        if (up_cities[_city].length == 0) {
            //Push an empty address to index 0
            //because default uint value for city_indexes is 0 in provider struct
            up_cities[_city].push(address(0));
        }

        up_cities[_city].push(msg.sender);
        //array index = length-1

        UPs[msg.sender].city_indexes[_city] = up_cities[_city].length - 1;
    }

    /**
     * @notice Removes city for a service provider
     * @param _city : city name
     */
    function sp_remove_city(string memory _city) public  {
        onlySP();
        //Does the SP have the city ?
        require(SPs[msg.sender].city_indexes[_city] != 0);

        sp_cities[_city][SPs[msg.sender].city_indexes[_city]] = address(0);
        SPs[msg.sender].city_indexes[_city] = 0;
    }

    /**
     * @notice Removes city for a user provider
     * @param _city : city name
     */
    function up_remove_city(string memory _city) public  {
        onlyUP();
        //Does the UP have the city ?
        require(UPs[msg.sender].city_indexes[_city] != 0);

        up_cities[_city][UPs[msg.sender].city_indexes[_city]] = address(0);
        UPs[msg.sender].city_indexes[_city] = 0;
    }

    /**
    * @notice call this to get all sps in a city
    * @param _city : the requested city
    * @return array of the providers
    */
    function SP_by_city( string memory _city) view public returns (address[] memory){
        return sp_cities[_city];
    }

    /**
    * @notice call this to get all ups in a city
    * @param _city : the requested city
    * @return array of the providers
    */
    function UP_by_city( string memory _city) view public returns (address[] memory){
        return up_cities[_city];
    }

    /**
     * @notice function to call by SPs to change their data
     * @param _name : Name of the service provider
     * @param _url : Introduction url of the provider
     * @param _api_url : API URL of the provider for client connection
     * @param _fixed_fee : The fee (percent) for making a trip, 2 decimals
     */
    function edit_sp_data(string memory _name, string memory _url, string memory _api_url, uint16 _fixed_fee) public  {
        onlySP();
        require(_fixed_fee >= 0);
        require(_fixed_fee <= 10000);
        SPs[msg.sender].name = _name;
        SPs[msg.sender].url = _url;
        SPs[msg.sender].api_url = _api_url;
        SPs[msg.sender].fixed_fee = _fixed_fee;
    }

    /**
     * @notice function to call by UPs to change their data
     * @param _name : Name of the user provider
     * @param _url : Introduction url of the provider
     * @param _api_url : API URL of the provider for client connection
     * @param _fixed_fee : The fee (percent) for making a trip, 2 decimals
     */
    function edit_up_data(string memory _name, string memory _url, string memory _api_url, uint16 _fixed_fee) public  {
        onlyUP();
        require(_fixed_fee >= 0);
        require(_fixed_fee <= 10000);

        UPs[msg.sender].name = _name;
        UPs[msg.sender].url = _url;
        UPs[msg.sender].api_url = _api_url;
        UPs[msg.sender].fixed_fee = _fixed_fee;
    }

    /**
     * @notice User providers can active/deactive their passenger
     * @param _user : address of the passenger
     * @param _active : passenger's state
     */
    function toggle_p(address _user, bool _active) public  {
        onlyUP();
        require(passengers[_user].provider == msg.sender);
        passengers[_user].active = _active;
    }

    /**
     * @notice Service providers can active/deactive their driver
     * @param _user : address of the driver
     * @param _active : driver's state
     */
    function toggle_d(address _user, bool _active) public  {
        onlySP();
        require(drivers[_user].provider == msg.sender);
        drivers[_user].active = _active;
    }

    /**
     * @notice User providers can active/deactive themselves
     * @param _active : state
     */
    function toggle_up(bool _active) public  {
        onlyUP();
        UPs[msg.sender].enabled = _active;
    }

    /**
     * @notice Service providers can active/deactive themselves
     * @param _active : state
     */
    function toggle_sp(bool _active) public  {
        onlySP();
        SPs[msg.sender].enabled = _active;
    }

    /**
     * @notice the function to withdraw providers' fees from the contract
     * @param _amount : amount to withdraw
     */
    function withdraw_balance(uint256 _amount) public  {
        onlyProvider();
        require(_amount > 0);
        //balance reduction before transfer
        balances[msg.sender] = balances[msg.sender].sub(_amount);

        _transfer_carnc(msg.sender, _amount);
    }

    /**
     * @notice Service Providers call this function to stake their tokens
     * @dev should approve the contract the _amount tokens
     * @param _amount : amount to stake
     */
    function sp_deposit_stake(uint256 _amount) public  {
        onlySP();
        require(_amount > 0);
        _stake(msg.sender, _amount);
        SPs[msg.sender].stake = SPs[msg.sender].stake.add(_amount);
    }

    /**
     * @notice User Providers call this function to stake their tokens
     * @dev should approve the contract the _amount tokens
     * @param _amount : amount to stake
     */
    function up_deposit_stake(uint256 _amount) public  {
        onlyUP();
        require(_amount > 0);
        _stake(msg.sender, _amount);
        UPs[msg.sender].stake = UPs[msg.sender].stake.add(_amount);
    }

    /**
     * @notice Providers without active trips can withdraw their stake for the total to be less than minimum stake amount
     * @dev validator for withdrawing stakes
     * @param _amount : amount to withdraw
     */
    function sp_withdraw_stake(uint256 _amount) public  {
        onlySP();
        require(sp_active_trips[msg.sender] == 0);
        require(SPs[msg.sender].stake >= _amount);
        SPs[msg.sender].stake = SPs[msg.sender].stake.sub(_amount);
        _withdraw_stake(msg.sender, _amount);
    }

    /**
     * @notice Providers without active trips can withdraw their stake for the total to be less than minimum stake amount
     * @dev validator for withdrawing stakes
     * @param _amount : amount to withdraw
     */
    function up_withdraw_stake(uint256 _amount) public  {
        onlyUP();
        require(up_active_trips[msg.sender] == 0);
        require(UPs[msg.sender].stake >= _amount);
        UPs[msg.sender].stake = UPs[msg.sender].stake.sub(_amount);
        _withdraw_stake(msg.sender, _amount);
    }

    /**
     * @notice Handles staker contract calls for stake
     * @param _provider : requested provider address
     * @param _amount : amount to stake
     */
    function _stake(address _provider, uint256 _amount) private {
        _transfer_from_carnc(_provider, staker, _amount);
        Staker _staker = Staker(staker);
        _staker.deposit(_provider, _amount);
    }


    /**
     * @notice Handles staker contract calls for withdrawing stake
     * @param _provider : requested provider address
     * @param _amount : amount to stake
     */
    function _withdraw_stake(address _provider, uint256 _amount) private {
        Staker _staker = Staker(staker);
        _staker.withdraw(_provider, _amount);
    }

    /*-----trip----*/

    /**
    * @notice trip maker function
    * @dev provider should do the requirements before sending the transaction to prevent useless transactions to the chain
    * @dev todo should check if we can send struct as function arg
    * @param _tripProposal : proposal of the trip
    * @param v_p : Passenger signed section -> V
    * @param r_p : Passenger signed section -> R
    * @param s_p : Passenger signed section -> S
    * @param v_d : Driver signed section -> V
    * @param r_d : Driver signed section -> R
    * @param s_d : Driver signed section -> S
    */
    function make_trip(TripProposal memory _tripProposal, uint8 v_p, bytes32 r_p, bytes32 s_p, uint8 v_d, bytes32 r_d, bytes32 s_d) public  {
        onlyStakedSP();
        //check passenger and driver
        require(passengers[_tripProposal.passenger].active);
        require(passengers[_tripProposal.passenger].inTrip == 0);

        require(drivers[_tripProposal.driver].active);
        require(drivers[_tripProposal.driver].inTrip == 0);

        //check providers
        address _up = passengers[_tripProposal.passenger].provider;

        require(UPs[_up].enabled);
        require(UPs[_up].stake > min_stake);
        require(SPs[msg.sender].enabled);


        //check if the provider is for the driver
        require(drivers[_tripProposal.driver].provider == msg.sender);


        //check deadlines
        require(block.timestamp < _tripProposal.passengerDeadline);
        require(block.timestamp < _tripProposal.driverDeadline);

        //check the fees
        //dont check up fees because already checked when registering/editing
        //require(_tripProposal.up_fee >= 0);
        //require(_tripProposal.up_fee <= 10000);
        require(_tripProposal.sp_fee >= 0);
        require(_tripProposal.sp_fee <= 10000);

        //check user provider and its fee (is constant and should be equal to the request)
        require(UPs[_up].fixed_fee == _tripProposal.up_fee);

        //check the signed messages
        require(verify_trip(_tripProposal, v_p, r_p, s_p, v_d, r_d, s_d));


        _start_trip(_tripProposal, msg.sender, _up);
    }

    /**
    * @notice end trip validator
    * @dev can be called by provider of a trip or the driver
    * @param _id : tripId
    */
    function end_trip(uint256 _id) public {
        //is trip open
        require(trips[_id].state == 0);

        bool isDriver = trips[_id].driver == msg.sender;

        if (!isDriver) {
            require(drivers[trips[_id].driver].provider == msg.sender);
        }


        _end_trip(_id, 1);
    }

    /**
    * @notice cancel trip validator
    * @dev can be called by provider of a trip
    * @param _id : tripId
    * @param _mode : end trip mode, modes list in Trip struct
    */
    function cancel_trip(uint256 _id, uint8 _mode) public {
        //is trip open
        require(trips[_id].state == 0);

        //valid modes from 2 to 5
        require(1 < _mode && _mode < 6);

        require(drivers[trips[_id].driver].provider == msg.sender);

        _end_trip(_id, _mode);

    }

    /**
    * @notice submit passenger's rate
    */
    function rate_trip_p(uint256 _id, uint8 _rate) public {
        require(msg.sender == trips[_id].passenger);
        require(!trips[_id].p_rated);
        require(0 < _rate && _rate < 6);

        trips[_id].p_rated = true;
        drivers[trips[_id].driver].rate_sum += uint256(_rate);
        drivers[trips[_id].driver].rate_count += 1;

        emit TripRated(_id, _rate, msg.sender);

    }

    /**
    * @notice submit driver's rate
    */
    function rate_trip_d(uint256 _id, uint8 _rate) public {
        require(msg.sender == trips[_id].driver);
        require(!trips[_id].d_rated);
        require(0 < _rate && _rate < 6);

        trips[_id].d_rated = true;
        drivers[trips[_id].passenger].rate_sum += uint256(_rate);
        drivers[trips[_id].passenger].rate_count += 1;

        emit TripRated(_id, _rate, msg.sender);

    }

    /**
    * @notice main function responsible for starting trip after validations
    * @dev should be validated then sent here
    * @param _tripProposal : trip proposal struct
    */
    function _start_trip(TripProposal memory _tripProposal, address _sp, address _up) private {
        //Calculate total fee amount
        // (spFee+upFee) * amount / (100 * 100)
        uint256 _fee_amount = uint256(_tripProposal.up_fee + _tripProposal.sp_fee).mul(_tripProposal.price).div(10000);

        //transfer from driver to contract
        _transfer_from_carnc(_tripProposal.driver, address(this), _fee_amount);

        //make trip
        Trip memory _trip = Trip(_tripProposal.price,
            _tripProposal.origindata,
            _tripProposal.destinationData,
            _tripProposal.passenger,
            _tripProposal.driver,
            _tripProposal.sp_fee,
            _tripProposal.up_fee,
            0,
            false, false
        );
        trip_count += 1;
        trips[trip_count] = _trip;


        //update driver and passenger inTrip variables
        passengers[_trip.passenger].inTrip = trip_count;
        drivers[_trip.driver].inTrip = trip_count;

        //update providers active trips
        up_active_trips[_up] += 1;
        sp_active_trips[_sp] += 1;


        //emit event
        emit TripStarted(trip_count, _sp, _up, _trip.passenger, _trip.driver, _tripProposal.price);
    }

    /**
    * @notice main method to end trip after validation
    * @param _id : trip Id
    * @param _mode : end trip mode, modes list in Trip struct
    */
    function _end_trip(uint256 _id, uint8 _mode) private {
        trips[_id].state = _mode;
        emit TripEnded(_id, _mode);

        passengers[trips[_id].passenger].inTrip = 0;
        drivers[trips[_id].driver].inTrip = 0;

        address sp_address = drivers[trips[_id].driver].provider;
        address up_address = passengers[trips[_id].passenger].provider;
        up_active_trips[up_address] -= 1;
        sp_active_trips[sp_address] -= 1;

        _fee_dist(_id, _mode, sp_address, up_address);

    }

    /**
    * @notice main method to distribute trip fees after closing trip
    * @param _id : trip Id
    * @param _mode : end trip mode, modes list in Trip struct
    */

    function _fee_dist(uint256 _id, uint8 _mode, address _sp, address _up) private {


        uint256 amount = trips[_id].amount;
        uint256 sp_share = amount.mul(trips[_id].sp_fee).div(10000);
        uint256 up_share = amount.mul(trips[_id].up_fee).div(10000);

        //pay sp_share else pay back to driver
        if (_mode == 1 || _mode == 2 || _mode == 4) {
            balances[_sp] = balances[_sp].add(sp_share);
        } else {
            _transfer_carnc(trips[_id].driver, sp_share);
        }

        //pay up_share else pay back to driver
        if (_mode == 1 || _mode == 2 || _mode == 5) {
            balances[_up] = balances[_up].add(up_share);
        } else {
            _transfer_carnc(trips[_id].passenger, up_share);
        }

    }


    /**
    * @dev private function to handle CarNC token transfer function
    */
    function _transfer_carnc(address _to, uint256 _amount) private {
        CarNCToken _carNc = CarNCToken(carNc);
        _carNc.transfer(_to, _amount);
    }

    /**
    * @dev private function to handle CarNC token transfer from function
    */
    function _transfer_from_carnc(address _from, address _to, uint256 _amount) private {
        CarNCToken _carNc = CarNCToken(carNc);
        _carNc.transferFrom(_from, _to, _amount);
    }

    /*-----Signiture validation----*/



    /**
     * @notice Create hash of Domain for EIP712
     * @dev should be call in constructor
     * @param eip712Domain : domain of eip712
     */
    function hash(EIP712Domain memory eip712Domain)
    internal
    pure
    returns (bytes32)
    {
        return
        keccak256(
            abi.encode(
                EIP712DOMAIN_TYPEHASH,
                keccak256(bytes(eip712Domain.name)),
                keccak256(bytes(eip712Domain.version)),
                eip712Domain.chainId,
                eip712Domain.verifyingContract
            )
        );
    }

    /**
     * @notice Create hash of TripProposal which will use in verify_trip
     * @dev should be call in verify_trip
     * @param tripProposal : struct of data
     */
    function hash(TripProposal memory tripProposal)
    internal
    pure
    returns (bytes32)
    {
        return
        keccak256(
            abi.encode(
                TRIP_PROPOSAL_TYPEHASH,
                tripProposal.passenger,
                tripProposal.driver,
                tripProposal.price,
                keccak256(bytes(tripProposal.origindata)),
                keccak256(bytes(tripProposal.destinationData)),
                tripProposal.sp_fee,
                tripProposal.up_fee,
                tripProposal.driverDeadline,
                tripProposal.passengerDeadline
            )
        );

    }

    /**
     * @notice Create hash of RegisterProposal which will use in verify_register
     * @dev should be called in verify_register
     * @param _registerProposal : struct of data
     */
    function hash(RegisterProposal memory _registerProposal)
    internal
    pure
    returns (bytes32)
    {
        return
        keccak256(
            abi.encode(
                REGISTER_PROPOSAL_TYPEHASH, _registerProposal.provider
            )
        );
    }

    /**
     * @notice veryfication of two signature from passenger and driver
     * @dev should pass two signature
     * @param tripProposal : struct of data
     */
    function verify_trip(
        TripProposal memory tripProposal,
        uint8 v_p,
        bytes32 r_p,
        bytes32 s_p,
        uint8 v_d,
        bytes32 r_d,
        bytes32 s_d
    ) internal view returns (bool) {
        // Note: we need to use `encodePacked` here instead of `encode`.
        bytes32 digest_1 = keccak256(
            abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, hash(tripProposal))
        );
        bytes32 digest_2 = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", digest_1)
        );

        bool driverVeryfication = ecrecover(digest_2, v_d, r_d, s_d) ==
        tripProposal.driver;
        bool passengerVeryfication = ecrecover(digest_2, v_p, r_p, s_p) ==
        tripProposal.passenger;
        return driverVeryfication && passengerVeryfication;
    }


    /**
     * @notice verify if the user really wanted to be registered by this provider
     * @dev should pass two signature
     * @param _registerProposal : struct of data
     */
    function verify_register(
        RegisterProposal memory _registerProposal,
        address _signer,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) internal view returns (bool) {
        bytes32 digest_1 = keccak256(
            abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, hash(_registerProposal))
        );
        bytes32 digest_2 = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32" ,digest_1)
        );
        return ecrecover(digest_2, _v, _r, _s) == _signer;
    }

    /*---------Structs----------*/

    struct Provider {
        string name;
        string url;
        string api_url;
        uint16 fixed_fee; //fixed provider fee with 2 decimals
        uint256 stake; //stake amount
        bool exists;
        bool enabled;
        mapping(string => uint256) city_indexes;
    }

    /** Trip states
     * 0 => started
     * 1 => finished
     * 2 => canceled : sp fee is paid, up fee is paid
     * 3 => canceled : sp fee is Not paid, up fee is Not paid
     * 4 => canceled : sp fee is paid, up fee is Not paid
     * 5 => canceled : sp fee is Not paid, up fee is paid
     */
    struct Trip {
        uint256 amount;
        string origindata;
        string destinationData;
        address passenger;
        address driver;
        uint16 sp_fee;
        uint16 up_fee;
        uint8 state;
        bool d_rated; //rate submitted by driver
        bool p_rated; //rate submitted by passenger
    }

    struct User {
        string name;
        bool exists;
        bool active; //providers can dative their users permanently or temporarily
        uint256 inTrip; //if 0 => free to have trips, if not => current tripId
        address provider;
        uint256 rate_sum;
        uint128 rate_count;
    }

    bytes32 constant TRIP_PROPOSAL_TYPEHASH =
    keccak256(
        "TripProposal(address passenger,address driver,uint256 price,string origindata,string destinationData,uint16 sp_fee,uint16 up_fee,uint256 driverDeadline,uint256 passengerDeadline)"
    );

    bytes32 constant REGISTER_PROPOSAL_TYPEHASH =
    keccak256(
        "RegisterProposal(address provider)"
    );

    struct TripProposal {
        address passenger;
        address driver;
        uint256 price;
        string origindata;
        string destinationData;
        uint16 sp_fee;
        uint16 up_fee;
        uint256 driverDeadline;
        uint256 passengerDeadline;
    }

    struct RegisterProposal {
        address provider;
    }

    struct EIP712Domain {
        string name;
        string version;
        uint256 chainId;
        address verifyingContract;
    }

    /*---------Events----------*/

    event TripStarted(uint256 indexed tripId, address sp, address up, address p, address d, uint256 amount);
    event TripEnded(uint256 indexed tripId, uint8 mode);
    event TripRated(uint256 indexed tripId, uint8 rate, address rater);
}