// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@imtbl/imx-contracts/contracts/Mintable.sol";

/*
    ________  __  _      ______  __   ____
   / __/ /\ \/ / | | /| / / __ \/ /  / __/
  _\ \/ /__\  /  | |/ |/ / /_/ / /__/ _/
 /___/____//_/___|__/|__/\____/____/_/____   __  _____
  / _ \/ _ |/ ___/  _/ |/ / ___/ / ___/ /  / / / / _ )
 / , _/ __ / /___/ //    / (_ / / /__/ /__/ /_/ / _  |
/_/|_/_/ |_\___/___/_/|_/\___/  \___/____/\____/____/

*/

contract SlyWolfRacingClub is Mintable, ERC721 {
    string private _baseURIPath;

    event SWRCMinted(address to, uint256 id);

    constructor(address _owner, address _imx)
        ERC721("SlyWolfRacingClub", "SWRC")
        Mintable(_owner, _imx) {}

    function setBaseURI(string memory baseURI) public onlyOwner {
        _baseURIPath = baseURI;
    }

    function withdraw() public onlyOwner {
        uint balance = address(this).balance;
        Address.sendValue(payable(_msgSender()), balance);
    }

    function _baseURI() internal view override returns (string memory) {
        return _baseURIPath;
    }

    function _mintFor(address to, uint256 id, bytes memory) internal override {
        _safeMint(to, id);
        emit SWRCMinted(to, id);
    }
}