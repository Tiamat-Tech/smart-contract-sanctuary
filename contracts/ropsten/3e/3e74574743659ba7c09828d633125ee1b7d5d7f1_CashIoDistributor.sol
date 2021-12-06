/**
 *Submitted for verification at Etherscan.io on 2021-12-06
*/

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/*
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

pragma solidity ^0.8.0;

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _setOwner(_msgSender());
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _setOwner(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _setOwner(newOwner);
    }

    function _setOwner(address newOwner) private {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}


contract CashIoDistributor is Ownable {

    uint256 public distributePercentForCashIoDividend = 40;
    uint256 public distributePercentForCashIoJackpot = 10;
    uint256 public distributePercentForNftHolders = 10;
    uint256 public distributePercentForTeam = 20;
    uint256 public distributePercentForDevelopment = 20;

    address public addressTeam;
    address public addressDevelopment;
    address public addressNftHolders;
    address public addressCashIoDividend;
    address public addressCashIoJackpot;

    receive() external payable { }

    function setPrizePoolShare(uint256 percentForCashIoDividend, uint256 percentForCashIoJackpot, uint256 percentForNftHolders, uint256 percentForMarketing, uint256 percentForDevelopment) public onlyOwner {
        require(percentForCashIoDividend + percentForCashIoJackpot + percentForNftHolders + percentForMarketing + percentForDevelopment == 100);
        distributePercentForCashIoDividend = percentForCashIoDividend;
        distributePercentForCashIoJackpot = percentForCashIoJackpot;
        distributePercentForNftHolders = percentForNftHolders;
        distributePercentForTeam = percentForMarketing;
        distributePercentForDevelopment = percentForDevelopment;
    }


    function updateAddressTeam(address _addressTeam) public onlyOwner {
        addressTeam = _addressTeam;
    }
    
    function updateAddressDevelopment(address _addressDevelopment) public onlyOwner {
        addressDevelopment = _addressDevelopment;
    }
        
    function updateAddressCashIoDividend(address _addressCashIoDividend) public onlyOwner {
        addressCashIoDividend = _addressCashIoDividend;
    }
    
    function updateAddressCashIoJackpot(address _addressCashIoJackpot) public onlyOwner {
        addressCashIoJackpot = _addressCashIoJackpot;
    }    
    
    function updateAddressNftHolder(address _addressNftHolders) public onlyOwner {
        addressNftHolders = _addressNftHolders;
    }

    function distribute() public {
        uint256 contractBalance = address(this).balance;
        uint256 amountDividend = contractBalance * distributePercentForCashIoDividend / 100;
        uint256 amountJackpot = contractBalance * distributePercentForCashIoJackpot / 100;
        uint256 amountNftHolders = contractBalance * distributePercentForNftHolders / 100;
        uint256 amountMarketing = contractBalance * distributePercentForTeam / 100;
        uint256 amountDevelopment = contractBalance * distributePercentForDevelopment / 100;

        if(amountDividend > 0)
            payable(addressCashIoDividend).call{value: amountDividend, gas: 60000}("");


        if(amountJackpot > 0) 
            payable(addressCashIoJackpot).call{value: amountJackpot, gas: 60000}("");

        if(amountNftHolders > 0)
                payable(addressNftHolders).call{value: amountNftHolders, gas: 60000}("");
        
        if(amountMarketing > 0)
                payable(addressTeam).call{value: amountMarketing, gas: 60000}("");
        
        if(amountDevelopment > 0)
                payable(addressDevelopment).call{value: amountDevelopment, gas: 60000}("");
    }
}