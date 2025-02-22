// SPDX-License-Identifier: MIT
pragma solidity ^0.7.1;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol"; // for WETH
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

contract FeeApprover is Ownable {
    using SafeMath for uint256;

    uint8 public feePercentX100 = 5;
    bool public paused;
    bool public initiated;

    mapping(address => uint256) public discountFrom;
    mapping(address => uint256) public discountTo;
    mapping(address => uint256) public feeBlackList;

    // called once for initial setup
    function initialize(address _tokenUniswapPair, address _liquidVault) public onlyOwner {
        require(_tokenUniswapPair != address(0) && _liquidVault != address(0), "Zero addresses not allowed");
        require(!initiated, "FeeApprover: already initiated");

        paused = true;
        initiated = true;
        _setFeeDiscountFrom(_tokenUniswapPair, 600);
        _setFeeDiscountTo(_liquidVault, 1000);
        _setFeeDiscountFrom(_liquidVault, 1000);
    }

    // once R3T is unpaused, it can never be paused
    function unPause() public onlyOwner {
        paused = false;
    }

    function setFeeMultiplier(uint8 _feeMultiplier) public onlyOwner {
        require(
            _feeMultiplier <= 100,
            "R3T: percentage expressed as number between 0 and 100"
        );
        feePercentX100 = _feeMultiplier;
    }

    function setFeeBlackList(address _address, uint256 _feeAmount)
        public
        onlyOwner
    {
        require(
            _feeAmount <= 100,
            "R3T: percentage expressed as number between 0 and 100"
        );
        feeBlackList[_address] = _feeAmount;
    }

    function setFeeDiscountTo(address _address, uint256 _discount)
        public
        onlyOwner
    {
        _setFeeDiscountTo(_address, _discount);
    }

    function _setFeeDiscountTo(address _address, uint256 _discount) internal {
        require(
            _discount <= 1000,
            "R3T: discount expressed as percentage between 0 and 1000"
        );
        discountTo[_address] = _discount;
    }

    function setFeeDiscountFrom(address _address, uint256 _discount)
        public
        onlyOwner
    {
        _setFeeDiscountFrom(_address, _discount);
    }

    function _setFeeDiscountFrom(address _address, uint256 _discount) internal {
        require(
            _discount <= 1000,
            "R3T: discount expressed as percentage between 0 and 1000"
        );
        discountFrom[_address] = _discount;
    }

    function calculateAmountsAfterFee(
        address sender,
        address recipient,
        uint256 amount
    )
        public
        view
        returns (
            uint256 transferToAmount,
            uint256 transferToFeeDistributorAmount
        )
    {
        require(!paused && initiated, "R3T: system not yet initialized");
        uint256 fee;
        if (feeBlackList[sender] > 0) {
            fee = feeBlackList[sender].mul(amount).div(100);
        } else {
            fee = amount.mul(feePercentX100).div(100);
            uint256 totalDiscount = discountFrom[sender].mul(fee).div(1000) +
                discountTo[recipient].mul(fee).div(1000);
            fee = totalDiscount > fee ? 0 : fee - totalDiscount;
        }

        return (amount - fee, fee);
    }
}