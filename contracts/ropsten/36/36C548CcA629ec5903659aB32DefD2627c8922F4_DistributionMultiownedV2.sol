// SPDX-License-Identifier: Unlicense

pragma solidity ^0.8.4;

import "./Multiowned.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";


contract DistributionMultiownedV2 is Multiowned {
    /*
    Stakers get 7.5%
    Masternodes get 22.5%
    Publishers get 70%
    Gather commission is 30% on Publishers' portion
    (so in effect publishers get 70% of the 70% they are entitled to; 30% of that 70% goes to gather as commission)
    */
    using SafeMath for uint256;

    // all values were multiplied by 100 because solidity doesn't have float number
    uint256 public coefficientStakers;
    uint256 public coefficientMasternodes;
    uint256 public coefficientPublishers;
    uint256 public coefficientGather;

    // frozen balance for each case of reward 
    uint256 public frozenBalanceStakers;
    uint256 public frozenBalanceMasternodes;
    uint256 public frozenBalanceGathers;
    uint256 public totalFrozen;

    uint256 coeficientTotal;

    modifier globalsSet { 
        require (
            !(frozenBalanceGathers == 0 && frozenBalanceStakers == 0 && frozenBalanceGathers == 0),
            "Distribution: frozen balances were not set"); 
        _; 
    }

    function initialize(address[] memory _owners, uint _required) public initializer {
        __Multiowned_init(_owners, _required);
        coefficientStakers = 800;  // uses for 8%
        coefficientMasternodes = 2200; // uses for 22%
        coefficientPublishers = 7000; // uses for 70%

        // 30% of funds for publishers goes to gather as commission
        coefficientGather = 3000; // uses for 30%
        coeficientTotal = 100 * 100;
    }

    function checkCoefficient(
        uint256 _coefficientStakers,
        uint256 _coefficientMasternodes,
        uint256 _coefficientPublishers,
        uint256 _coefficientGather) public view
    {   
        require(
            _coefficientStakers
             + _coefficientMasternodes
             + _coefficientPublishers == coeficientTotal,
            "Distribution: Total amount of coefficients should be equal 10000."
        );

        require (
            _coefficientGather <= coeficientTotal,
            "Distribution: A coefficient for _coefficientGather should be less or equal 10000."
        );
    }

    function distribute(
        address[] memory _stakerAddresses,
        address[] memory _masternodeAddresses,
        address[] memory _gatherAddresses,
        uint256[] memory _stakerAmounts,
        uint256[] memory _masternodeAmounts,
        uint256[] memory _gatherAmounts) public globalsSet onlymanyowners(keccak256(msg.data)) {
        (
            uint256 totalAmountStakers,
            uint256 totalAmountMasternodes,
            uint256 totalAmountGathers
        ) = checkAndReturnTotalAmount(
            _stakerAddresses,
            _masternodeAddresses,
            _gatherAddresses,
            _stakerAmounts,
            _masternodeAmounts,
            _gatherAmounts
        );

        uint256 _stakersLength = _stakerAddresses.length;
        uint256 _masternodesLength = _masternodeAddresses.length;
        uint256 _gathersLength = _gatherAddresses.length;

        if(_stakersLength != 0) {
            for(uint256 i; i < _stakersLength; i++) {
                payable(_stakerAddresses[i]).transfer(_stakerAmounts[i]);
            }
            frozenBalanceStakers = frozenBalanceStakers - totalAmountStakers;
        }
        if(_masternodesLength != 0) {
            for(uint256 i; i < _masternodesLength; i++) {
                payable(_masternodeAddresses[i]).transfer(_masternodeAmounts[i]);
            }
            frozenBalanceMasternodes = frozenBalanceMasternodes - totalAmountMasternodes;
        }
        if(_gathersLength != 0) {
            for(uint256 i; i < _gathersLength; i++) {
                payable(_gatherAddresses[i]).transfer(_gatherAmounts[i]);
            }
            frozenBalanceGathers = frozenBalanceGathers - totalAmountGathers;
        }
    }

    function checkAndReturnTotalAmount(
        address[] memory _stakerAddresses,
        address[] memory _masternodeAddresses,
        address[] memory _gatherAddresses,
        uint256[] memory _stakerAmounts,
        uint256[] memory _masternodeAmounts,
        uint256[] memory _gatherAmounts) public view returns(uint256, uint256, uint256) {

        uint256 _stakersLength = _stakerAddresses.length;
        uint256 _masternodesLength = _masternodeAddresses.length;
        uint256 _gathersLength = _gatherAddresses.length;

        require(
            _stakersLength == _stakerAmounts.length,
            "Distribution: length of provided addresses and amounts should me the same for stakers"
        );
        require(
            _masternodesLength == _masternodeAmounts.length,
            "Distribution: length of provided addresses and amounts should me the same for masternodes"
        );
        require(
            _gathersLength == _gatherAmounts.length,
            "Distribution: length of provided addresses and amounts should me the same for gathers"
        );

        require(
            _stakersLength + _masternodesLength + _gathersLength < 100,
            "Distribution: Total length of provided addresses sholud be less then 100!"
        );

        uint256 totalAmountStakers;
        for(uint256 i; i < _stakersLength; i++) {
            totalAmountStakers += _stakerAmounts[i];
            require(
                _stakerAddresses[i] != address(0),
                "Distribution: the address can not be zero address (check stakers)"
            );
        }

        require(
            totalAmountStakers <= frozenBalanceStakers,
            "Distribution: length of provided amounts should be less or equal frozenBalanceStakers"
        );

        uint256 totalAmountMasternodes;
        for(uint256 i; i < _masternodesLength; i++) {
            totalAmountMasternodes += _masternodeAmounts[i];
            require(
                _masternodeAddresses[i] != address(0),
                "Distribution: the address can not be zero address (check masternodes)"
            );
        }

        require(
            totalAmountMasternodes <= frozenBalanceMasternodes,
            "Distribution: length of provided amounts should be less or equal frozenBalanceMasternodes"
        );

        uint256 totalAmountGathers;
        for(uint256 i; i < _gathersLength; i++) {
            totalAmountGathers += _gatherAmounts[i];
            require(
                _gatherAddresses[i] != address(0),
                "Distribution: the address can not be zero address (check gathers)"
            );
        }

        require(
            totalAmountGathers <= frozenBalanceGathers,
            "Distribution: length of provided amounts should be less or equal frozenBalanceGathers"
        );
        require(
            totalAmountStakers + totalAmountMasternodes + totalAmountGathers > 0,
            "Distribution: you should provide at least one address to make distribution"
        );
        return (totalAmountStakers, totalAmountMasternodes, totalAmountGathers);
    }

    /*
    All values for coefficients should be mul by 100
    For ex: if it needs to have a coefficientStakers as 67.9 %
    then it needs to be provided 6790 value for _coefficientStakers
    */
    function setNewCoefficients(
        uint256 _coefficientStakers,
        uint256 _coefficientMasternodes,
        uint256 _coefficientPublishers,
        uint256 _coefficientGather) public onlymanyowners(keccak256(msg.data))
    {
        checkCoefficient(
            _coefficientStakers,
            _coefficientMasternodes,
            _coefficientPublishers,
            _coefficientGather
        );
        if (coefficientStakers != _coefficientStakers)
            coefficientStakers = _coefficientStakers;
        if (coefficientMasternodes != _coefficientMasternodes)
            coefficientMasternodes = _coefficientMasternodes;
        if (coefficientPublishers != _coefficientPublishers)
            coefficientPublishers = _coefficientPublishers;
        if (coefficientGather != _coefficientGather)
            coefficientGather = _coefficientGather;
    }

    function setFrozenBalances() public onlymanyowners(keccak256(msg.data)) {
        totalFrozen = frozenBalanceStakers + frozenBalanceMasternodes + frozenBalanceGathers;

        require(
            totalFrozen != address(this).balance,
            "Distribution: the current contract balance was not changed"
        );
        uint256 value = address(this).balance - totalFrozen;
        // 100 - percents, 100 - return an imaginary float number of percents with 2 decimals

        uint256 numerator = value * coeficientTotal;
        uint256 divider = coefficientStakers + coefficientMasternodes
             + (coefficientGather * coefficientPublishers / coeficientTotal);

        uint256 totalBlockReward = numerator / divider;
        frozenBalanceStakers = frozenBalanceStakers + 
            (totalBlockReward * coefficientStakers / coeficientTotal);
        frozenBalanceMasternodes = frozenBalanceMasternodes + 
            (totalBlockReward * coefficientMasternodes / coeficientTotal);
        uint256 _portionPublishers = totalBlockReward * coefficientPublishers / coeficientTotal;
        frozenBalanceGathers = frozenBalanceGathers + (
            _portionPublishers * coefficientGather / coeficientTotal
        );
    }

    receive() external payable {}
}