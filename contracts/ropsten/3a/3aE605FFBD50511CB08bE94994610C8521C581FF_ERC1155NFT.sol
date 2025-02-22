pragma solidity >=0.8.0 <0.9.0;
//SPDX-License-Identifier: MIT

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./ERC2981Collection.sol";

contract ERC1155NFT is ERC1155, Ownable, ERC2981Collection {
    using SafeMath for uint256;
    using Address for address;
    using Counters for Counters.Counter;

    uint256 public nonce = 0;

    mapping(uint256 => mapping(address => uint256)) internal balances;

    constructor() ERC1155("https://tk9dde0thbro.usemoralis.com/{id}.json") {}

    modifier onlyContracts() {
        require(msg.sender == tx.origin, "Only Contracts");
        _;
    }

    function setRoyalties(address _receiver, uint256 _percentage)
        external
        onlyOwner
    {
        _setRoyalties(_receiver, _percentage);
    }

    function mint(
        address account,
        uint256 id,
        bytes memory data
    ) external {
        _mint(account, id, uint256(1), data);
        _setURI(uri(id));

    }

    function mintBatch(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) external onlyContracts {
        _mintBatch(to, ids, amounts, data);
    }

    function uri(uint256 _id) override public pure returns(string memory){
        return string(
            abi.encodePacked("https://tk9dde0thbro.usemoralis.com/",_id,".json")
        );
    }
}