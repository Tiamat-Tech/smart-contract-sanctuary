pragma solidity ^0.6.6;

abstract contract ILimitOrderBookFactory {

    function emitOrderEvent(
        address _owner, uint _orderNo, address _stoken, address _btoken, uint _amountIn,
        uint _minAmountOut, uint _maxAmountOut, uint _stokenSwapRate, uint _status,
        uint _type, uint gWei) external virtual;

    function emitOrderCancel(address _owner, uint _orderNo) external virtual;

    function emitOrderExecuted(address _owner, uint _orderNo, uint tokensOut, uint fee) external virtual;

    function getTrxFee() public virtual returns (uint,uint);

}