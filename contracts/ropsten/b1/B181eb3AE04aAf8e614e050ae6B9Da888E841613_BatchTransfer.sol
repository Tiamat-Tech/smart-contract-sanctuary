// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

import "./interface/IAzimuth.sol";
import "./interface/IEcliptic.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "./interface/ILinearStarRelease.sol";
import "./Envelope.sol";

contract BatchTransfer is Context {

  address[] public contracts;
  IAzimuth public azimuth;
  ILinearStarRelease public lsr;


  constructor(IAzimuth _azimuth, ILinearStarRelease _lsr) 
    payable 
  {     
    azimuth = _azimuth;
    lsr = _lsr;
  }

  function createEnvelope(address _envToken)
    internal
    returns(address newContract)
  {
    EnvelopeForwarder ef = new EnvelopeForwarder(_envToken);
    contracts.push(address(ef));
    
    return address(ef);
  }

  function pack(uint32 _point, address _token)
    external
    payable
  {

    IEcliptic ecliptic = IEcliptic(azimuth.owner());

    // create envelope forwarder contraact
    address ef = createEnvelope(_token);

    // transfer the galaxy to the new envelope forwarder contract
    ecliptic.transferFrom(_msgSender(), ef, _point); 

    // lsr.approveBatchTransfer(address(ef));  

    // lsr.transferBatch(_msgSender());  

  }


}