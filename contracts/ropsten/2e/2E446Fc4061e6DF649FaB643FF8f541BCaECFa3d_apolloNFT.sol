// SPDX-License-Identifier: MIT
// Creator: Shawbot @ The Nexus
// Modified ERC721A contract by Chiru Labs

pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC1155/ERC1155.sol';
import '@openzeppelin/contracts/access/AccessControl.sol';


contract apolloNFT is ERC1155, AccessControl{

    modifier onlyAdmin (){
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Caller is not an admin");
        _;
    }

    constructor(string memory url) ERC1155(url) {
    //constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC1155, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function setURI(string memory newuri) public onlyAdmin{
        _setURI(newuri);
    }

    function mint(address to,
        uint256 id,
        uint256 amount,
        bytes memory data) public onlyAdmin{
        _mint(to,id,amount,data);
    }

    function burn(
        address from,
        uint256 id,
        uint256 amount
    ) public onlyAdmin {
        _burn(from,id,amount);
    }

    function burnBatch(
        address from,
        uint256[] memory ids,
        uint256[] memory amounts
    ) public onlyAdmin {
        require(from != address(0), "ERC1155: burn from the zero address");
        require(ids.length == amounts.length, "ERC1155: ids and amounts length mismatch");

        for (uint256 i = 0; i < ids.length; i++) {
            uint256 id = ids[i];
            uint256 amount = amounts[i];

            uint256 fromBalance = balanceOf(from, id);
            require(fromBalance >= amount, "ERC1155: burn amount exceeds balance");
            unchecked {
                _burn(from,id,amount);
                //_balances[id][from] = fromBalance - amount;
            }
        }

    }

    function setApprovalForAll(
        address owner,
        address operator,
        bool approved
    ) public onlyAdmin {
        _setApprovalForAll(owner,operator,approved);
    }


}