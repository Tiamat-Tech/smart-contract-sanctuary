//SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;


// Payment splitter manager contract


import "@openzeppelin/contracts/finance/PaymentSplitter.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";

import "./PaymentSplitterCloneable.sol";




contract PaymentSplitterManagerClones is Ownable {
    mapping(address => address[]) private _createdSplitters;
    mapping(address => address[]) private _registeredSplitters;
    address[] public splitters;

    uint public tax;
    
    event PaymentSplitterCreated(address newSplitter);

    constructor () {
        PaymentSplitterCloneable implementation = new PaymentSplitterCloneable();
        address[] memory payees_ = new address[](1);
        payees_[0] = address(this);
        uint256[] memory shares_ = new uint256[](1);
        shares_[0] = 1;
        implementation.initialize(payees_, shares_);
        splitters.push(address(implementation));
        _createdSplitters[address(this)].push(address(implementation));
        _registeredSplitters[address(this)].push(address(implementation));
    }

    function splitterImplementation() public view returns (address) {
        return splitters[0];
    }

    function registeredCountOf(address _target) external view returns (uint) {
        return _registeredSplitters[_target].length;
    }

    function registeredSplittersOf(address _target) external view returns (address[] memory) {
        return _registeredSplitters[_target];
    }

    function createdSplittersOf(address _target) external view returns (address[] memory) {
        return _createdSplitters[_target];
    }

    function setTax(uint _tax) external onlyOwner {
        tax = _tax;
    }

    function newSplitter(address[] memory payees_, uint256[] memory shares_) external payable {
        require(msg.value >= tax);
        address _newSplitter = Clones.clone(splitterImplementation());
        PaymentSplitterCloneable(payable(_newSplitter)).initialize(payees_, shares_);
        splitters.push(_newSplitter);
        _createdSplitters[msg.sender].push(_newSplitter);
        for(uint i = 0; i < payees_.length; i++) {
            _registeredSplitters[payees_[i]].push(_newSplitter);
        }
    }

    function shakeIndex(address payable _recv, uint [] memory _ids) external {
        for(uint i = 0; i < _ids.length; i++) {
            PaymentSplitter(payable(_registeredSplitters[_recv][_ids[i]])).release(_recv);
        }
    }

    function shakeRange(address payable _recv, uint _start, uint _end) external {
        for(uint i = _start; i < _end; i++) {
            PaymentSplitter(payable(_registeredSplitters[_recv][i])).release(_recv);
        }
    }

    function shakeAll(address payable _recv) external {
        for(uint i = 0; i < _registeredSplitters[_recv].length; i++){
            PaymentSplitter(payable(_registeredSplitters[_recv][i])).release(_recv);
        }
    }

    function release(address payable _recv, uint _amount) external onlyOwner {
        Address.sendValue(_recv, _amount);
    }

    // views
    /**
     * @dev Getter for the amount of shares held by an account.
     */
    function sharesOfAccount(address splitter, address account) public view returns (uint256) {
        return PaymentSplitterCloneable(payable(splitter)).shares(account);
    }

    function shares(address splitter) public view returns (uint256[] memory) {
        PaymentSplitterCloneable psc = PaymentSplitterCloneable(payable(splitter));

        uint numPayees = psc.numPayees();
        uint256[] memory shares_ = new uint256[](numPayees);
        for (uint i = 0; i < numPayees; i++) {
            address p = psc.payee(i); 
            shares_[i] = psc.shares(p);
        }
        return shares_;
    }

    /**
     * @dev Getter for the address of the payee number `index`.
     */
    function payee(address splitter, uint256 index) public view returns (address) {
        return PaymentSplitterCloneable(payable(splitter)).payee(index);
    }

    function payees(address splitter) public view returns ( address[] memory) {
        PaymentSplitterCloneable psc = PaymentSplitterCloneable(payable(splitter));
        uint numPayees = psc.numPayees();
        address[] memory payees_ = new address[](numPayees);
        for (uint i = 0; i < numPayees; i++) {
            payees_[i] = psc.payee(i);
        }
        return payees_;
    }

    function balances(address splitter) public view returns (uint256[] memory) {
        PaymentSplitterCloneable psc = PaymentSplitterCloneable(payable(splitter));

        uint256 balance = splitter.balance;

        uint256 totalReleased = psc.totalReleased();
        uint256 totalShares = psc.totalShares();
        uint numPayees = psc.numPayees();
        uint256[] memory balances_ = new uint256[](numPayees);
        uint256 totalReceived = balance + totalReleased;
        for (uint i = 0; i < numPayees; i++) {
            address payeeAddress = psc.payee(i);
            uint256 shares_ = psc.shares(payeeAddress);
            // adapt this logic from payment splitter
            // uint256 payment = (totalReceived * _shares[account]) / _totalShares - _released[account];

            uint256 released = psc.released(payeeAddress);
            balances_[i] = (totalReceived * shares_) / totalShares - released;
        }

        return balances_;
    }
}


//PAYABLE ENDPOINTS AS ERC-721?
//DONT OVERENGINEER AT FIRST KEEP IT SIMPLE
//EVERYONE WANTS TO OVERENGINEER EVERYTHING