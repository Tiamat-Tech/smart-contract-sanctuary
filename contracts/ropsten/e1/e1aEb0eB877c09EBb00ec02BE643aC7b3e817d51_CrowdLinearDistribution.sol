// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;


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
    event CrowdLinearDistributionInitialized(address from);
    event TokensReleased(address beneficiary, uint256 amount);

    //0: Team_And_Advisors, 1: Community, 2: Investors, 3: Token_Launch_auction, 4: Liquidity
    enum VestingType {
        Team_And_Advisors,
        Community,
        Investors,
        Token_Launch_auction,
        Liquidity
    }

    struct BeneficiaryStruct {
        uint256 _start;
        uint256 _initial;
        uint256 _released;
        uint256 _balance;
        uint256 _vestingType;
        bool _exist;
        Ruleset[] _ruleset;
    }

    struct VestingTypeStruct {
        uint256 _initial;
        uint256 _allocatedInitial;
        Ruleset[] _ruleset;
    }

    struct Ruleset {
        uint256 _month;
        uint256 _value;//VestingTypeStruct: coefficient, BeneficiaryStruct: amount
    }

    mapping(address => BeneficiaryStruct) public _beneficiaryIndex;
    mapping(VestingType => VestingTypeStruct) public _vestingTypeIndex;
    address[] public _beneficiaries;
    address public _tokenAddress;

    constructor () {

        VestingTypeStruct storage teamVestingTypeStruct = _vestingTypeIndex[VestingType.Team_And_Advisors];
        teamVestingTypeStruct._initial = 40000000 ether;
        teamVestingTypeStruct._ruleset.push(Ruleset(5, 100));
        teamVestingTypeStruct._ruleset.push(Ruleset(11, 200));
        teamVestingTypeStruct._ruleset.push(Ruleset(17, 325));
        teamVestingTypeStruct._ruleset.push(Ruleset(1000, 500));

        VestingTypeStruct storage communityVestingTypeStruct = _vestingTypeIndex[VestingType.Community];
        communityVestingTypeStruct._initial = 10000000 ether;
        communityVestingTypeStruct._ruleset.push(Ruleset(5, 100));
        communityVestingTypeStruct._ruleset.push(Ruleset(11, 200));
        communityVestingTypeStruct._ruleset.push(Ruleset(17, 325));
        communityVestingTypeStruct._ruleset.push(Ruleset(1000, 500));

        VestingTypeStruct storage investorsVestingTypeStruct = _vestingTypeIndex[VestingType.Investors];
        investorsVestingTypeStruct._initial = 20000000 ether;
        investorsVestingTypeStruct._ruleset.push(Ruleset(5, 100));
        investorsVestingTypeStruct._ruleset.push(Ruleset(11, 200));
        investorsVestingTypeStruct._ruleset.push(Ruleset(17, 325));
        investorsVestingTypeStruct._ruleset.push(Ruleset(1000, 500));

        VestingTypeStruct storage auctionVestingTypeStruct = _vestingTypeIndex[VestingType.Token_Launch_auction];
        auctionVestingTypeStruct._initial = 50000000 ether;
        auctionVestingTypeStruct._ruleset.push(Ruleset(9, 100));
        auctionVestingTypeStruct._ruleset.push(Ruleset(1000, 200));

        VestingTypeStruct storage liquidityVestingTypeStruct = _vestingTypeIndex[VestingType.Liquidity];
        liquidityVestingTypeStruct._initial = 100000000 ether;
        liquidityVestingTypeStruct._ruleset.push(Ruleset(1, 120));
        liquidityVestingTypeStruct._ruleset.push(Ruleset(2, 140));
        liquidityVestingTypeStruct._ruleset.push(Ruleset(3, 160));
        liquidityVestingTypeStruct._ruleset.push(Ruleset(4, 180));
        liquidityVestingTypeStruct._ruleset.push(Ruleset(5, 200));
        liquidityVestingTypeStruct._ruleset.push(Ruleset(6, 220));
        liquidityVestingTypeStruct._ruleset.push(Ruleset(7, 240));
        liquidityVestingTypeStruct._ruleset.push(Ruleset(8, 260));
        liquidityVestingTypeStruct._ruleset.push(Ruleset(9, 280));
        liquidityVestingTypeStruct._ruleset.push(Ruleset(10, 300));
        liquidityVestingTypeStruct._ruleset.push(Ruleset(11, 320));
        liquidityVestingTypeStruct._ruleset.push(Ruleset(12, 340));
        liquidityVestingTypeStruct._ruleset.push(Ruleset(13, 360));
        liquidityVestingTypeStruct._ruleset.push(Ruleset(14, 380));
        liquidityVestingTypeStruct._ruleset.push(Ruleset(15, 400));
        liquidityVestingTypeStruct._ruleset.push(Ruleset(16, 420));
        liquidityVestingTypeStruct._ruleset.push(Ruleset(17, 440));
        liquidityVestingTypeStruct._ruleset.push(Ruleset(18, 460));
        liquidityVestingTypeStruct._ruleset.push(Ruleset(19, 480));
        liquidityVestingTypeStruct._ruleset.push(Ruleset(20, 500));
        liquidityVestingTypeStruct._ruleset.push(Ruleset(21, 520));
        liquidityVestingTypeStruct._ruleset.push(Ruleset(22, 540));
        liquidityVestingTypeStruct._ruleset.push(Ruleset(1000, 550));
    }

    fallback() external {
        revert("ce01");
    }

    /**
     * @notice initialize contract.
     */
    function initialize(address tokenAddress) external onlyOwner {
        require(tokenAddress != address(0) , "CrowdLinearDistribution: the token address is not valid");
        _tokenAddress = tokenAddress;

        emit CrowdLinearDistributionInitialized(address(msg.sender));
    }
    
    function create(address beneficiary, uint256 start, uint8 vestingType, uint256 initial) external onlyOwner {
        require(_tokenAddress != address(0), "CrowdLinearDistribution: the token address is not valid");
        require(!_beneficiaryIndex[beneficiary]._exist, "CrowdLinearDistribution: beneficiary exists");
        require(vestingType >= 0 && vestingType < 5, "CrowdLinearDistribution: vestingType is not valid");
        require(initial > 0, "CrowdLinearDistribution: initial must be greater than zero");

        VestingTypeStruct storage vestingTypeStruct = _vestingTypeIndex[VestingType(vestingType)];
        require(initial + vestingTypeStruct._allocatedInitial <= vestingTypeStruct._initial, "CrowdLinearDistribution: Not enough token to distribute");

        _beneficiaries.push(beneficiary);
        BeneficiaryStruct storage beneficiaryStruct = _beneficiaryIndex[beneficiary];
        beneficiaryStruct._start = start;
        beneficiaryStruct._initial = initial;
        beneficiaryStruct._vestingType = vestingType;
        beneficiaryStruct._exist = true;
        for(uint i = 0; i < vestingTypeStruct._ruleset.length; i++) {
            Ruleset memory ruleset = vestingTypeStruct._ruleset[i];
            beneficiaryStruct._ruleset.push(Ruleset(ruleset._month, calculateAmount(ruleset._value, initial)));
        }
        beneficiaryStruct._balance = beneficiaryStruct._ruleset[vestingTypeStruct._ruleset.length - 1]._value;

        vestingTypeStruct._allocatedInitial = vestingTypeStruct._allocatedInitial + initial;

        emit CrowdLinearDistributionCreated(beneficiary);
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

        emit TokensReleased(beneficiary, unreleased);
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
        require(_beneficiaryIndex[beneficiary]._exist, "CrowdLinearDistribution: beneficiary does not exist");

        return _beneficiaryIndex[beneficiary]._vestingType;
    }

    function getBeneficiary(address beneficiary) external view returns (BeneficiaryStruct memory) {
        require(_beneficiaryIndex[beneficiary]._exist, "CrowdLinearDistribution: beneficiary does not exist");

        return _beneficiaryIndex[beneficiary];
    }

    function getInitial(address beneficiary) external view returns (uint256) {
        require(_beneficiaryIndex[beneficiary]._exist, "CrowdLinearDistribution: beneficiary does not exist");

        return _beneficiaryIndex[beneficiary]._initial;
    }

    function getStart(address beneficiary) external view returns (uint256) {
        require(_beneficiaryIndex[beneficiary]._exist, "CrowdLinearDistribution: beneficiary does not exist");

        return _beneficiaryIndex[beneficiary]._start;
    }

    function getTotal(address beneficiary) external view returns (uint256) {
        require(_beneficiaryIndex[beneficiary]._exist, "CrowdLinearDistribution: beneficiary does not exist");

        return _beneficiaryIndex[beneficiary]._balance + _beneficiaryIndex[beneficiary]._released;
    }

    function getVested(address beneficiary) external view returns (uint256) {
        require(_beneficiaryIndex[beneficiary]._exist, "CrowdLinearDistribution: beneficiary does not exist");

        return _vestedAmount(beneficiary);
    }

    function getReleased(address beneficiary) external view returns (uint256) {
        require(_beneficiaryIndex[beneficiary]._exist, "CrowdLinearDistribution: beneficiary does not exist");

        return _beneficiaryIndex[beneficiary]._released;
    }
    
    function getBalance(address beneficiary) external view returns (uint256) {
        require(_beneficiaryIndex[beneficiary]._exist, "CrowdLinearDistribution: beneficiary does not exist");

        return uint256(_beneficiaryIndex[beneficiary]._balance);
    }

    function getVestingTypeStruct(uint256 vestingType) external view returns (VestingTypeStruct memory) {
        require(vestingType >= 0 && vestingType < 5, "CrowdLinearDistribution: vestingType is not valid");

        return _vestingTypeIndex[VestingType(vestingType)];
    }

    /**
     * @notice Returns the releasable amount of token for the given beneficiary
     */
    function getReleasable(address beneficiary) public view returns (uint256) {
        require(_beneficiaryIndex[beneficiary]._exist, "CrowdLinearDistribution: beneficiary does not exist");

        return _vestedAmount(beneficiary) - _beneficiaryIndex[beneficiary]._released;
    }

    /**
     * @dev Calculates the amount that has already vested.
     */
    function _vestedAmount(address beneficiary) private view returns (uint256) {
        BeneficiaryStruct storage tokenVesting = _beneficiaryIndex[beneficiary];
        uint256 totalBalance = tokenVesting._balance + tokenVesting._released;

        if (block.timestamp < tokenVesting._start)
            return 0;

        uint256 _months = BokkyPooBahsDateTimeLibrary.diffMonths(tokenVesting._start, block.timestamp);

        if (_months < 1)
            return tokenVesting._initial;

        uint256 result = 0;
        for (uint256 i = 0; i < tokenVesting._ruleset.length; i++) {
            Ruleset memory ruleset = tokenVesting._ruleset[i];
            if (_months <= ruleset._month) {
                result = ruleset._value;
                break;
            }
        }

        return (result >= totalBalance) ? totalBalance : result;
    }

    function calculateAmount(uint coefficient, uint beneficiaryInitial) private pure returns (uint) {
        return (coefficient * beneficiaryInitial) / (10 ** 2);
    }

}