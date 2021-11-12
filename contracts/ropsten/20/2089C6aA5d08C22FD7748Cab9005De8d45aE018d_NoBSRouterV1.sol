// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

import '@pancakeswap/pancake-swap-lib/contracts/token/BEP20/IBEP20.sol';
import "./utils/Ownable.sol";
import "./interfaces/INoBSContract.sol";
import "./interfaces/INoBSFactory.sol";
import "./interfaces/INoBSDynamicReflector.sol";
import "./interfaces/INoBSMultiReflectionRouterV1.sol";

contract NoBSRouterV1 is INoBSMultiReflectionRouterV1, Ownable {

    INoBSFactory public noBSFactory;
    address payable private feeReceiver;
    uint256 public standardFee;
    uint256 public standardFeeDivisor;
    address public networkLPRouter;

    constructor(address owner, address _factory, address _feeReceiver, address _lpRouter) public Ownable() {
        feeReceiver = payable(_feeReceiver);
        standardFee = 25;
        standardFeeDivisor = 10000;
        networkLPRouter = _lpRouter;
        _owner = owner;
        INoBSFactory _noBSFactory = INoBSFactory(_factory);
        _noBSFactory.initialize(_lpRouter, _feeReceiver, standardFee, standardFeeDivisor);
        noBSFactory = _noBSFactory;
    }

    function setFeeReceiver(address _feeReceiver) external onlyOwner {
        feeReceiver = payable(_feeReceiver);
    }

    function setFactory(address _factory) external onlyOwner {
        noBSFactory = INoBSFactory(_factory);
        noBSFactory.initialize(networkLPRouter, feeReceiver, standardFee, standardFeeDivisor);
    }

    function transferStuckCurrency(address destination) external onlyOwner {
        destination.call{value: address(this).balance}("");
    }

    function transferStuckToken(address _destination, address _token) external onlyOwner {
        IBEP20 token = IBEP20(_token);
        uint256 balance = token.balanceOf(address(this));
        token.transfer(_destination, balance);
    }

    function setRoutingFee(uint256 _setFee, uint256 _setFeeDivisor) external onlyOwner {
        standardFee = _setFee;
        standardFeeDivisor = _setFeeDivisor;
        noBSFactory.setRoutingFee(_setFee, _setFeeDivisor);
    }

    function updateLPRouter(address _lpRouter) external onlyOwner {
        networkLPRouter = _lpRouter;
        noBSFactory.updateLPRouter(_lpRouter);
    }

    // Getters
    function factory() external view override returns(address) {
        return address(noBSFactory);
    }

    function getReflector() external view override returns(address) {
        return getReflectorFor(_msgSender());
    }

    function getReflectorFor(address tokenAddress) public view override returns(address) {
        return getReflectorForContractAtIndex(tokenAddress, 0);
    }

    function reflectorAtIndex(uint256 index) external view override returns(address) {
        return getReflectorForContractAtIndex(_msgSender(), index);
    }

    function getReflectorForContractAtIndex(address tokenAddress, uint256 index) public view override returns(address) {
        return noBSFactory.getReflector(tokenAddress, index);
    }

    // Factory Interactions
    function createDynamicReflector() external override returns(address) {
        return noBSFactory.createReflector(_msgSender(), address(0));
    }

    function createAdditionalDynamicReflector() external override returns(address) {
        return noBSFactory.createAdditionalReflector(_msgSender(), address(0));
    }

    function createDynamicReflectorWithToken(address tokenToReflect) external override returns(address){
        return noBSFactory.createReflector(_msgSender(), tokenToReflect);
    }

    function createAdditionalDynamicReflectorWithToken(address tokenToReflect) external override returns(address){
        return noBSFactory.createAdditionalReflector(_msgSender(), tokenToReflect);
    }


    // Reflection Settings
    function updateExcludedFromFeesByRouter(address reflector, bool _shouldExcludeContractFromFees) external onlyOwner {
        INoBSContract(reflector).updateExcludedFromFeesByRouter(_shouldExcludeContractFromFees);
    }
}