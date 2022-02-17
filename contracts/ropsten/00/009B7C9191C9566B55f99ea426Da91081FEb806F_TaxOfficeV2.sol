// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

// import "openzeppelin/contracts/math/SafeMath.sol";

import "./openzeppelin/SafeMath.sol";

import "./owner/Operator.sol";
import "./interfaces/ITaxable.sol";
import "./interfaces/IUniswapV2Router.sol";
import "./interfaces/IERC20.sol";

/*
    http://feng.finance start
*/
contract TaxOfficeV2 is Operator {
    using SafeMath for uint256;

    address public feng;
    address public uniRouter;
    address public wftm = address(0xc778417E063141139Fce010982780140Aa0cD5Ab);

    constructor(address _feng, address _pair) public {
        require(_feng != address(0), "feng address cannot be 0");
        require(_pair != address(0), "pair address cannot be 0");
        feng = _feng;
        uniRouter = _pair;
    }

    mapping(address => bool) public taxExclusionEnabled;

    function setTaxTiersTwap(uint8 _index, uint256 _value) public onlyOperator returns (bool) {
        return ITaxable(feng).setTaxTiersTwap(_index, _value);
    }

    function setTaxTiersRate(uint8 _index, uint256 _value) public onlyOperator returns (bool) {
        return ITaxable(feng).setTaxTiersRate(_index, _value);
    }

    function enableAutoCalculateTax() public onlyOperator {
        ITaxable(feng).enableAutoCalculateTax();
    }

    function disableAutoCalculateTax() public onlyOperator {
        ITaxable(feng).disableAutoCalculateTax();
    }

    function setTaxRate(uint256 _taxRate) public onlyOperator {
        ITaxable(feng).setTaxRate(_taxRate);
    }

    function setBurnThreshold(uint256 _burnThreshold) public onlyOperator {
        ITaxable(feng).setBurnThreshold(_burnThreshold);
    }

    function setTaxCollectorAddress(address _taxCollectorAddress) public onlyOperator {
        ITaxable(feng).setTaxCollectorAddress(_taxCollectorAddress);
    }

    function excludeAddressFromTax(address _address) external onlyOperator returns (bool) {
        return _excludeAddressFromTax(_address);
    }

    function _excludeAddressFromTax(address _address) private returns (bool) {
        if (!ITaxable(feng).isAddressExcluded(_address)) {
            return ITaxable(feng).excludeAddress(_address);
        }
    }

    function includeAddressInTax(address _address) external onlyOperator returns (bool) {
        return _includeAddressInTax(_address);
    }

    function _includeAddressInTax(address _address) private returns (bool) {
        if (ITaxable(feng).isAddressExcluded(_address)) {
            return ITaxable(feng).includeAddress(_address);
        }
    }

    function taxRate() external view returns (uint256) {
        return ITaxable(feng).taxRate();
    }

    function addLiquidityTaxFree(
        address token,
        uint256 amtFeng,
        uint256 amtToken,
        uint256 amtFengMin,
        uint256 amtTokenMin
    )
        external
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        require(amtFeng != 0 && amtToken != 0, "amounts can't be 0");
        _excludeAddressFromTax(msg.sender);

        IERC20(feng).transferFrom(msg.sender, address(this), amtFeng);
        IERC20(token).transferFrom(msg.sender, address(this), amtToken);
        _approveTokenIfNeeded(feng, uniRouter);
        _approveTokenIfNeeded(token, uniRouter);

        _includeAddressInTax(msg.sender);

        uint256 resultAmtFeng;
        uint256 resultAmtToken;
        uint256 liquidity;
        (resultAmtFeng, resultAmtToken, liquidity) = IUniswapV2Router(uniRouter).addLiquidity(
            feng,
            token,
            amtFeng,
            amtToken,
            amtFengMin,
            amtTokenMin,
            msg.sender,
            block.timestamp
        );

        if(amtFeng.sub(resultAmtFeng) > 0) {
            IERC20(feng).transfer(msg.sender, amtFeng.sub(resultAmtFeng));
        }
        if(amtToken.sub(resultAmtToken) > 0) {
            IERC20(token).transfer(msg.sender, amtToken.sub(resultAmtToken));
        }
        return (resultAmtFeng, resultAmtToken, liquidity);
    }

    function addLiquidityETHTaxFree(
        uint256 amtFeng,
        uint256 amtFengMin,
        uint256 amtFtmMin
    )
        external
        payable
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        require(amtFeng != 0 && msg.value != 0, "amounts can't be 0");
        _excludeAddressFromTax(msg.sender);

        IERC20(feng).transferFrom(msg.sender, address(this), amtFeng);
        _approveTokenIfNeeded(feng, uniRouter);

        _includeAddressInTax(msg.sender);

        uint256 resultAmtFeng;
        uint256 resultAmtFtm;
        uint256 liquidity;
        (resultAmtFeng, resultAmtFtm, liquidity) = IUniswapV2Router(uniRouter).addLiquidityETH{value: msg.value}(
            feng,
            amtFeng,
            amtFengMin,
            amtFtmMin,
            msg.sender,
            block.timestamp
        );

        if(amtFeng.sub(resultAmtFeng) > 0) {
            IERC20(feng).transfer(msg.sender, amtFeng.sub(resultAmtFeng));
        }
        return (resultAmtFeng, resultAmtFtm, liquidity);
    }

    function setTaxableFengOracle(address _fengOracle) external onlyOperator {
        ITaxable(feng).setFengOracle(_fengOracle);
    }

    function transferTaxOffice(address _newTaxOffice) external onlyOperator {
        ITaxable(feng).setTaxOffice(_newTaxOffice);
    }

    function taxFreeTransferFrom(
        address _sender,
        address _recipient,
        uint256 _amt
    ) external {
        require(taxExclusionEnabled[msg.sender], "Address not approved for tax free transfers");
        _excludeAddressFromTax(_sender);
        IERC20(feng).transferFrom(_sender, _recipient, _amt);
        _includeAddressInTax(_sender);
    }

    function setTaxExclusionForAddress(address _address, bool _excluded) external onlyOperator {
        taxExclusionEnabled[_address] = _excluded;
    }

    function _approveTokenIfNeeded(address _token, address _router) private {
        if (IERC20(_token).allowance(address(this), _router) == 0) {
            IERC20(_token).approve(_router, type(uint256).max);
        }
    }
}