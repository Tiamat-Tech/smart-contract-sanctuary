// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

import "./interfaces/ISpiritOrbPetsv1.sol";

contract MediatorSOPv1 is IERC721Receiver, Ownable {
    ISpiritOrbPetsv1 public SOPv1;

    uint16 count;

    struct Pet {
      uint16 id; // max possible is 65535, but will only to go 7777
      uint8 level; // max possble is 255, but will only go to 30
      bool active;
      uint64 cdPlay; // uint64 in case people want to play past 2038?
      uint64 cdFeed; // sorry humans of year 2,147,485,547 AD...
      uint64 cdClean;
      uint64 cdTrain;
      uint64 cdDaycare;
    }

    //Pet[7777] public pets;
    mapping(uint16 => uint16) public petIds;

    // Events
    event StartToL2(address sender, uint256 tokenId, uint8 level, bool active, uint64 cdPlay, uint64 cdFeed, uint64 cdClean, uint64 cdTrain, uint64 cdDaycare);
    event EndToL2(address sender, uint256 tokenId);

    event StartToL1(address to, uint256 tokenId);
    event EndToL1(address to, uint256 tokenId);


    constructor(address _SOPv1) {
        SOPv1 = ISpiritOrbPetsv1(_SOPv1);
        count = 0;
    }

    function startBridgeToL2(uint16 _tokenId) external {
        require(msg.sender == SOPv1.ownerOf(_tokenId), "You don't own this token");
        SOPv1.approve(address(this), _tokenId);
        _startBridgeToL2(msg.sender, _tokenId);
    }

    function _startBridgeToL2(address _sender, uint16 _tokenId) internal {

        (uint8 level, bool active) = SOPv1.getPetInfo(_tokenId);
        (uint64 cdPlay, uint64 cdFeed, uint64 cdClean, uint64 cdTrain, uint64 cdDaycare) = SOPv1.getPetCooldowns(_tokenId);

        SOPv1.safeTransferFrom(_sender, address(this), _tokenId);
        petIds[count] = _tokenId;
        
        count ++;

        emit StartToL2(_sender, _tokenId, level, active, cdPlay, cdFeed, cdClean, cdTrain, cdDaycare);
    }

    /**
     * @dev See {IERC721Receiver-onERC721Received}.
     *
     * Always returns `IERC721Receiver.onERC721Received.selector`.
     */
    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) public virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}