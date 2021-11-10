// SPDX-License-Identifier: MIT

pragma solidity >=0.6.2 <0.8.0;
pragma abicoder v2;

import "./ERC1155Base.sol";

contract ERC1155StarGrail is ERC1155Base {

    constructor(
        string memory _name,
        string memory _symbol,
        string memory baseURI,
        string memory contractURI)
    HasContractURI(contractURI)
    ERC1155Base(_name, _symbol){
        _setBaseURI(baseURI);
    }

    function withdraw(address payable owner) public onlyOwner returns (bool) {
        _withdraw(owner);
        return true;
    }

    function setMinPrice(uint256 price) public onlyOwner returns (bool) {
        _setMinPrice(price);
        return true;
    }

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function isWhitelisted(address account) public view returns (bool) {
        return _isInWhitelist(account);
    }

    function addToWhitelist(address account) external onlyOwner {
        return _addAccountToWhitelist(account);
    }

    function removeFromWhitelist(address account) external onlyOwner {
        return _removeAccountFromWhitelist(account);
    }

    uint256[50] private __gap;
}