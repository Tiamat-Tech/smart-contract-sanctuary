// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@imtbl/imx-contracts/contracts/Mintable.sol";

contract NFTBasicIMX is ERC721, Mintable {
    
    mapping(address => bool) private _admins;

    event AdminAccessSet(address _admin, bool _enabled);

    constructor(
        address _owner,
        string memory _name,
        string memory _symbol,
        address _imx
    ) ERC721(_name, _symbol) Mintable(_owner, _imx) {}

    function _mintFor(
        address user,
        uint256 id,
        bytes memory ipfs
    ) internal override {
        _safeMint(user, id, ipfs);
    }

    function setAdmin(address admin, bool enabled) external onlyOwner {
    _admins[admin] = enabled;
    emit AdminAccessSet(admin, enabled);
  }
  
  modifier onlyAdmin() {
    require(
      _admins[msg.sender] || msg.sender == owner(),
      "Caller does not have Admin Access"
    );
    _;
  }
}