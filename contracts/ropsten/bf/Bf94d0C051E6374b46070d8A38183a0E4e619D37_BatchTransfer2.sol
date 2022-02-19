// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

import "./interface/IAzimuth.sol";
import "./interface/IEcliptic.sol";
import "./interface/IERC721.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Context.sol";

contract BatchTransfer2 is Context {

  IERC721Partial public ERC721;
  IAzimuth public azimuth;


  function batchSpawn(address _target, uint32[] calldata _points) external {

      IEcliptic ecliptic = IEcliptic(azimuth.owner());

      for (uint32 index; index < _points.length; index++) {
          ecliptic.spawn(_points[index], _msgSender());
        }
    }


  function batchTransfer(IERC721Partial _ecliptic, address _target, uint256[] calldata _points) external {

    IEcliptic ecliptic = IEcliptic(azimuth.owner());

      for (uint256 index; index < _points.length; index++) {
          _ecliptic.transferFrom(_msgSender(), _target, _points[index]);
        }
    }

}