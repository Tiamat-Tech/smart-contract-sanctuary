/**
 *Submitted for verification at Etherscan.io on 2022-01-27
*/

pragma solidity ^0.8.11;

contract Deposits {
    address public contributor;

    constructor() {
        contributor = msg.sender;
    }

    modifier onlyContributor() {
        require(msg.sender == contributor, "Access denied!");
        _;
    }

    modifier checkType(uint8 _type) {
        require(_type <= 2, "Incorrect deposit type!");
        _;
    }

    mapping (address => Deposit) public deposits;

    struct Deposit {
        address contributor;
        uint8 depositType;
    }

    function createDeposit(address _contributor, uint8 _depositType) public onlyContributor checkType(_depositType) {
        deposits[_contributor] = (Deposit(_contributor, _depositType));
    }

    function closeDeposit(address _contributor) public onlyContributor {
        delete deposits[_contributor];
    }
}