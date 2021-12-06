//SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0;

import "../abstracts/WrappedERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// contract WrappedHoge is WrappedERC20(ERC20(0xfAd45E47083e4607302aa43c65fB3106F1cd7607)) {}
contract WrappedHogeTestnet is Ownable, WrappedERC20(ERC20(0x49758F64eC3604E63D244338Cfc439f5904E9c9c)) {

    function name() public view virtual override returns (string memory) {
        return "Hyper Hoge";
    }

    function symbol() public view virtual override returns (string memory) {
        return "hHoge";
    }

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