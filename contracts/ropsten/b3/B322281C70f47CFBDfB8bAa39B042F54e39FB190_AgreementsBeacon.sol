// SPDX-License-Identifier: Apache 2.0

pragma solidity ^0.8.1;

import "./agreements-beacon-interface.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract AgreementsBeacon is IAgreementsBeacon {
    using Address for address;
    using Strings for uint256;

    mapping(address => mapping(uint256 => Beacon)) private beacons;

    bytes32 private constant EVENT_NAMESPACE = "monax";
    bytes32 private constant EVENT_NAME_BEACON_STATE_CHANGE =
        "request:beacon-status-change";
    bytes32 private constant EVENT_NAME_REQUEST_CREATE_AGREEMENT =
        "request:create-agreement";
    bytes32 private constant EVENT_NAME_REPORT_AGREEMENT_STATUS =
        "report:agreement-status";

    uint256 public constant AGREEMENT_BEACON_PRICE = 1000; // TODO

    address[] private _owners;
    uint256 private _requestIndex;
    uint256 private _currentEventIndex;
    string private _baseUrl;

    modifier ownersOnly() {
        bool isOwner;
        for (uint256 i; i < _owners.length; i++) {
            if (msg.sender == _owners[i]) {
                isOwner = true;
            }
        }
        require(isOwner, "Sender must be a contract owner");
        _;
    }

    modifier requireCharge() {
        uint256 price = AGREEMENT_BEACON_PRICE;
        require(msg.value >= price, "Insufficient funds for operation");
        _;
    }

    modifier isBeaconActivated(address tokenContractAddress, uint256 tokenId) {
        require(
            beacons[tokenContractAddress][tokenId].activated,
            "Beacon not activated"
        );
        _;
    }

    modifier addEvent(uint256 eventCount) {
        _;
        _currentEventIndex += eventCount;
    }

    modifier addRequestIndex() {
        _;
        _requestIndex += 1;
    }

    constructor(address[] memory _o) {
        require(_o.length > 0, "> 1 owner required");
        _requestIndex = 1;
        _owners = _o;
        _baseUrl = string(
            abi.encodePacked(
                "https://agreements.zone/ethereum/",
                block.chainid.toString(),
                "/{tokenContractAddress}/{id}"
            )
        );
    }

    function requestCreateBeacon(
        address tokenContractAddress,
        uint256 tokenId,
        bytes32 templateId,
        string memory templateConfig
    ) external payable virtual override requireCharge() {
        require(
            beacons[tokenContractAddress][tokenId].creator == address(0),
            "Request limit reached"
        );
        beacons[tokenContractAddress][tokenId].creator = msg.sender;
        beacons[tokenContractAddress][tokenId].templateId = templateId;
        beacons[tokenContractAddress][tokenId].templateConfig = templateConfig;
        beacons[tokenContractAddress][tokenId].activated = true;
        _emitBeaconStateChange(
            tokenContractAddress,
            tokenId,
            templateId,
            templateConfig,
            true
        );
    }

    function requestUpdateBeacon(
        address tokenContractAddress,
        uint256 tokenId,
        bytes32 templateId,
        string memory templateConfig,
        bool activated
    ) external payable virtual override requireCharge() {
        require(
            beacons[tokenContractAddress][tokenId].creator == msg.sender,
            "You do not own me"
        );
        beacons[tokenContractAddress][tokenId].templateId = templateId;
        beacons[tokenContractAddress][tokenId].templateConfig = templateConfig;
        beacons[tokenContractAddress][tokenId].activated = activated;
        _emitBeaconStateChange(
            tokenContractAddress,
            tokenId,
            templateId,
            templateConfig,
            activated
        );
    }

    function requestCreateAgreement(
        address tokenContractAddress,
        uint256 tokenId,
        address[] memory accepters
    )
        external
        payable
        virtual
        override
        requireCharge()
        isBeaconActivated(tokenContractAddress, tokenId)
        addRequestIndex()
    {
        for (uint256 i = 0; i < accepters.length; i++) {
            address accepter = accepters[i];
            if (
                beacons[tokenContractAddress][tokenId].agreements[accepter]
                    .requestIndex != 0
            ) {
                continue;
            }
            beacons[tokenContractAddress][tokenId].agreements[accepter]
                .creator = beacons[tokenContractAddress][tokenId].creator;
            beacons[tokenContractAddress][tokenId].agreements[accepter]
                .accepter = accepter;
            beacons[tokenContractAddress][tokenId].agreements[accepter]
                .state = LegalState.FORMULATED;
            beacons[tokenContractAddress][tokenId].agreements[accepter]
                .requestIndex = _requestIndex;
            _emitCreateAgreementRequest(
                tokenContractAddress,
                tokenId,
                accepter
            );
        }
    }

    function reportAgreementStatus(
        address tokenContractAddress,
        uint256 tokenId,
        address accepter,
        address agreement,
        LegalState state,
        string memory errorCode
    ) external virtual override ownersOnly() {
        if (
            beacons[tokenContractAddress][tokenId].agreements[accepter]
                .agreement == address(0)
        ) {
            beacons[tokenContractAddress][tokenId].agreements[accepter]
                .agreement = agreement;
            beacons[tokenContractAddress][tokenId].agreements[accepter]
                .state = state;
            beacons[tokenContractAddress][tokenId].agreements[accepter]
                .errorCode = errorCode;
        } else {
            beacons[tokenContractAddress][tokenId].agreements[accepter]
                .state = state;
        }
        beacons[tokenContractAddress][tokenId].agreements[accepter]
            .currentBlockHeight = block.number;
        beacons[tokenContractAddress][tokenId].agreements[accepter]
            .currentEventIndex = _currentEventIndex;
        _emitAgreementStatus(tokenContractAddress, tokenId, accepter);
    }

    function getBeaconURL(address tokenContractAddress, uint256 tokenId)
        external
        view
        virtual
        override
        isBeaconActivated(tokenContractAddress, tokenId)
        returns (string memory)
    {
        return _baseUrl;
    }

    function getBeaconCreator(address tokenContractAddress, uint256 tokenId)
        external
        view
        virtual
        override
        isBeaconActivated(tokenContractAddress, tokenId)
        returns (address creator)
    {
        return beacons[tokenContractAddress][tokenId].creator;
    }

    function getAgreementId(
        address tokenContractAddress,
        uint256 tokenId,
        address accepter
    )
        external
        view
        virtual
        override
        isBeaconActivated(tokenContractAddress, tokenId)
        returns (address agreement)
    {
        return
            beacons[tokenContractAddress][tokenId].agreements[accepter]
                .agreement;
    }

    function getAgreementStatus(
        address tokenContractAddress,
        uint256 tokenId,
        address accepter
    )
        external
        view
        virtual
        override
        isBeaconActivated(tokenContractAddress, tokenId)
        returns (LegalState state)
    {
        return
            beacons[tokenContractAddress][tokenId].agreements[accepter].state;
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override
        returns (bool)
    {
        return interfaceId == type(IAgreementsBeacon).interfaceId;
    }

    function _emitBeaconStateChange(
        address tokenContractAddress,
        uint256 tokenId,
        bytes32 templateId,
        string memory templateConfig,
        bool activated
    ) private addEvent(1) {
        emit LogBeaconStatusChange(
            EVENT_NAMESPACE,
            EVENT_NAME_BEACON_STATE_CHANGE,
            msg.sender,
            tx.origin, // solhint-disable-line avoid-tx-origin
            tokenContractAddress,
            tokenId,
            templateId,
            templateConfig,
            activated,
            block.number,
            _currentEventIndex
        );
    }

    function _emitCreateAgreementRequest(
        address tokenContractAddress,
        uint256 tokenId,
        address accepter
    ) private addEvent(1) {
        emit LogRequestCreateAgreement(
            EVENT_NAMESPACE,
            EVENT_NAME_REQUEST_CREATE_AGREEMENT,
            msg.sender,
            tx.origin, // solhint-disable-line avoid-tx-origin
            tokenContractAddress,
            tokenId,
            accepter,
            beacons[tokenContractAddress][tokenId].agreements[accepter]
                .requestIndex,
            block.number,
            _currentEventIndex
        );
    }

    function _emitAgreementStatus(
        address tokenContractAddress,
        uint256 tokenId,
        address accepter
    ) private addEvent(1) {
        emit LogAgreementStatus(
            EVENT_NAMESPACE,
            EVENT_NAME_REPORT_AGREEMENT_STATUS,
            beacons[tokenContractAddress][tokenId].agreements[accepter]
                .agreement,
            beacons[tokenContractAddress][tokenId].agreements[accepter].state,
            beacons[tokenContractAddress][tokenId].agreements[accepter]
                .errorCode,
            beacons[tokenContractAddress][tokenId].agreements[accepter]
                .requestIndex,
            block.number,
            _currentEventIndex
        );
    }
}