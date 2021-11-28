// SPDX-License-Identifier: MIT
//       ___           ___           ___           ___     
//      /\  \         /\  \         /\__\         /\  \    
//     /::\  \       /::\  \       /:/  /        /::\  \   
//    /:/\:\  \     /:/\:\  \     /:/  /        /:/\ \  \  
//   /:/  \:\__\   /::\~\:\  \   /:/  /  ___   _\:\~\ \  \ 
//  /:/__/ \:|__| /:/\:\ \:\__\ /:/__/  /\__\ /\ \:\ \ \__\
//  \:\  \ /:/  / \:\~\:\ \/__/ \:\  \ /:/  / \:\ \:\ \/__/
//   \:\  /:/  /   \:\ \:\__\    \:\  /:/  /   \:\ \:\__\  
//    \:\/:/  /     \:\ \/__/     \:\/:/  /     \:\/:/  /  
//     \::/__/       \:\__\        \::/  /       \::/  /   
//      ~~            \/__/         \/__/         \/__/    
//
// DEUS ERC-1155 Contract
/// @creator:     DEUSGames
/// @author:      cem - twitter.com/cemtuncelli                            

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";

contract DEUSBasicPlayer is ERC1155, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _supplyCounter;

    uint256 public constant BASICPLAYER_BLACK = 0;
    uint256 public constant BASICPLAYER_RED = 1;
    uint256 public constant BASICPLAYER_BLUE = 2;
    uint256 public constant BASICPLAYER_ORANGE = 3;

    uint constant NUMBER_OF_TOKENS_ALLOWED_PER_TX = 10;
    uint constant NUMBER_OF_TOKENS_ALLOWED_PER_ADDRESS = 10;

    uint constant TOTAL_SUPPLY = 8888;
    uint constant MINT_PRICE = 0.077 ether;
    bool public IS_SALE_ACTIVE = false;

    address public constant DEUS_ADDRESS = 0x2B7620dc9942d8d5064dB021348224D418994bCC;

    mapping (uint256 => string) private _uris;
    mapping (address => uint) addressToMintCount;

    constructor() ERC1155("https://kapidoo.github.io/1155/metadata/1.0.0/{id}.json") {}

    function uri(uint256 _id) override public view returns (string memory) {
      return (_uris[_id]);
    }

    modifier onlyAccounts () {
      require(msg.sender == tx.origin, "Not allowed origin");
      _;
    }

    function safeMint(uint256 _tokenId, uint _amount) public payable onlyAccounts {
      require(IS_SALE_ACTIVE, "Sale not started");
      require(msg.value >= _amount * MINT_PRICE, "Not enough ether balance");
      require(_amount <= NUMBER_OF_TOKENS_ALLOWED_PER_TX, "Too many requested");

      uint current = _supplyCounter.current();

      require(current + _amount < TOTAL_SUPPLY, "Exceeds total supply");
      require(addressToMintCount[msg.sender] + _amount <= NUMBER_OF_TOKENS_ALLOWED_PER_ADDRESS, "Exceeds allowance");

      addressToMintCount[msg.sender] += _amount;

      for (uint i = 0; i < _amount; i++) {
        _supplyCounter.increment();
        _mint(msg.sender, _tokenId, _amount, "");
      }
    }

    function togglePublicSale() public onlyOwner {
        IS_SALE_ACTIVE = !IS_SALE_ACTIVE;
    }

    function _withdraw(address _address, uint256 _amount) private {
      (bool success, ) = _address.call{value: _amount}("");
      require(success, "Transfer failed.");
    }

    function withdrawAll() public onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0);

        _withdraw(DEUS_ADDRESS, balance);
    }
}