// SPDX-License-Identifier: MIT

/*
╋╋╋╋╋╋╋┏┓╋╋╋╋╋╋╋╋╋╋╋╋┏┓
╋╋╋╋╋╋╋┃┃╋╋╋╋╋╋╋╋╋╋╋╋┃┃
┏━━┳┓╋┏┫┗━┳━━┳━┳━━┳━━┫┃┏━━━┓
┃┏━┫┃╋┃┃┏┓┃┃━┫┏┫┏┓┃┏┓┃┃┣━━┃┃
┃┗━┫┗━┛┃┗┛┃┃━┫┃┃┗┛┃┏┓┃┗┫┃━━┫
┗━━┻━┓┏┻━━┻━━┻┛┗━┓┣┛┗┻━┻━━━┛
╋╋╋┏━┛┃╋╋╋╋╋╋╋╋┏━┛┃
╋╋╋┗━━┛╋╋╋╋╋╋╋╋┗━━┛
*/

// CyberGalz Legal Overview [https://cybergalznft.com/legaloverview]

pragma solidity >=0.8.4;

import '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import "./ERC721XX.sol";

abstract contract GalzRandomizer {
    function getTokenId(uint256 tokenId) public view virtual returns(uint256 resultId);
}

contract GalzPartz is ERC721XX, OwnableUpgradeable {

    string private _baseURIextended;

    bool public contractLocked = false;

    function initialize() initializer public {
        __ERC721XX_init("GalzPartz", "GALZPARTZ", address(0x4527BE8f31E2ebFbEF4fCADDb5a17447B27d2aef));
    }

    function setBaseURI(string memory baseURI_) public onlyOwner {
        require(contractLocked == false, "Contract has been locked and URI can't be changed");
        _baseURIextended = baseURI_;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return _baseURIextended;
    }

    function lockContract() public onlyOwner {
        contractLocked = true;   
    }

}