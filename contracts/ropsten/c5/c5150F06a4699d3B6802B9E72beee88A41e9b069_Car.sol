// SPDX-License-Identifier: MIT

pragma solidity ^0.7.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

contract Car is ERC721, Ownable
{
    using SafeMath for uint256;

    string public defaultTokenURI;
    uint256 public totalCars;

    address _dev;

    mapping(uint256 => uint256) public carPrices;

    address payable defaultAddress;

    event CarPurchased(address user, uint256 car, uint256 timestamp);

    constructor(string memory name, string memory symbol, address payable _defaultAddress) ERC721(name, symbol) {
        defaultAddress = _defaultAddress;
    }

    modifier onlyOwnerOrDev() {
        require(defaultAddress == msg.sender || msg.sender == _dev, "Ownable: caller is not the owner");
        _;
    }

    function setBaseUri(string memory newBaseUri) external onlyOwnerOrDev {
        _setBaseURI(newBaseUri);
    }

    function setTokenURI(uint256 tokenId, string memory newTokenUri) external onlyOwnerOrDev {
        _setTokenURI(tokenId, newTokenUri);
    }

    function setDefaultTokenURI(string memory newDefaultTokenUri) external onlyOwnerOrDev {
        defaultTokenURI = newDefaultTokenUri;
    }


    function createCar(address _carOwner) external onlyOwnerOrDev {
      _mint(_carOwner, totalCars);
      _setTokenURI(totalCars, defaultTokenURI);
      totalCars = totalCars.add(1);
    }

    function buyCar(uint256 _car) external payable {
      require(carPrices[_car] > 0, "Car Not For Sale");
      require(msg.value >= carPrices[_car], "Wrong amount of money");

      address sender = _msgSender();

      emit CarPurchased(sender, _car, block.timestamp);
    }

    function sellToken(uint256 _car, uint256 _value) external
    {
        require(ownerOf(_car) == msg.sender, "You dont own this car");
        carPrices[_car] == _value;

    }
}