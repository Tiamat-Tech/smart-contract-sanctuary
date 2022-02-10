// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import '@openzeppelin/contracts/token/ERC1155/ERC1155.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/utils/Strings.sol';

contract WonkyStonkCommunityBadges is ERC1155, Ownable {
    uint256 public constant PINK = 0;
    uint256 public constant BLUE = 1;
    uint256 public constant GOLD = 2;


    address[] PinkAddressArray =  [0x4AFBEA2a11e9A6dA944fb66970aeB78DFE15a01f, 0xED867A4D24eDDa0F0b83349241D883aa45B906c1,0x4AFBEA2a11e9A6dA944fb66970aeB78DFE15a01f, 0xED867A4D24eDDa0F0b83349241D883aa45B906c1,0x4AFBEA2a11e9A6dA944fb66970aeB78DFE15a01f, 0xED867A4D24eDDa0F0b83349241D883aa45B906c1,0x4AFBEA2a11e9A6dA944fb66970aeB78DFE15a01f, 0xED867A4D24eDDa0F0b83349241D883aa45B906c1,0x4AFBEA2a11e9A6dA944fb66970aeB78DFE15a01f, 0xED867A4D24eDDa0F0b83349241D883aa45B906c1];
    address[] BlueAddressArray =  [0x4AFBEA2a11e9A6dA944fb66970aeB78DFE15a01f, 0xED867A4D24eDDa0F0b83349241D883aa45B906c1,0x4AFBEA2a11e9A6dA944fb66970aeB78DFE15a01f, 0xED867A4D24eDDa0F0b83349241D883aa45B906c1,0x4AFBEA2a11e9A6dA944fb66970aeB78DFE15a01f, 0xED867A4D24eDDa0F0b83349241D883aa45B906c1,0x4AFBEA2a11e9A6dA944fb66970aeB78DFE15a01f, 0xED867A4D24eDDa0F0b83349241D883aa45B906c1,0x4AFBEA2a11e9A6dA944fb66970aeB78DFE15a01f, 0xED867A4D24eDDa0F0b83349241D883aa45B906c1,0x4AFBEA2a11e9A6dA944fb66970aeB78DFE15a01f, 0xED867A4D24eDDa0F0b83349241D883aa45B906c1];  
    address[] GoldAddressArray =  [0x4AFBEA2a11e9A6dA944fb66970aeB78DFE15a01f, 0xED867A4D24eDDa0F0b83349241D883aa45B906c1,0x4AFBEA2a11e9A6dA944fb66970aeB78DFE15a01f, 0xED867A4D24eDDa0F0b83349241D883aa45B906c1,0x4AFBEA2a11e9A6dA944fb66970aeB78DFE15a01f, 0xED867A4D24eDDa0F0b83349241D883aa45B906c1,0x4AFBEA2a11e9A6dA944fb66970aeB78DFE15a01f, 0xED867A4D24eDDa0F0b83349241D883aa45B906c1,0x4AFBEA2a11e9A6dA944fb66970aeB78DFE15a01f, 0xED867A4D24eDDa0F0b83349241D883aa45B906c1,0x4AFBEA2a11e9A6dA944fb66970aeB78DFE15a01f, 0xED867A4D24eDDa0F0b83349241D883aa45B906c1];


    constructor() ERC1155('https://gateway.pinata.cloud/ipfs/QmP8bbQyuqYNgonPb1hfDu9xbNZt2AVa2V1zkkiNpgeCxY/{id}.json') {
       
        for(uint256 i=0; i < PinkAddressArray.length; i++) {
            _mint(PinkAddressArray[i], PINK, 1, "");
        }

        for(uint256 i=0; i < BlueAddressArray.length; i++) {
        _mint(BlueAddressArray[i], BLUE, 1, "");
        }

        for(uint256 i=0; i < GoldAddressArray.length; i++) {
            _mint(GoldAddressArray[i], GOLD, 1, "");
        }

    }

    function uri(uint256 _TokenId) override public view returns (string memory) {
        return string(
            abi.encodePacked(
                "https://gateway.pinata.cloud/ipfs/QmP8bbQyuqYNgonPb1hfDu9xbNZt2AVa2V1zkkiNpgeCxY/",
                Strings.toString(_TokenId),
                ".json"
            )    
        );
    }

}