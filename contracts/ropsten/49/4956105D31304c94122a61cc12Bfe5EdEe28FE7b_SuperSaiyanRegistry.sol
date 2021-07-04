// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

import {
    ISuperfluid,
    ISuperToken,
    ISuperApp,
    ISuperAgreement,
    SuperAppDefinitions
} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import {
    IConstantFlowAgreementV1
} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/agreements/IConstantFlowAgreementV1.sol";
import {
    SuperAppBase
} from "@superfluid-finance/ethereum-contracts/contracts/apps/SuperAppBase.sol";

import "./ISuperSaiyanRegistry.sol";

contract SuperSaiyanRegistry is ISuperSaiyanRegistry, ERC1155, SuperAppBase {
    using Counters for Counters.Counter;

    // ******************************* SuperSaiyan vars *******************************

    mapping(uint256 => Service) private _services;
    mapping(address => Subscriber) private _subscribers;
    mapping(uint256 => Subscription) private _subscriptions;

    // @dev Helper mapping for getting the serviceId for a specific provider. In the current design one provider can
    // register one service. It is better to use serviceId to represent the service as it is more natural and also
    // could allow for more things in the future.
    mapping(address => uint256) private _serviceProviders;

    Counters.Counter private _subscriptionIds;
    Counters.Counter private _serviceIds;
    Counters.Counter private _numSubscribers;

    // Not needed, _serviceIds can be used for the tokenIds
    //    // ******************************* ERC1155 vars *******************************
    //
    //    // Mapping from provider's address to their token class id;
    //    // Each provider has a separate "token class". We can view the concept of "token class" as a ERC721, or in other words for each provider we have different ERC721.
    //    mapping(address => uint256) private _providerIds;
    //
    //    // Counter to track the number of token classes, as well as to derive the tokenId for the different token classes.
    //    // Increments when new token is minted for the first time for a specific provider.
    //    Counters.Counter private _tokenIds;
    //
    //    // ******************************* SuperFluid vars *******************************

    ISuperfluid private _host;
    IConstantFlowAgreementV1 private _cfa;
    ISuperToken private _acceptedToken;

    // ******************************* Provider name getters *******************************
    // In LR will not be needed as will perform ENS look up on provider name to get address.
    mapping(string => uint256) private _serviceProvidersNames;

    modifier serviceExists(string memory serviceName) {
        require(
            _serviceProvidersNames[serviceName] != 0,
            "SuperSaiyanRegistry: Service does not exists."
        );
        _;
    }

    constructor(
        ISuperfluid host,
        IConstantFlowAgreementV1 cfa,
        ISuperToken acceptedToken
    ) ERC1155("https://supersayian.xyz/api/nfts/{id}.json") {
        require(
            address(host) != address(0),
            "SuperSaiyanRegistry: SuperFluid host can't be the zero address."
        );
        require(
            address(cfa) != address(0),
            "SuperSaiyanRegistry: SuperFluid cfa can't be the zero address"
        );
        require(
            address(acceptedToken) != address(0),
            "SuperSaiyanRegistry: SuperFluid acceptedToken can't be the zero address"
        );

        _host = host;
        _cfa = cfa;
        _acceptedToken = acceptedToken;

        uint256 configWord =
            SuperAppDefinitions.APP_LEVEL_FINAL |
                SuperAppDefinitions.BEFORE_AGREEMENT_CREATED_NOOP |
                SuperAppDefinitions.BEFORE_AGREEMENT_UPDATED_NOOP |
                SuperAppDefinitions.BEFORE_AGREEMENT_TERMINATED_NOOP;

        _host.registerApp(configWord);

        // serviceIds starting from 1 (to save on gas costs with checks in the createService function).
        _serviceIds.increment();
    }

    // ******************************* ERC1155 functions *******************************

    function mint(address to, uint256 tokenId) private {
        _mint(to, tokenId, 1, "");
    }

    // ******************************* SuperFluid functions *******************************

    function afterAgreementCreated(
        ISuperToken superToken,
        address agreementClass,
        bytes32 agreementId,
        bytes calldata, /*agreementData*/
        bytes calldata, /*cbdata*/
        bytes calldata ctx
    )
        external
        override
        onlyExpected(superToken, agreementClass)
        onlyHost
        returns (bytes memory newCtx)
    {
        newCtx = ctx;
        ISuperfluid.Context memory contextDecoded = ISuperfluid(_host).decodeCtx(ctx);

        // the serviceId is passed as userData to the CFA agreement creation
        uint256 serviceId = abi.decode(contextDecoded.userData, (uint256));
        require(
            _services[serviceId].providerAddress != address(0),
            "SuperSaiyanRegistry: Service is not registered yet!"
        );

        // redirect flow
        (, int96 flowRate, , ) = _cfa.getFlowByID(_acceptedToken, agreementId);

        require(
            _services[serviceId].flowRate == uint96(flowRate),
            "SuperSaiyanRegistry: Service flow rate mismatch."
        );

        (newCtx, ) = _host.callAgreementWithContext(
            _cfa,
            abi.encodeWithSelector(
                _cfa.createFlow.selector,
                _acceptedToken,
                _services[serviceId].providerAddress,
                flowRate,
                new bytes(0)
            ),
            "0x",
            newCtx
        );

        // create subscription if flow was redirected successfully
        address subscriberAddr = contextDecoded.msgSender;
        uint256 subscriptionId = _subscriptionIds.current();
        _subscriptions[subscriptionId] = Subscription(
            subscriptionId,
            subscriberAddr,
            serviceId,
            SubscriptionStatus.STARTED
        );
        _subscriptionIds.increment();

        if (_services[serviceId].subscriptionIds.length == 0) {
            // no subscribers yet, this is the first subscriber => mint NFT
            mint(subscriberAddr, serviceId);
        }

        _services[serviceId].subscriptionIds.push(subscriptionId);

        // create subscriber if it doesn't exists
        if (_subscribers[subscriberAddr].subscriptionIds.length == 0) {
            uint256[] memory subscriptionIds;
            _subscribers[subscriberAddr] = Subscriber(subscriptionIds);
            _numSubscribers.increment();
        }

        _subscribers[subscriberAddr].subscriptionIds.push(subscriptionId);
    }

    // TODO
    function afterAgreementUpdated(
        ISuperToken superToken,
        address agreementClass,
        bytes32 agreementId,
        bytes calldata agreementData,
        bytes calldata cbdata,
        bytes calldata ctx
    )
        external
        override
        onlyExpected(superToken, agreementClass)
        onlyHost
        returns (bytes memory newCtx)
    {}

    // TODO
    function afterAgreementTerminated(
        ISuperToken superToken,
        address agreementClass,
        bytes32 agreementId,
        bytes calldata agreementData,
        bytes calldata cbdata,
        bytes calldata ctx
    ) external override onlyHost returns (bytes memory newCtx) {}

    modifier onlyHost() {
        require(
            msg.sender == address(_host),
            "SuperSaiyanRegistry: Only one SuperFluid host is supported."
        );
        _;
    }

    function _isSameToken(ISuperToken superToken) private view returns (bool) {
        return address(superToken) == address(_acceptedToken);
    }

    function _isCFAv1(address agreementClass) private view returns (bool) {
        return
            ISuperAgreement(agreementClass).agreementType() ==
            keccak256("org.superfluid-finance.agreements.ConstantFlowAgreement.v1");
    }

    modifier onlyExpected(ISuperToken superToken, address agreementClass) {
        require(_isSameToken(superToken), "SuperSaiyanRegistry: Token not accepted.");
        require(_isCFAv1(agreementClass), "SuperSaiyanRegistry: Only CFAv1 supported.");
        _;
    }

    // ******************************* ISuperSaiyanRegistry implementation *******************************

    /**
     * @dev Create a service for provider. Revert if service with the same providerAddress and same token exists.
     */
    function createService(
        address providerAddress,
        string memory name,
        address token,
        uint256 amount,
        uint256 intervalSeconds
    ) external override {
        // serviceId counter starts from 1, so this check below is safe
        require(
            _serviceProviders[providerAddress] == 0,
            "SuperSaiyanRegistry: Service for the provider already exists."
        );
        require(token == address(_acceptedToken), "SuperSaiyanRegistry: Token not allowed."); // To be removed in the future.
        require(amount > 0, "SuperSaiyanRegistry: Amount should be greater than 0.");
        require(
            intervalSeconds > 0,
            "SuperSaiyanRegistry: The subscription interval should be greater than 0."
        );
        require(bytes(name).length > 0, "SuperSaiyanRegistry: Service name cannot be empty.");

        uint256 serviceId = _serviceIds.current();
        uint256[] memory subscriptionIds;

        address[] memory acceptedTokens = new address[](1);
        acceptedTokens[0] = token;

        uint256 flowRate = amount / intervalSeconds; // the flow rate is expressed as amount per second

        _services[serviceId] = Service(
            subscriptionIds,
            name,
            providerAddress,
            acceptedTokens,
            amount,
            intervalSeconds,
            flowRate
        );
        _serviceProviders[providerAddress] = serviceId;

        _serviceProvidersNames[name] = serviceId;

        emit ServiceCreated(serviceId, providerAddress, name, amount, intervalSeconds, flowRate);
        _serviceIds.increment();
    }

    /**
     * @dev Get the number of subscriptions in the system
     */
    function getNumSubscriptions() external view override returns (uint256 numSubscriptions) {
        numSubscriptions = _subscriptionIds.current();
    }

    /**
     * @dev Get the number of services in the system
     */
    function getNumServices() external view override returns (uint256 numServices) {
        numServices = _serviceIds.current() - 1;
    }

    /**
     * @dev Get the number of subscribers in the system
     */
    function getNumSubscribers() external view override returns (uint256 numSubscribers) {
        numSubscribers = _numSubscribers.current();
    }

    /**
     * @dev Get subscription by id.
     */
    function getSubscription(uint256 subscriptionId)
        external
        view
        override
        returns (Subscription memory subscription)
    {
        subscription = _subscriptions[subscriptionId];
    }

    /**
     * @dev Get service by id.
     */
    function getService(uint256 serviceId)
        external
        view
        override
        returns (Service memory service)
    {
        service = _services[serviceId];
    }

    /**
     * @dev Get subscriber by address.
     */
    function getSubscriber(address subscriberAddr)
        external
        view
        override
        returns (Subscriber memory subscriber)
    {
        subscriber = _subscribers[subscriberAddr];
    }

    /**
     * @dev Get service by name.
     */
    function getServiceByName(string memory name)
        external
        view
        override
        serviceExists(name)
        returns (Service memory service, uint256 serviceId)
    {
        serviceId = _serviceProvidersNames[name];
        service = _services[serviceId];
    }

    /**
     * @dev Get service by provider address.
     */
    function getServiceByProviderAddress(address provider)
        external
        view
        override
        returns (Service memory service, uint256 serviceId)
    {
        serviceId = _serviceProviders[provider];
        service = _services[serviceId];
    }
}