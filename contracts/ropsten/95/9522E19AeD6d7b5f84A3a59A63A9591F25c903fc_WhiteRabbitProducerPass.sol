// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Strings.sol";
import '@openzeppelin/contracts/access/Ownable.sol';
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract WhiteRabbitProducerPass is ERC1155, Ownable {

    string public name;
    string public symbol;
    address payable private _treasury;
    
    struct ProducerPass {
        uint256 price;
        uint256 episodeID; 
        string episodeName;
        // TODO: need to handle totaly supply limit either manually or using ERC1155Supply
    }
    
    event ProducerPassBought(uint256 episodeID, address indexed account, uint256 amount);

    mapping (uint256 => ProducerPass) public episodeToProducerPass; 

    constructor(string memory baseURI, address payable treasury) ERC1155(baseURI) {
        name = "White Rabbit Producer Pass";
        symbol = "WRPP";
        _treasury = treasury;
    }

    function setBaseURI(string memory baseURI) external onlyOwner {
        _setURI(baseURI);
    }

    function uri(uint256 episodeID) public view override returns (string memory) {
        require(episodeToProducerPass[episodeID].episodeID != 0, "URI requested for invalid episode");
        return string(abi.encodePacked(super.uri(episodeID)));
    }

    // when a new episode launches, a new producer pass is added by us here
    function addProducerPass(
        uint256 price,
        uint256 episodeID,
        string memory episodeName) 
        external onlyOwner {
            episodeToProducerPass[episodeID] = ProducerPass(price, episodeID, episodeName);
    }

    function mintProducerPass(uint256 episodeID, uint256 amount) external payable {
        ProducerPass memory pass = episodeToProducerPass[episodeID];
        require(msg.value == pass.price * amount, 'you dont have enough eth bro');

        _mint(msg.sender, episodeID, amount, '');
        Address.sendValue(_treasury, msg.value);
        emit ProducerPassBought(episodeID, msg.sender, amount);
    }

    // boilerplate override 

    function _mint(
        address account,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) internal virtual override(ERC1155) {
        super._mint(account, id, amount, data);
    }

    function _mintBatch(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual override(ERC1155) {
        super._mintBatch(to, ids, amounts, data);
    }
}