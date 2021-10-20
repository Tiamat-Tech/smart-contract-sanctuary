// SPDX-License-Identifier: Unlicensed

pragma solidity ^0.8.7;

import "./Interfaces.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/finance/PaymentSplitter.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/PullPayment.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/Multicall.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./upgrade/AddressesProvider.sol";
import "./upgrade/openzeppelin-upgradeability/VersionedInitializable.sol";

contract Registry is IRegistry, AccessControl, VersionedInitializable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // bytes32 public constant REGISTRY_ADMIN_ROLE = keccak256("REGISTRY_ADMIN_ROLE");
    bytes32 public constant OWNER_ROLE = keccak256("OWNER_ROLE");

    mapping(address => REGISTRATION) private registry;
    // hash of request used as id => service request
    mapping(uint256 => SERVICE_REQUEST) private services;

    // list of request ids for user
    mapping(address => uint256[]) requestIds;

    mapping(uint256 => SERVICE_DATA[]) private serviceData;

    mapping(uint256 => bool) private serviceFulfilled;

    mapping(uint256 => SERVICE_CHARGE) private servicePayments;

    uint256 public cutPerMillion;
    uint256 public constant maxCutPerMillion = 100000; // 10% of 1 million

    IERC20 public acceptedToken;

    /// EVENTS
    event ChangedFeePerMillion(uint256 share);
    event Registration(uint256 accountType, address account);
    event Request(uint256 requestId);
    event RequestUpdate(uint256 indexed requestId, bool fulfilled);
    event PaymentWithdrawn(uint256 indexed requestId, address indexed account);
    event FeeWithdrawn(uint256 amount, address indexed account);
    event UserRegistrationUpdated(address indexed account, bool approve);

    // upgradeability via proxy and delegate call
    AddressesProvider public addressesProvider;
    uint256 public constant REGISTRY_REVISION = 0x1;

    function getRevision() internal override pure returns (uint256) {
        return REGISTRY_REVISION;
    }

    /**
    * @dev this function is invoked by the proxy contract when 
    * the Registry contract is added to the AddressesProvider.
    * @param _addressesProvider the address of the AddressesProvider registry
    **/
    function initialize(AddressesProvider _addressesProvider, address _acceptedToken, address _admin) public initializer {
        addressesProvider = _addressesProvider;
        _setupRole(DEFAULT_ADMIN_ROLE, _admin);
        _setupRole(OWNER_ROLE, _admin);
        acceptedToken = IERC20(_acceptedToken);
    }
    
    // The smart contract is upgradeable with above function
    /* constructor(address _acceptedToken) {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(OWNER_ROLE, msg.sender);
        acceptedToken = IERC20(_acceptedToken);
    } */

    modifier onlyOwners() {
        require(
            hasRole(OWNER_ROLE, _msgSender()),
            "Caller does not have the OWNER_ROLE"
        );
        _;
    }

    function setOwnerCutPerMillion(uint256 _cutPerMillion)
        external
        override
        onlyOwners
    {
        require(
            _cutPerMillion > 0 && _cutPerMillion <= maxCutPerMillion,
            "setOwnerCutPerMillion: the owner cut should be between 0 and maxCutPerMillion"
        );

        cutPerMillion = _cutPerMillion;
        emit ChangedFeePerMillion(cutPerMillion);
    }

    function register(uint256 accountType, address onBehalfOf)
        external
        override
    {
        require(
            uint256(ACCOUNT_TYPE.SATTELITE) >= accountType,
            "register: invalid account type"
        );
        
        REGISTRATION storage r = registry[onBehalfOf];

        // satellite wallet is normal EOA managed by external user
        if (onBehalfOf != _msgSender()) {
            require(onBehalfOf != address(0), "register: cannot register zero address");
            r.user = onBehalfOf;
        } else {
            r.user = _msgSender();
        }
        require(r.approved == false, "register: address is already registered");
        r.acc_type = ACCOUNT_TYPE(accountType);

        if(hasRole(OWNER_ROLE, _msgSender())) {
            r.approved = true;
        }
        
        emit Registration(accountType, r.user);
    }

    function hashServiceRequest(SERVICE_REQUEST calldata serviceRequest)
        external
        pure
        override
        returns (uint256)
    {
        require(serviceRequest.timestamp != 0, "hashServiceRequest: invalid timestamp");
        return
            uint256(
                keccak256(
                    abi.encode(
                        serviceRequest.user,
                        serviceRequest.satellite,
                        serviceRequest.descriptionHash,
                        serviceRequest.timestamp
                    )
                )
            );
    }

    // called by satellite wallet or satellite admin
    function newServiceRequest(
        uint256 requestId,
        uint256 amount,
        SERVICE_REQUEST memory serviceRequest
    ) external override {
        SERVICE_REQUEST storage s = services[requestId];
        require(
            s.user == address(0) && s.satellite == address(0),
            "newServiceRequest: request already added"
        );

        s.user = serviceRequest.user;
        s.satellite = serviceRequest.satellite;
        s.descriptionHash = serviceRequest.descriptionHash;
        s.timestamp = serviceRequest.timestamp;
        require(s.timestamp != 0, "newServiceRequest: invalid timestamp");

        // client and satellite users must be registered
        require(registry[s.user].approved, "newServiceRequest: user must be fully registered");
        require(registry[s.satellite].approved, "newServiceRequest: satellite user must be fully registered");

        // make payment for service here

        require(amount != 0, "newServiceRequest: invalid amount");

        uint256 saleShareAmount;

        if (cutPerMillion > 0) {
            // Calculate sale share
            saleShareAmount = amount.mul(cutPerMillion).div(1e6);
        }
        servicePayments[requestId] = SERVICE_CHARGE({
            amount: amount.sub(saleShareAmount), // amount for satellite EOA
            fee: saleShareAmount, // fee so platform/SpaceChain
            amountWithdrawn: false,
            feeWithdrawn: false
        });

        acceptedToken.safeTransferFrom(
            _msgSender(),
            address(this), 
            amount
        );

        emit Request(requestId);
    }

    function updateServiceRequest(
        uint256 requestId,
        SERVICE_DATA[] memory data,
        bool fulfilled
    ) external override onlyOwners {
        SERVICE_DATA[] storage s = serviceData[requestId];
        if (data.length > 0) {
            for (uint256 i = 0; i < data.length; i++) {
                s.push(data[i]);
            }
        }
        serviceFulfilled[requestId] = fulfilled;

        emit RequestUpdate(requestId, fulfilled);
    }

    // deregisteration flow from user side. 
    function deRegister(bool approve)
        external
    {
        if (!approve) {
            registry[_msgSender()].approved = approve;
            emit UserRegistrationUpdated(_msgSender(), approve);
        }
    }
    
    
    // Admin can deregister user or set approved to false
    function updateUserRegistration(address clientOrSatellite, bool approve)
        external
        override
        onlyOwners
    {
        REGISTRATION memory s = getAccount(clientOrSatellite);
        if (!approve) {
            registry[clientOrSatellite].approved = approve;
        } else {
            if (s.acc_type == ACCOUNT_TYPE.CLIENT) {
                registry[clientOrSatellite].approved = approve;
                registry[clientOrSatellite].approvedBy[0] = _msgSender();
            } else {
                if (registry[clientOrSatellite].approvedBy[0] == address(0)) {
                    registry[clientOrSatellite].approvedBy[0] = _msgSender();
                } else {
                    if (
                        registry[clientOrSatellite].approvedBy[1] == address(0) && 
                        registry[clientOrSatellite].approvedBy[0] != _msgSender()
                    ) {
                        registry[clientOrSatellite].approvedBy[1] = _msgSender();
                    }
                }
                registry[clientOrSatellite].approved = approve;

                if (
                    registry[clientOrSatellite].approvedBy[1] == address(0) ||
                    registry[clientOrSatellite].approvedBy[0] == address(0)
                ) {
                    registry[clientOrSatellite].approved = false;
                }
            }
        }
        
        emit UserRegistrationUpdated(clientOrSatellite, approve);
    }

    function withdrawServicePayment(uint256 requestId, address to)
        external
        override
    {
        require(serviceFulfilled[requestId], "withdrawServicePayment: service not yet fulfilled");
        SERVICE_REQUEST memory s = services[requestId];
        require(_msgSender() == s.satellite, "withdrawServicePayment: invalid msg.sender, caller must be satellite");
        SERVICE_CHARGE storage c = servicePayments[requestId];
        uint256 amount = c.amount;
        c.amount = 0;

        if (!c.amountWithdrawn && amount > 0) {
            if (to == address(0)) {
                acceptedToken.safeTransfer(_msgSender(), amount);
                emit PaymentWithdrawn(requestId, _msgSender());
            } else {
                acceptedToken.safeTransfer(to, amount);
                emit PaymentWithdrawn(requestId, to);
            }
        }

        c.amountWithdrawn = true;
    }

    function withdrawServiceFee(uint256 requestId, address to) 
        external
        override
        onlyOwners
    {
        require(serviceFulfilled[requestId], "withdrawServiceFee: service not yet fulfilled");
        SERVICE_CHARGE storage c = servicePayments[requestId];
        uint256 amount = c.fee;
        c.fee = 0;
        if (!c.feeWithdrawn && amount > 0) {
            if (to == address(0)) {
                acceptedToken.safeTransfer(_msgSender(), amount);
                emit FeeWithdrawn(amount, _msgSender());
            } else {
                acceptedToken.safeTransfer(to, amount);
                emit FeeWithdrawn(amount, to);
            }
        }

        c.feeWithdrawn = true;
    }

    function getAccount(address account)
        public
        view
        returns (REGISTRATION memory)
    {
        return registry[account];
    }

    function getService(uint256 requestId)
        public
        view
        returns (SERVICE_REQUEST memory)
    {
        return services[requestId];
    }

    function getServicePayment(uint256 requestId)
        public
        view
        returns (SERVICE_CHARGE memory)
    {
        return servicePayments[requestId];
    }

    function isServiceFulfilled(uint256 requestId) public view returns (bool) {
        return serviceFulfilled[requestId];
    }
}