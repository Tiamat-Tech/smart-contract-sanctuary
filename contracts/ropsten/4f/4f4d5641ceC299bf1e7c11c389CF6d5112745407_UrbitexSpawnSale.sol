// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "./interface/IAzimuth.sol";
import "./interface/IEcliptic.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Context.sol";

contract UrbitexSpawnSale is Context, Ownable
{

  // At the time of deployment, this is one of two contracts in use by urbitex.
  // This contract facilitates the sale of planets via spawning from a host star.
  // The intent is to supply greater starting inventory to the marketplace without having to
  // first spawn dozens of planets.

  //  PlanetSold: planet has been sold
  //
  event PlanetSold(uint32 indexed prefix, uint32 indexed planet);

  //  azimuth: points state data store
  //
  IAzimuth public azimuth;

  //  price: fixed price to be set across all planets
  //
  uint256 public price;

  //  constructor(): configure the points data store and planet price
  //
  constructor(IAzimuth _azimuth, uint256 _price)
  {
    require(0 < _price);
    azimuth = _azimuth;
    setPrice(_price);
  }

    //  purchase(): pay the :price, acquire ownership of the _planet
    //
    function purchase(uint32 _planet)
      external
      payable
    {
      require (msg.value == price);
              
      //  spawn the planet, then immediately transfer to the caller
      //
      //   spawning to the caller would give the point's prefix's owner
      //   a window of opportunity to cancel the transfer
      //
      IEcliptic ecliptic = IEcliptic(azimuth.owner());
      ecliptic.spawn(_planet, address(this));
      ecliptic.transferPoint(_planet, _msgSender(), false);
      emit PlanetSold(azimuth.getPrefix(_planet), _planet);
    }

    // EXCHANGE OWNER OPERATIONS
    
    function setPrice(uint256 _price)
      public
      onlyOwner
    {
      require(0 < _price);
      price = _price;
    }

    function withdraw(address payable _target) external onlyOwner  {
      require(address(0) != _target);
      _target.transfer(address(this).balance);
    }

    function close(address payable _target) external onlyOwner  {
      require(address(0) != _target);
      selfdestruct(_target);
    }
}