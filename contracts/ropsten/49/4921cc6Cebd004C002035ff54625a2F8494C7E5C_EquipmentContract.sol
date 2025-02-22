// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract EquipmentContract is ERC1155 {
    using SafeMath for uint256;

    uint256 public constant EQUIP1 = 0;
    uint256 public constant EQUIP2 = 1;
    uint256 public constant EQUIP3 = 2;
    uint256[] public attackBoosts = [2, 6, 10];
    uint256[] public hpBoosts = [20, 30, 40];
    mapping(uint256 => uint256) public equipAttack;
    mapping(uint256 => uint256) public equipHp;

    constructor()
        ERC1155("https://gateway.pinata.cloud/ipfs/QmWe3xrXrWyBF8ezVsAwZbBhz6j6sZVS6BvxVNDSrQhagM/{id}.json")
    {
        for (uint256 i = 0; i < attackBoosts.length; i++) {
            equipAttack[i] = attackBoosts[i];
            equipHp[i] = hpBoosts[i];
        }
    }

    function mint(uint256 _id, uint256 _amount) public payable {
        require((_id < 3) && (_id >= 0), "token doesn't exist");
        _mint(msg.sender, _id, _amount, "");
    }

    function mintWithAddress(
        address _address,
        uint256 _id,
        uint256 _amount
    ) public payable {
        require((_id < 3) && (_id >= 0), "token doesn't exist");
        _mint(_address, _id, _amount, "");
    }

    function getEquipmentStats(uint256 equipId)
        external
        view
        returns (uint256, uint256)
    {
        return (equipAttack[equipId], equipHp[equipId]);
    }
}