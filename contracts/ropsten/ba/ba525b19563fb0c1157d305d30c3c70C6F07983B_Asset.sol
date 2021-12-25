// SPDX-License-Identifier: MIT
pragma solidity ^0.8.1;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "./Mintable.sol";

contract Asset is ERC721, Mintable {

    string  private _defaultURI;
    uint256 private _supply;
    uint256 public maxSupply = 555;

    event mint();

    constructor(
        address _owner,
        string memory _name,
        string memory _symbol,
        address _imx
    ) ERC721(_name, _symbol) Mintable(_owner, _imx) {}

    function _mintFor(
        address user,
        uint256 id,
        bytes memory
    ) internal override {
        _safeMint(user, id);
        _supply++;
        setDefaultURI("https://api.cryptomaids.tokyo/metadata/butler/");
    }

    function setDefaultURI(string memory defaultURI_) public onlyOwner {
        _defaultURI = defaultURI_;
    }

    function _baseURI() internal view override returns (string memory) {
        return _defaultURI;
    }

    // minting is handled offchain using Immutable X client API. 
    // invalid transactions (insufficiant value, invalid sale date, unauthorized whitelisted...etc) will be ignored.
    function mintButler() public payable {
        emit mint();
    }

    function totalSupply() public view virtual returns (uint256) { return _supply; }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}