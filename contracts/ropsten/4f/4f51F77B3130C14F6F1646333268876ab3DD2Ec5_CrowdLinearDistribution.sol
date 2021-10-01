// SPDX-License-Identifier: MIT

pragma solidity ^0.8.6;


import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./BokkyPooBahsDateTimeLibrary.sol";
import "./Ownable.sol";

/**
 * @title Ownable
 * @dev The Ownable contract has an owner address, and provides basic authorization control
 * functions, this simplifies the implementation of "user permissions".
 */
contract CrowdLinearDistribution is Ownable {

    event CrowdLinearDistributionCreated(address beneficiary);
    event logEvent(uint256 step);

    event CrowdLinearDistributionInitialized(address from);
    event CrowdLinearDistributionUpdated(uint256 start, uint256 cliff, uint256 initialShare, uint256 periodicShare);
    event TokensReleased(address beneficiary, uint256 amount);
    event CrowdLinearDistributionRevoked(address beneficiary);

    struct CrowdLinearDistributionStruct {
        uint256 _start;
        uint256 _cliff;
        uint256 _initialShare;
        uint256 _periodicShare;
        uint256 _released;
        uint256 _balance;
        uint256 _vestingType;
        uint256 _factor;
        bool _exist;
    }

    uint256 private allocated;

    mapping(address => CrowdLinearDistributionStruct) public _beneficiaryIndex;
    address[] public _beneficiaries;
    address public _tokenAddress;

    fallback() external {
        revert("ce01");
    }
    
    constructor () {}

    /**
     * @notice initialize contract.
     */
    function initialize(address tokenAddress) external onlyOwner {
        require(tokenAddress != address(0) , "CrowdLinearDistribution: token address not valid");
        _tokenAddress = tokenAddress;

        emit CrowdLinearDistributionInitialized(address(msg.sender));
    }
    
    function create(address beneficiary, uint256 start, uint256 cliff, uint256 initialShare, uint256 periodicShare, uint256 vestingType, uint256 factor, uint256 balance) onlyOwner external {
        require(!_beneficiaryIndex[beneficiary]._exist, "CrowdLinearDistributionFactory: beneficiary exists");
        require(_tokenAddress != address(0), "CrowdLinearDistribution: token address not valid");
        uint256 contractBalance = IERC20(_tokenAddress).balanceOf(address(this));
        require(contractBalance >= allocated + balance, "CrowdLinearDistribution: Not enough token to distribute");

        _beneficiaries.push(beneficiary);
        _beneficiaryIndex[beneficiary] = CrowdLinearDistributionStruct(start, cliff, initialShare, periodicShare, 0, balance, vestingType, factor, true);
        allocated = allocated + balance;
        
        emit CrowdLinearDistributionCreated(beneficiary);
    }

    /**
     * @notice Returns the releasable amount of token for the given beneficiary
     */
    function getReleasable(address beneficiary) public view returns (uint256) {
        require(_beneficiaryIndex[beneficiary]._exist, "CrowdLinearDistributionFactory: beneficiary does not exist");

        return _vestedAmount(beneficiary) - _beneficiaryIndex[beneficiary]._released;
    }
    
    /**
     * @notice Transfers vested tokens to beneficiary.
     */
    function release(address beneficiary) external {
        require(_tokenAddress != address(0), "CrowdLinearDistribution: token address not valid");
        uint256 unreleased = getReleasable(beneficiary);

        require(unreleased > 0, "CrowdLinearDistribution: releasable amount is zero");

        _beneficiaryIndex[beneficiary]._released = _beneficiaryIndex[beneficiary]._released + unreleased;
        _beneficiaryIndex[beneficiary]._balance = _beneficiaryIndex[beneficiary]._balance - unreleased;
        
        IERC20(_tokenAddress).transfer(beneficiary, unreleased);

        emit TokensReleased(address(beneficiary), unreleased);
    }
    
    /**
    * @notice Allows the owner to revoke the vesting.
    */
    function revoke(address beneficiary) external onlyOwner {
        require(_beneficiaryIndex[beneficiary]._vestingType >= 10, "CrowdLinearDistribution: Distribution is not revocable");
        require(_tokenAddress != address(0), "CrowdLinearDistribution: token address not valid");

        uint256 releasable = getReleasable(beneficiary);
        IERC20(_tokenAddress).transfer(beneficiary, releasable);

        //(getBalance(beneficiary) - releasable) amount, is not released and also is not allocated anymore, so return them to the contract
        allocated = allocated - (getBalance(beneficiary) - releasable);

        delete _beneficiaryIndex[beneficiary];

        emit TokensReleased(beneficiary, releasable);
        emit CrowdLinearDistributionRevoked(beneficiary);
    }

    function getBeneficiaries(uint256 vestingType) external view returns (address[] memory) {
        uint256 j = 0;
        address[] memory beneficiaries = new address[](_beneficiaries.length);

        for (uint256 i = 0; i < _beneficiaries.length; i++) {
            address beneficiary = _beneficiaries[i];
            if (_beneficiaryIndex[beneficiary]._vestingType == vestingType) {
                beneficiaries[j] = beneficiary;
                j++;
            }

        }
        return beneficiaries;
    }

    function getVestingType(address beneficiary) external view returns (uint256) {
        require(_beneficiaryIndex[beneficiary]._exist, "CrowdLinearDistributionFactory: beneficiary does not exist");

        return _beneficiaryIndex[beneficiary]._vestingType;
    }

    function getBeneficiary(address beneficiary) external view returns (CrowdLinearDistributionStruct memory) {
        require(_beneficiaryIndex[beneficiary]._exist, "CrowdLinearDistributionFactory: beneficiary not exists");

        return _beneficiaryIndex[beneficiary];
    }

    function getInitialShare(address beneficiary) external view returns (uint256) {
        require(_beneficiaryIndex[beneficiary]._exist, "CrowdLinearDistributionFactory: beneficiary does not exist");

        return _beneficiaryIndex[beneficiary]._initialShare;
    }

    function getPeriodicShare(address beneficiary) external view returns (uint256) {
        require(_beneficiaryIndex[beneficiary]._exist, "CrowdLinearDistributionFactory: beneficiary does not exist");

        return _beneficiaryIndex[beneficiary]._periodicShare;
    }

    function getStart(address beneficiary) external view returns (uint256) {
        require(_beneficiaryIndex[beneficiary]._exist, "CrowdLinearDistributionFactory: beneficiary does not exist");

        return _beneficiaryIndex[beneficiary]._start;
    }

    function getCliff(address beneficiary) external view returns (uint256) {
        require(_beneficiaryIndex[beneficiary]._exist, "CrowdLinearDistributionFactory: beneficiary does not exist");

        return _beneficiaryIndex[beneficiary]._cliff;
    }

    function getTotal(address beneficiary) external view returns (uint256) {
        require(_beneficiaryIndex[beneficiary]._exist, "CrowdLinearDistributionFactory: beneficiary does not exist");

        return _beneficiaryIndex[beneficiary]._balance + _beneficiaryIndex[beneficiary]._released;
    }

    function getVested(address beneficiary) external view returns (uint256) {
        require(_beneficiaryIndex[beneficiary]._exist, "CrowdLinearDistributionFactory: beneficiary does not exist");

        return _vestedAmount(beneficiary);
    }

    function getReleased(address beneficiary) external view returns (uint256) {
        require(_beneficiaryIndex[beneficiary]._exist, "CrowdLinearDistributionFactory: beneficiary does not exist");

        return _beneficiaryIndex[beneficiary]._released;
    }
    
    function getBalance(address beneficiary) public view returns (uint256) {
        require(_beneficiaryIndex[beneficiary]._exist, "CrowdLinearDistributionFactory: beneficiary does not exist");

        return uint256(_beneficiaryIndex[beneficiary]._balance);
    }

    /**
     * @dev Calculates the amount that has already vested.
     */
    function _vestedAmount(address beneficiary) private view returns (uint256) {
        CrowdLinearDistributionStruct memory tokenVesting = _beneficiaryIndex[beneficiary];
        uint256 currentBalance = tokenVesting._balance;
        uint256 totalBalance = currentBalance + tokenVesting._released;
        uint256 initialRelease = tokenVesting._initialShare;

        if (block.timestamp < tokenVesting._start)
            return 0;

        if (block.timestamp < tokenVesting._cliff)
            return initialRelease;

        uint256 _months = BokkyPooBahsDateTimeLibrary.diffMonths(tokenVesting._cliff, block.timestamp);

        uint256 previousMonth = tokenVesting._periodicShare;
        uint256 sum = tokenVesting._periodicShare;

        for (uint256 i = 1; i <= _months; ++i) {
            previousMonth = previousMonth + (tokenVesting._factor * previousMonth) / (1 ether);
            sum += previousMonth;
        }

        return (sum >= totalBalance) ? totalBalance : sum;
    }

}