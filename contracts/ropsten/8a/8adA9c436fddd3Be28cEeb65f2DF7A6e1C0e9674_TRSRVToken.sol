// SPDX-License-Identifier: MIT

// solhint-disable reason-string, no-empty-blocks

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Wrapper.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";

contract TRSRVToken is Ownable, ERC20, ERC20Wrapper, ERC20Permit {
    uint256 private _totalReserve = 0;

    constructor(
        address underlying
    )
        Ownable()
        ERC20("", "")
        ERC20Wrapper(IERC20(underlying))
        ERC20Permit(string(abi.encodePacked("tRSRV-", ERC20(address(underlying)).symbol())))
        {
        }

    function name() public view virtual override returns (string memory) {
        string memory underlyingSymbol = ERC20(address(underlying)).symbol();
        return string(abi.encodePacked("tRSRV ", underlyingSymbol));
    }

    function symbol() public view virtual override returns (string memory) {
        string memory underlyingSymbol = ERC20(address(underlying)).symbol();
        return string(abi.encodePacked("tRSRV-", underlyingSymbol));
    }

    function decimals() public view virtual override returns (uint8) {
        return ERC20(address(underlying)).decimals();
    }

    function totalReserve() public view virtual returns (uint256) {
        return _totalReserve;
    }

    function reserveApprove(uint256 amount) public virtual onlyOwner returns (bool) {
        IERC20(underlying).approve(address(this), amount);
        return true;
    }

    function reserveTo(address account, uint256 amount) public virtual onlyOwner returns (bool) {
        SafeERC20.safeTransferFrom(underlying, address(this), account, amount);
        _mintReserve(account, amount);
        return true;
    }

    function _mintReserve(address account, uint256 amount) internal virtual {
        require(account != address(0), "TRSRVToken: mint reserve to the zero address");
        require(totalSupply() - _totalReserve >= amount, "TRSRVToken: mint reserve amount exceeds balance");

        _totalReserve += amount;
    }
}