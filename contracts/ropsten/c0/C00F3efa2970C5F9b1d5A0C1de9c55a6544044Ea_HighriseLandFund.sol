// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "ECDSA.sol";
import "ERC165Checker.sol";

import "IHighriseLand.sol";

contract HighriseLandFund {
    using ERC165Checker for address;
    using ECDSA for bytes32;

    event FundLandEvent(
        address indexed sender,
        uint256 fundAmount,
        string reservationId
    );

    enum FundState {
        ENABLED,
        DISABLED
    }

    address public owner;
    address landContract;

    // mapping to store which address deposited how much ETH
    mapping(address => uint256) public addressToAmountFunded;
    // token price in wei
    uint256 public landTokenPrice;
    FundState fundState;

    constructor(uint256 _landTokenPrice, address _landContract) {
        require(
            _landContract.supportsInterface(type(IHighriseLand).interfaceId),
            "IS_NOT_HIGHRISE_LAND_CONTRACT"
        );
        owner = msg.sender;
        landTokenPrice = _landTokenPrice;
        fundState = FundState.DISABLED;
        landContract = _landContract;
    }

    modifier validAmount() {
        require(
            msg.value >= landTokenPrice,
            "Not enough ETH to pay for tokens"
        );
        _;
    }

    modifier enabled() {
        require(
            fundState == FundState.ENABLED,
            "Contract not enabled for funding"
        );
        _;
    }

    function fund(bytes memory data, bytes memory signature)
        public
        payable
        enabled
        validAmount
    {
        require(_verify(keccak256(data), signature, owner));
        (uint256 tokenId, uint256 expiry) = abi.decode(
            abi.encodePacked(data),
            (uint256, uint256)
        );
        require(expiry > block.timestamp, "Reservation expired");
        addressToAmountFunded[msg.sender] += msg.value;
        (IHighriseLand(landContract)).mint(msg.sender, 1);
        emit FundLandEvent(msg.sender, msg.value, "");
    }

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    function enable() public onlyOwner {
        fundState = FundState.ENABLED;
    }

    function disable() public onlyOwner {
        fundState = FundState.DISABLED;
    }

    modifier disabled() {
        require(
            fundState == FundState.DISABLED,
            "Disable contract before withdrawing"
        );
        _;
    }

    function withdraw() public onlyOwner disabled {
        payable(msg.sender).transfer(address(this).balance);
    }

    function _verify(
        bytes32 data,
        bytes memory signature,
        address account
    ) internal pure returns (bool) {
        return data.recover(signature) == account;
    }
}