pragma solidity ^0.7.0;

import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { DSMath } from "../../common/math.sol";
import { Basic } from "../../common/basic.sol";
import { Events } from "./events.sol";

abstract contract BasicResolver is Events, DSMath, Basic {
    using SafeERC20 for IERC20;

    /**
     * @dev Deposit Assets To Smart Account.
     * @param token Token Address.
     * @param amt Token Amount.
     * @param getId Get Storage ID.
     * @param setId Set Storage ID.
     */
    function deposit(
        address token,
        uint256 amt,
        uint256 getId,
        uint256 setId
    ) public payable returns (string memory _eventName, bytes memory _eventParam) {
        uint _amt = getUint(getId, amt);
        if (token != ethAddr) {
            IERC20 tokenContract = IERC20(token);
            _amt = _amt == uint(-1) ? tokenContract.balanceOf(msg.sender) : _amt;
            tokenContract.safeTransferFrom(msg.sender, address(this), _amt);
        } else {
            require(msg.value == _amt || _amt == uint(-1), "invalid-ether-amount");
            _amt = msg.value;
        }
        setUint(setId, _amt);

        _eventName = "LogDeposit(address,uint256,uint256,uint256)";
        _eventParam = abi.encode(token, _amt, getId, setId);
    }

    /**
     * @dev Withdraw Assets To Smart Account.
     * @param token Token Address.
     * @param amt Token Amount.
     * @param to Withdraw token address.
     * @param getId Get Storage ID.
     * @param setId Set Storage ID.
     */
    function withdraw(
        address token,
        uint amt,
        address payable to,
        uint getId,
        uint setId
    ) public payable returns (string memory _eventName, bytes memory _eventParam) {
        uint _amt = getUint(getId, amt);
        if (token == ethAddr) {
            _amt = _amt == uint(-1) ? address(this).balance : _amt;
            to.call{value: _amt}("");
        } else {
            IERC20 tokenContract = IERC20(token);
            _amt = _amt == uint(-1) ? tokenContract.balanceOf(address(this)) : _amt;
            tokenContract.safeTransfer(to, _amt);
        }
        setUint(setId, _amt);

        _eventName = "LogWithdraw(address,uint256,address,uint256,uint256)";
        _eventParam = abi.encode(token, _amt, to, getId, setId);
    }
}

contract ConnectV2Basic is BasicResolver {
    string constant public name = "Basic-v1";
}