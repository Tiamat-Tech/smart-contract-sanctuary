// SPDX-License-Identifier: MIT
          
//  ______     __  __     __     __         __         ______       
// /\  ___\   /\ \_\ \   /\ \   /\ \       /\ \       /\  __ \      
// \ \ \____  \ \  __ \  \ \ \  \ \ \____  \ \ \____  \ \  __ \     
//  \ \_____\  \ \_\ \_\  \ \_\  \ \_____\  \ \_____\  \ \_\ \_\    
//   \/_____/   \/_/\/_/   \/_/   \/_____/   \/_____/   \/_/\/_/    
                                                                 
//  ______     __     __         __         ______                  
// /\___  \   /\ \   /\ \       /\ \       /\  __ \                 
// \/_/  /__  \ \ \  \ \ \____  \ \ \____  \ \  __ \                
//   /\_____\  \ \_\  \ \_____\  \ \_____\  \ \_\ \_\               
//   \/_____/   \/_/   \/_____/   \/_____/   \/_/\/_/        

pragma solidity ^0.8.0;

import "./ChillaZillaERC721.sol";

interface IZEGG {
    function burn(address _from, uint256 _amount) external;
    function updateReward(address _from, address _to) external;
} 

contract ChillaZilla is ChillaZillaERC721 {
 
    modifier zillaOwner(uint256 zillaId) {
        require(ownerOf(zillaId) == msg.sender, "Cannot interact with a Zilla you do not own");
        _;
    }
    
    IZEGG public ZEGG;
    
    uint256 constant public BREEDING_PRICE = 1000 ether;
 
    /**
     * @dev Keeps track of the state of hatchlingZilla
     * 0 - Unminted
     * 1 - Egg
     * 2 - Revealed
     */
    mapping(uint256 => uint256) public hatchlingZilla;

    event ZillaHatched(uint256 zillaId, uint256 parent1, uint256 parent2);
    event ZillaRevealed(uint256 zillaId);

    constructor(string memory name, string memory symbol, uint256 supply, uint256 genCount) ChillaZillaERC721(name, symbol, supply, genCount) {}

    function breed(uint256 parent1, uint256 parent2) external zillaOwner(parent1) zillaOwner(parent2) {
        uint256 supply = totalSupply(); 
        require(supply < maxSupply,                               "Cannot hatch any more zillas");
        require(parent1 < maxGenCount && parent2 < maxGenCount,   "Cannot breed with zilla hatchling");
        require(parent1 != parent2,                               "Must select two unique parents");

        ZEGG.burn(msg.sender, BREEDING_PRICE);
        uint256 zillaId = maxGenCount + hatchlingCount;
        hatchlingZilla[zillaId] = 1;
        hatchlingCount++;
        _safeMint(msg.sender, zillaId);
        emit ZillaHatched(zillaId, parent1, parent2);
    }

    function reveal(uint256 zillaId) external zillaOwner(zillaId) {
        hatchlingZilla[zillaId] = 2;
        emit ZillaRevealed(zillaId);
    }

    function hatchlingZillaState(uint256 zillaId) public view returns(uint256){
        return hatchlingZilla[zillaId];
    }

    function setZillaEgg(address zEggAddress) external onlyOwner {
        ZEGG = IZEGG(zEggAddress);
    }
    
    function transferFrom(address from, address to, uint256 tokenId) public override {
        if (tokenId < maxGenCount) {
            ZEGG.updateReward(from, to);
            balanceGenesis[from]--;
            balanceGenesis[to]++;
        }
        ERC721.transferFrom(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) public override {
        if (tokenId < maxGenCount) {
            ZEGG.updateReward(from, to);
            balanceGenesis[from]--;
            balanceGenesis[to]++;
        }
        ERC721.safeTransferFrom(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) public override {
        if (tokenId < maxGenCount) {
            ZEGG.updateReward(from, to);
            balanceGenesis[from]--;
            balanceGenesis[to]++;
        }
        ERC721.safeTransferFrom(from, to, tokenId, data);
    }
}