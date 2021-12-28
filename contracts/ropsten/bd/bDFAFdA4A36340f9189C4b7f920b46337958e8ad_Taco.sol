//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Taco is ERC20("Taco", "TAKO"), Ownable {
    address bakeryAddress;
    address bakerAddress;
    address pantryAddress;

    constructor(address _pantryAddress) {
        pantryAddress = _pantryAddress;
    }

    function setBakeryAddress(address _bakeryAddress) external onlyOwner {
        require(address(bakeryAddress) == address(0), "Bakery address already set");
        bakeryAddress = _bakeryAddress;
    }

    function setBakerAddress(address _bakerAddress) external onlyOwner {
        require(address(bakerAddress) == address(0), "Baker address already set");
        bakerAddress = _bakerAddress;
    }

    function mint(address _to, uint256 _amount) external {
        require(_msgSender() == bakeryAddress, "Only the Bakery contract can mint");
        _mint(_to, _amount);
    }

    function burn(address _from, uint256 _amount) external {
        require(_msgSender() == bakerAddress, "Only the Baker contract can burn");
        _burn(_from, _amount);
    }

    function transferToPantry(address _from, uint256 _amount) external {
        require(_msgSender() == pantryAddress, "Only the Pantry contract can call transferToPantry");
        _transfer(_from, pantryAddress, _amount);
    }
}