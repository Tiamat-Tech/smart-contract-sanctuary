pragma solidity ^0.8.7;

import "./Interfaces.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DSARegistry is IRegistry, AccessControl {
    using Address for address;

    address payable public SpaceChain;
    IERC20 public acceptedToken;

    bytes32 public constant OWNER_ROLE = keccak256("OWNER_ROLE");

    mapping(address => bool) public blacklist;
    mapping(address => REGISTRATION) private registry;

    REGISTRATION[] private registerArray;
    DATA[] private dataArray;

    mapping(address => uint256) private registerIndex;
    // hash of request used as id => data request
    mapping(uint256 => REQUEST) private requests;

    // list of request ids for user
    mapping(address => uint256[]) requestIds;
    // hash of request used as id => IPFS hash
    mapping(uint256 => bytes32) private requestDatasets;
    // dataset name => DATA
    mapping(bytes32 => DATA) private datasets;
    mapping(uint256 => PAYMENT) private payments;

    uint256 public cutPerMillion;
    uint256 public constant maxCutPerMillion = 20000; // 10% of 1 million

    uint256 registryArrayIndex;
    uint256 dataArrayIndex;

    receive() payable external {}

    constructor(address _SpaceChain, address _acceptedToken) {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(OWNER_ROLE, msg.sender);
        acceptedToken = IERC20(_acceptedToken);
        SpaceChain = payable(_SpaceChain);
    }

    /**
     * This function will register new general or enterprise users
     * @param accountType 0 for general and 1 for enterprise 
     * @param onBehalfOf The address to register
     */
    function register(uint8 accountType, address onBehalfOf)
        external
        override
    {
        require(!blacklist[onBehalfOf], "cannot register a blacklisted address");
        require(
            uint256(ACCOUNT_TYPE.ENTERPRISE) >= accountType,
            "register: invalid account type"
        );
        
        REGISTRATION storage r = registry[onBehalfOf];

        // if user is already registered, they can only re-register with a different account type
        // to switch accounts
        if ((r.user != address(0)) && (r.approved)) {
            require(accountType != uint256(r.acc_type), "register: address is already registered");
        } else if ((r.user == address(0)) && (!r.approved)) {
            // only create new array element for fresh accounts
            // enterprise wallets will be duplicated otherwise because their
            // approved is false but r.user is not address(0)
            // which is opposite of if case where user is not switching 
            // accounts but waiting approval and calls register again
            r.arrayIndex = registryArrayIndex++;
            registerArray.push(r);
            registerIndex[onBehalfOf] = r.arrayIndex;
        }

        // ENTERPRISE wallet is normal EOA managed by external user
        if (onBehalfOf != msg.sender) {
            require(onBehalfOf != address(0), "register: cannot register zero address");
            r.user = onBehalfOf;
        } else {
            r.user = onBehalfOf;
        }
        
        r.approved = false;

        // if user is client type, register them
        if (ACCOUNT_TYPE(accountType) == ACCOUNT_TYPE.GENERAL) {
            r.approved = true;
            r.pending = false;
        }

        if (ACCOUNT_TYPE(accountType) == ACCOUNT_TYPE.ENTERPRISE) {
            r.pending = true;
        }
        
        r.acc_type = ACCOUNT_TYPE(accountType);

        if(hasRole(OWNER_ROLE, msg.sender)) {
            r.approved = true;
            r.pending = false;
        }

        registerArray[registerIndex[onBehalfOf]] = r;        
        emit Registration(accountType, r.user);
    }

    modifier onlyOwners() {
        require(
            hasRole(OWNER_ROLE, msg.sender),
            "Caller does not have the OWNER_ROLE"
        );
        _;
    }

    /**
     * This function will create a hash of the service request.
     * To make each data request unique with a unique id generated from
     * the resulting hash
     * @param request The dadta/service request to hash.
     */
    function hashDataRequest(REQUEST memory request)
        external
        view
        override
        returns (uint256)
    {
        require(request.timestamp >= block.timestamp, "hashDataRequest: invalid timestamp");
        return
            uint256(
                keccak256(
                    abi.encode(
                        request.user,
                        request.enterprise,
                        request.descriptionHash,
                        request.timestamp
                    )
                )
            );
    }

    /**
     * This function will add an address to the blacklist.
     * Preventing the address from interacting with other functions of the contract
     * @param account The address to blacklist
     * @param blocked bool true to block and false to unblock
     */
    function updateBlackList(address account, bool blocked)
        external
        override
        onlyOwners
    {
        blacklist[account] = blocked;
        REGISTRATION memory s = getAccount(account);
        // if user is registered, update account at array index
        if (s.user != address(0)) {
            registerArray[registerIndex[account]].blacklisted = blocked;
        }
        emit BlacklistUpdated(account, blocked);
    }

    /**
     * This function will create and store details related to a new data
     * request, e.g., payment information and ipfs Hash
     * Note: It will also collect payment from user using ERC-20 transferFrom() function
     * so user must have approved this smart contract for the amount to pay
     * before calling this function by calling 
     * approve(spender, amount) on the ERC-20 contract for acceptedToken above
     * Note: This function calls uploadData() function in this contract which is a public function
     * used to store the IPFS hash of the purchased dataset and callable by this contract itself or admin
     * @param requestId The request id
     * @param request Data request information
     * @param datasetName unique id of dataset
     */
    function newDataRequest(
        uint256 requestId,
        REQUEST memory request,
        bytes32 datasetName
    ) external payable override {
        require(!blacklist[msg.sender], "cannot create request with blacklisted address");

        REQUEST storage s = requests[requestId];
        require(
            s.user == address(0) && s.enterprise == address(0),
            "newDataRequest: request already added"
        );

        s.user = request.user;
        s.enterprise = request.enterprise;
        s.descriptionHash = request.descriptionHash;
        s.timestamp = request.timestamp;
        require(s.timestamp != 0, "newDataRequest: invalid timestamp");

        bytes32 ipfsHash = datasets[datasetName].ipfsHash;
        uploadDataForRequest(requestId, ipfsHash);

        // client and enterprise users must be registered
        require(
            registry[s.user].approved && 
            registry[s.enterprise].approved, 
            "newDataRequest: user and enterprise must be fully registered"
        );
        // make payment for service here
        require(msg.value == datasets[datasetName].amount, "dataset amount not equal to msg.value");

        acceptedToken.transferFrom(
            msg.sender,
            address(this), 
            datasets[datasetName].amount
        );

        uint256 saleShareAmount;
        if (cutPerMillion > 0) {
            // Calculate sale share
            saleShareAmount = (datasets[datasetName].amount * cutPerMillion) / 1e6;
        }

        uint256 enterpriseAmount = datasets[datasetName].amount - saleShareAmount;
        if (s.enterprise == datasets[datasetName].uploader) {
            acceptedToken.transfer(
                s.enterprise, 
                enterpriseAmount
            );
            payments[requestId] = PAYMENT({
                enterpriseFee: enterpriseAmount, // amount for enterprise EOA
                adminFee: saleShareAmount, // fees to platform/SpaceChain
                adminFeeWithdrawn: false,
                enterpriseFeeWithdrawn: true
            });
        } else {
            payments[requestId] = PAYMENT({
                enterpriseFee: enterpriseAmount, // amount for enterprise EOA
                adminFee: saleShareAmount, // fees to platform/SpaceChain
                adminFeeWithdrawn: false,
                enterpriseFeeWithdrawn: false
            });
        }
        emit NewRequest(requestId);
    }

    /**
     * This function will store IPFS hash associated with the request Id
     * after receiving payment.
     * The function is only callable by this contract or admins
     * to update the stored ipfs hash in the case of any issues
     * or update to the dataset associated with a request id
     * @param requestId The request id
     * @param ipfsHash IPFS hash
     */
    function uploadDataForRequest (
        uint256 requestId,
        bytes32 ipfsHash
    ) public override {
        require(
            msg.sender == address(this) ||
            hasRole(OWNER_ROLE, msg.sender),
            "uploadData: invalid msg.sender, caller must be this smart contract or admin"
        );
        require(ipfsHash.length != 0, "ipfs hash length is 0");
        require(ipfsHash != 0x0, "invalid ipfs hash");
        requestDatasets[requestId] = ipfsHash;
        emit RequestDatasetUpdated(requestId);
    }

    function uploadDataset(uint256 amount, bytes32 datasetName, bytes32 ipfsHash, address enterpriseOwner) external override {
        REGISTRATION storage r = registry[msg.sender];

        require(amount > 0, "cannot charge 0 for dataset");
        require(ipfsHash.length != 0, "ipfs hash length is 0");
        require(ipfsHash != 0x0, "invalid ipfs hash");
        require(datasetName.length != 0, "datasetName hash length is 0");
        require(datasetName != 0x0, "invalid dataset name");
        
        require(enterpriseOwner != address(0), "cannot store zero address for dataset owner");

        require(
            r.acc_type == ACCOUNT_TYPE.ENTERPRISE ||
            hasRole(OWNER_ROLE, msg.sender),
            "uploadData: invalid msg.sender, caller must be enterprise or admin"
        );

        if (datasets[datasetName].ipfsHash == 0x0) {
            // add to array index to include in getAllDatasets()
            datasets[datasetName].arrayIndex = dataArrayIndex++;
            dataArray.push(datasets[datasetName]);
        }

        datasets[datasetName].amount = amount;
        datasets[datasetName].ipfsHash = ipfsHash;
        
        if (hasRole(OWNER_ROLE, msg.sender)) {
            datasets[datasetName].admin = msg.sender;
            datasets[datasetName].uploader = enterpriseOwner;
        } else {
            // enterprise can upload dataset for another enterprise
            // of might belong to same group
            datasets[datasetName].uploader = enterpriseOwner;
        }

        emit NewDatasetCreated(amount, datasetName);
    }

    /**
     * This function will either be used to approve or block/stop a users registration
     * It is only callable by admins to approve enterprise user type
     * @param clientOrEnterprise The address to approve or block
     * @param approve true or false
     */
    function updateUserRegistration(address clientOrEnterprise, bool approve)
        external
        override
        onlyOwners
    {
        REGISTRATION storage r = registry[clientOrEnterprise];
        if (!approve) {
            require(r.approved == true, "updateUserRegistration: user registration already deactivated");
            r.approved = approve;
            r.pending = false;
            r.approvedBy[0] = address(0);
            r.approvedBy[1] = address(0);
        } else {
            require(r.approved == false, "updateUserRegistration: user registration already approved/activated");
            if (r.acc_type == ACCOUNT_TYPE.GENERAL) {
                r.pending = false;
                r.approved = approve;
                r.approvedBy[0] = msg.sender;
            } else {
                if (r.approvedBy[0] == address(0)) {
                    r.approvedBy[0] = msg.sender;
                } else {
                    if (
                        r.approvedBy[1] == address(0) && 
                        r.approvedBy[0] != msg.sender
                    ) {
                        r.approvedBy[1] = msg.sender;
                    }
                }
                r.approved = approve;

                if (
                    r.approvedBy[1] == address(0) ||
                    r.approvedBy[0] == address(0)
                ) {
                    r.approved = false;
                    r.pending = true;
                } else if (
                    r.approvedBy[1] != address(0) &&
                    r.approvedBy[0] != address(0)
                ) {
                    r.approved = approve;
                    r.pending = false;
                }
            }
        }
        
        registerArray[registerIndex[clientOrEnterprise]] = r;

        emit UserRegistrationUpdated(clientOrEnterprise, approve);
    }

    /**
     * This function will enable users to deregister themselves.
     * It will set approve status for user to false
     * @param approve true or false. User needs to specify false to deregister.
     */
    function removeRegistration(bool approve) external override {
        REGISTRATION storage r = registry[msg.sender];

        require(
            r.approved == true,
            "removeRegistration: registration already deactivated"
        );

        if (!approve) {
            registry[msg.sender].approved = approve;
            registry[msg.sender].pending = false;
            registry[msg.sender].approvedBy[0] = address(0);
            registry[msg.sender].approvedBy[1] = address(0);
            emit UserRegistrationUpdated(msg.sender, approve);
        }
        registerArray[registerIndex[msg.sender]] = r;
    }

    /**
     * This function will set the platform share of the fees paid for
     * IPFS data in the form of the accepted token.
     * @param _cutPerMillion owners share measured out of 1 million. E.g., 100,000
     * is 10% of 1 million so for every payment, SpaceChain will get 10%
     */
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

    /**
     * This function is used by enterprise user to withdraw or collect
     * payment made for their dataset by general user
     * Admin can also call in case enterprise wallet misplaces their account private key
     * or do not hold ether for gas fees
     * @param requestId The request id
     * @param to The wallet where they want the funds to go to
     */
    function withdrawEnterpriseFee(uint256 requestId, address to)
        external
        override
    {
        REQUEST memory s = requests[requestId];
        require(
            msg.sender == s.enterprise ||
            hasRole(OWNER_ROLE, msg.sender),
            "withdrawEnterpriseFee: invalid msg.sender, caller must be enterprise or admin"
        );
        PAYMENT storage c = payments[requestId];
        uint256 amount = c.enterpriseFee;
        c.enterpriseFee = 0;
        if (!c.enterpriseFeeWithdrawn && amount > 0) {
            if (to == address(0)) {
                acceptedToken.transfer(msg.sender, amount);
                emit PaymentWithdrawn(requestId, msg.sender);
            } else {
                acceptedToken.transfer(to, amount);
                emit PaymentWithdrawn(requestId, to);
            }
            c.enterpriseFeeWithdrawn = true;
        }
    }

    /**
     * This function is used by admins to withdraw or collect
     * percentage of payment made for dataset by general user
     * as fees for the platform. The funds are sent to SpaceChain wallet address
     * above. This address is only changeable by admins using the 
     * setSpaceChainWallet() function
     * @param requestId The request id
     */
    function withdrawAdminFee(uint256 requestId)
        external
        override
        onlyOwners
    {
        PAYMENT storage c = payments[requestId];
        uint256 amount = c.adminFee;
        c.adminFee = 0;
        require(SpaceChain != address(0), "spacechain address not set");
        if (!c.adminFeeWithdrawn && amount > 0) {
            acceptedToken.transfer(SpaceChain, amount);
            emit FeeWithdrawn(amount, SpaceChain);
            c.adminFeeWithdrawn = true;
        }
    }

    /**
     * This function is used by admins to update the
     * SpaceChain wallet used in collecting platform fees 
     * @param _spacechain The new SpaceChain wallet address
     */
    function setSpaceChainWallet(address _spacechain) external override onlyOwners {
        require(_spacechain != address(0), "setSpaceChainWallet: cannot set zero address");
        SpaceChain = payable(_spacechain);
    }

    function getAccount(address account)
        public
        view
        override
        returns (REGISTRATION memory)
    {
        return registry[account];
    }

    function getAllAccounts()
        external
        view
        override
        onlyOwners
        returns (REGISTRATION[] memory)
    {
        return registerArray;
    }

    function getAllDatasets()
        external
        view
        override
        onlyOwners
        returns (DATA[] memory)
    {
        return dataArray;
    }

    function getRequest(uint256 requestId)
        public
        view
        override
        returns (REQUEST memory)
    {
        return requests[requestId];
    }

    function getRequestData(uint256 requestId)
        external
        view
        override
        returns (bytes32 ipfsHash)
    {
        REQUEST memory sr = getRequest(requestId);
        require(
            msg.sender == sr.user ||
            hasRole(OWNER_ROLE, msg.sender),
            "only client or admin can access ipfs hash"
        );

        return requestDatasets[requestId];
    }

    function getData(bytes32 datasetName)
        external
        view
        override
        returns (bytes32 ipfsHash)
    {
        require(
            msg.sender == datasets[datasetName].uploader ||
            hasRole(OWNER_ROLE, msg.sender),
            "only client or admin can access ipfs hash"
        );

        return datasets[datasetName].ipfsHash;
    }

    function getPayment(uint256 requestId)
        public
        view
        override
        returns (PAYMENT memory)
    {
        REQUEST memory sr = getRequest(requestId);
        require(
            msg.sender == sr.user ||
            hasRole(OWNER_ROLE, msg.sender),
            "only client or admin can access ipfs hash"
        );

        return payments[requestId];
    }
}