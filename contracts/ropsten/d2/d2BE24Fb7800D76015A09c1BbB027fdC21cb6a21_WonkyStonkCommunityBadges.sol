// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import '@openzeppelin/contracts/token/ERC1155/ERC1155.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/utils/Strings.sol';


contract WonkyStonkCommunityBadges is ERC1155, Ownable {


    uint256 public constant PINK = 1;
    uint256 public constant BLUE = 2;
    uint256 public constant GOLD = 3;

    //uint256 public startEvent = 1635364800;
    //uint256 public endEvent = 1636081200;

    constructor() ERC1155('https://gateway.pinata.cloud/ipfs/QmSFDVm5HXwWrpdsGFVvuShYYxWPG1xj9f3nnuFXtwqaLh/{id}.json') {

    }

    function MintBadge(address to, uint256 id , bytes memory data) public {

        //require(block.timestamp >= startEvent, "Event not started");
        //require(block.timestamp <= endEvent, "Event ended");

        //COMPLEX LOGIC TO CHECK IF WALLET IS ELIGABLE FOR MINT. 
        if(id == 1) {
            _mint(to, PINK, 1, data);
        } 
        if(id == 2) {
             _mint(to, PINK, 1, data);
             _mint(to, BLUE, 1, data);
        }
        if(id == 3) {
             _mint(to, PINK, 1, data);
             _mint(to, BLUE, 1, data);
             _mint(to, GOLD, 1, data);
        }

    }




    function uri(uint256 _TokenId) override public view returns (string memory) {
        return string(
            abi.encodePacked(
                "https://gateway.pinata.cloud/ipfs/QmSFDVm5HXwWrpdsGFVvuShYYxWPG1xj9f3nnuFXtwqaLh/",
                Strings.toString(_TokenId),
                ".json"
            )    
        );
    }


}