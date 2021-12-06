//SPDX-License-Identifier: Unlicense
pragma solidity >=0.7.5;

import "../abstracts/WrappedERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// contract WrappedHoge is WrappedERC20(ERC20(0xfAd45E47083e4607302aa43c65fB3106F1cd7607)) {}
contract WrappedHogeTestnet is Ownable, WrappedERC20(ERC20(0xd2f0541B27953D39561a5037F9A22a9e6E677a23)) {
    function deposit(address _recipient, uint256 _amount) public override {
        uint256 beforeBalance = underlyingToken.balanceOf(address(this));
        bool success = underlyingToken.transferFrom(msg.sender, address(this), _amount);
        require(success, "Transfer from failed");
        uint256 afterBalance = underlyingToken.balanceOf(address(this));
        uint256 _mintAmount = afterBalance - beforeBalance;
        _mint(_recipient, _mintAmount);
    }

    function withdrawReflections() public onlyOwner() {
        bool success = underlyingToken.transfer(owner(), reflectionsEarned());
        require(success, "Transfer failed");
    }

    function reflectionsEarned() public view returns(uint256 amount) {
        return underlyingToken.balanceOf(address(this)) - totalSupply();
    }
}