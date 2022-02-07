// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

import "./interface/IERC721.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Context.sol";

contract BatchTransfer2 is Context {

  IERC721Partial public ERC721;

  function batchTransfer(IERC721Partial _ecliptic, address _target, uint256[] calldata _points) external {
      for (uint256 index; index < _points.length; index++) {
          _ecliptic.transferFrom(_msgSender(), _target, _points[index]);
        }
    }

}