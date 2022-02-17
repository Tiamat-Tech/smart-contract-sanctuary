// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

// import "@openzeppelin/contracts/math/SafeMath.sol";
// import "@openzeppelin/contracts/access/Ownable.sol";
// import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./openzeppelin/IERC20.sol";
import "./openzeppelin/SafeMath.sol";
import "./openzeppelin/Ownable.sol";


/*
  Inspired by http://feng.finance start
*/
contract TaxOracle is Ownable {
    using SafeMath for uint256;

    IERC20 public feng;
    IERC20 public wftm;
    address public pair;

    constructor(
        address _feng,
        address _wftm,
        address _pair
    ) public {
        require(_feng != address(0), "feng address cannot be 0");
        require(_wftm != address(0), "wftm address cannot be 0");
        require(_pair != address(0), "pair address cannot be 0");
        feng = IERC20(_feng);
        wftm = IERC20(_wftm);
        pair = _pair;
    }

    function consult(address _token, uint256 _amountIn) external view returns (uint144 amountOut) {
        require(_token == address(feng), "token needs to be feng");
        uint256 fengBalance = feng.balanceOf(pair);
        uint256 wftmBalance = wftm.balanceOf(pair);
        return uint144(fengBalance.mul(_amountIn).div(wftmBalance));
    }

    function setFeng(address _feng) external onlyOwner {
        require(_feng != address(0), "feng address cannot be 0");
        feng = IERC20(_feng);
    }

    function setWftm(address _wftm) external onlyOwner {
        require(_wftm != address(0), "wftm address cannot be 0");
        wftm = IERC20(_wftm);
    }

    function setPair(address _pair) external onlyOwner {
        require(_pair != address(0), "pair address cannot be 0");
        pair = _pair;
    }
}