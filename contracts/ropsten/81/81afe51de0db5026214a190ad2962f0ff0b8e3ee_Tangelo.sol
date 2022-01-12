// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Tangelo is ERC20, Pausable, Ownable {
    bool isPublic = false;
    mapping (address => bool) whitelist;

    constructor() ERC20("Tangelo", "TLO") {
        whitelist[msg.sender] = true;
        _mint(msg.sender, 1000000 * 10 ** decimals());
    }

    modifier whitelisted(address _address) {
        if (!isPublic) {
            require(whitelist[_address]);
        }
        _;
    }

    function setWhitelistStatus(address _address, bool status) public onlyOwner {
        whitelist[_address] = status;
    }

    function setPublic(bool _isPublic) public onlyOwner {
        isPublic = _isPublic;
    }


    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount)
        internal
        whenNotPaused
        whitelisted(to)
        override
    {
        super._beforeTokenTransfer(from, to, amount);
    }
}