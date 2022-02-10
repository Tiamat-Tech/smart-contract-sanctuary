// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import '@openzeppelin/contracts/token/ERC1155/ERC1155.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/utils/Strings.sol';

contract WonkyStonkCommunityBadges is Ownable, ERC1155 {
    uint256 public constant PINK = 0;
    uint256 public constant BLUE = 1;
    uint256 public constant GOLD = 2;

    //For later
    //address[] GoldAddressArray;     
    //address[] GoldAddressArray =  [0x36eaf79c12e96a3dc6f53426c, 0xf235aa56dd96bda02acfb361e];

    //address[] BlueAddressArray;     
    //address[] BlueAddressArray =  [0x36eaf79c12e96a3dc6f53426c, 0xf235aa56dd96bda02acfb361e];

    //address[] GoldAddressArray;     
    //address[] GoldAddressArray =  [0x36eaf79c12e96a3dc6f53426c, 0xf235aa56dd96bda02acfb361e];

    constructor() ERC1155('https://gateway.pinata.cloud/ipfs/QmP8bbQyuqYNgonPb1hfDu9xbNZt2AVa2V1zkkiNpgeCxY/{id}.json') {
       

        _mint(msg.sender, PINK, 100, "");
        _mint(msg.sender, BLUE, 50, "");
        _mint(msg.sender, GOLD, 10, "");


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