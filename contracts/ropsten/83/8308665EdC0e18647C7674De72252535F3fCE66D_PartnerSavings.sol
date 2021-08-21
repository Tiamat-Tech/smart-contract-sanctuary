pragma solidity 0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract PartnerSavings {
    using EnumerableSet for EnumerableSet.UintSet;

    uint256 nextRequestId;

    IERC20 usdc;
    IERC20 partnerCoin;

    address public person1 = 0x1F7283bEDAB59e843bA6671A95417244b532C3e6;
    address public person2 = 0xa8d4852E23f7aC0767d69983f187C91810CDD295;

    struct Request {
        string title;
        string description;
        address vendorAddress;
        uint256 amount;
        address author;
        string status;
    }

    mapping(uint256 => Request) public requests;
    EnumerableSet.UintSet private requestIds;

    constructor(IERC20 _partnerCoin, IERC20 _usdc) {
        partnerCoin = _partnerCoin;
        usdc = _usdc;
    }

    function getAllRequests(uint256[] memory indices)
        external
        view
        returns (Request[] memory)
    {
        Request[] memory output = new Request[](requestIds.length());
        for (uint256 i = 0; i < requestIds.length(); i++) {
            output[i] = requests[i];
        }
        return output;
    }

    function makeRequest(
        string memory title,
        string memory description,
        address vendorAddress,
        uint256 amount
    ) public {
        require(
            msg.sender == person1 || msg.sender == person2,
            "Not authorized"
        );

        uint256 requestId = generateRequestId();
        requests[requestId] = Request(
            title,
            description,
            vendorAddress,
            amount,
            msg.sender,
            "pending"
        );
        requestIds.add(requestId);
    }

    function approveRequest(uint256 requestId) external {
        require(
            compareStrings(requests[requestId].status, "pending"),
            "Request is not pending"
        );
        require(
            msg.sender == person1 || msg.sender == person2,
            "Not authorized to make requests"
        );
        require(
            msg.sender != requests[requestId].author,
            "Cannot approve your own request"
        );

        compareStrings(requests[requestId].status, "approved");
        usdc.transfer(
            requests[requestId].vendorAddress,
            requests[requestId].amount
        );
    }

    function cancelRequest(uint256 requestId) external {
        require(
            compareStrings(requests[requestId].status, "pending"),
            "Request is not pending"
        );
        require(
            msg.sender == requests[requestId].author,
            "Cannot only cancel your own request"
        );
        requests[requestId].status = "canceled";
    }

    function declineRequest(uint256 requestId) external {
        require(
            compareStrings(requests[requestId].status, "pending"),
            "Request is not pending"
        );
        require(
            msg.sender == person1 || msg.sender == person2,
            "Not authorized to decline requests"
        );
        require(
            msg.sender != requests[requestId].author,
            "Cannot decline your own request"
        );
        requests[requestId].status = "declined";
    }

    function deposit(uint256 amount) external {
        usdc.transferFrom(msg.sender, address(this), amount);
        partnerCoin.transfer(msg.sender, 10**18);
    }

    function collectRewards(uint256 amount) external {}

    function generateRequestId() internal returns (uint256) {
        return nextRequestId++;
    }

    function compareStrings(string memory a, string memory b)
        public
        view
        returns (bool)
    {
        return (keccak256(abi.encodePacked((a))) ==
            keccak256(abi.encodePacked((b))));
    }
}