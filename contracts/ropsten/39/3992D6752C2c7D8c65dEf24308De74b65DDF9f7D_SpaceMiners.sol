// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title ERC1155 ownerOf() for SpaceMiners portals contract
interface Portal {
    function ownerOf(uint256 tokenId) external view returns (address);
}

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

/// @title SpaceMiners contract for miners
contract SpaceMiners is ERC1155 {

    struct Miner {
        uint bagSize;
        uint warpFee;
        uint returnTime;
        uint departTime;
        uint fee;
    }

    struct Player {
        uint[] ownedMiners;
        uint[] deployedMiners;
    }

    Miner[] public miners;
    mapping(address => Player) private players;

    uint256 public constant MINER_1 = 0;
    uint256 public constant MINER_2 = 1;
    uint256 public constant MINER_3 = 2;
    uint256 public constant MINER_4 = 3;

    constructor() ERC1155("https://game.example/api/item/") {
        miners.push(Miner({bagSize: 16, warpFee: 5, returnTime: 48, departTime: 0, fee: 1 wei}));
        miners.push(Miner({bagSize: 24, warpFee: 4, returnTime: 39, departTime: 0, fee: 1 wei}));
        miners.push(Miner({bagSize: 32, warpFee: 4, returnTime: 31, departTime: 0, fee: 1 wei}));
        miners.push(Miner({bagSize: 48, warpFee: 3, returnTime: 24, departTime: 0, fee: 1 wei}));
        //_mint(msg.sender, MINER_1, 1, "");
    }

    /// @notice Mint miner for fee
    /// @param _minerId id of the miner (0-3)
    function mintMiner(uint _minerId) public payable {
        require(msg.value == miners[_minerId].fee);
        _mint(msg.sender, _minerId, 1, "");
    }

    /// @notice Checks owner of portal
    /// @param _id Portal id
    /// @param _contractAddress Portal contract address
    function checkPortalOwner(uint _id, address _contractAddress) internal view returns(address) {
        Portal portalsContract = Portal(_contractAddress);
        return portalsContract.ownerOf(_id);
    }

    /// @notice Returns payout for portal fees
    /// @param _portalOwner Portal owner address
    function portalPayout(address _portalOwner) internal view {}

    /// @notice Send a miner through a random portal for GEMs
    /// @param _minerId id of the miner (0-3)
    function warp(uint _minerId) public {
        require(balanceOf(msg.sender, _minerId) >= 1, "You don't own any miners");

    }
/*
    function _beforeTokenTransfer(address operator, address from, address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data) internal virtual override {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data); // Call parent hook

        for(uint i=0; i < ids.length; i++) {
            if(from != address(0)) {
                players[from].ownedMiners[i] = balanceOf(from, i) - amounts[i]; 
            }
            // make sure to check for balance of miner id as this will update state before hand
            players[to].ownedMiners[i] += amounts[i];
        }
    }
*/

}