// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./SafeMath.sol";
import "./interfaces/IERC20.sol";

contract Exchange {
    using SafeMath for uint256;
    
    address admin;

    struct TokenDescription {
        IERC20 token;
        uint256 rate;
        bool isExist;
    }

    mapping (address => TokenDescription) tokens;

    modifier onlyAdmin {
        require(msg.sender == admin, "Only admin can call this function");
        _;
    }

    event TokenAdded(
        address token,
        uint256 rate
    );

    event TokenRemoved(
        address token
    );

    event TokensPurchased(
        address account,
        address token,
        uint amount,
        uint256 rate
    );

    event TokensSold(
        address account,
        address token,
        uint amount,
        uint256 rate
    );

    constructor(address _admin) {
        admin = _admin;
    }

    function buyToken(address _token) public payable {
        uint256 amount = msg.value.mul(tokens[_token].rate);
        IERC20 token = tokens[_token].token;

        token.transfer(msg.sender, amount);
        emit TokensPurchased(
            msg.sender,
            _token,
            amount,
            tokens[_token].rate
        );
    }

    function sellToken(address _token, uint256 _amount) public {
        uint256 ethAmount = _amount.div(tokens[_token].rate);

        payable(msg.sender).transfer(ethAmount);

        (bool success, ) = msg.sender.call{value: ethAmount}("");
        require(success, "Token purchase fails");

        emit TokensSold(
            msg.sender,
            _token,
            ethAmount,
            tokens[_token].rate
        );
    }

    function addToken(address _token, uint256 _rate) public onlyAdmin {
        tokens[_token].token = IERC20(_token);
        tokens[_token].rate = _rate;
        tokens[_token].isExist = true;

        emit TokenAdded(_token, _rate);
    }

    function removeToken(address _token) public onlyAdmin {
        delete tokens[_token];

        emit TokenRemoved(_token);
    }

    function setTokenRate(address _token, uint256 _rate) public onlyAdmin {
        tokens[_token].rate = _rate;
    }

    function tokenRate(address _token) public view returns (uint256) {
        return tokens[_token].rate;
    }
}