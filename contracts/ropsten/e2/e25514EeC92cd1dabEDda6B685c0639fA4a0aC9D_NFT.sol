// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.3;

import "./ERC1155MintBurnPackedBalance.sol";

contract NFT is ERC1155MintBurnPackedBalance {

    address public owner;

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner {
        require(msg.sender == owner, "not allowed");
        _;
    }

    function changeOwner(address _newOwner) public onlyOwner {
        owner = _newOwner;
    }

    function mint(address _to, uint256 _id, uint256 _amount) public onlyOwner {
        _mint(_to, _id, _amount, "");
    }

    function batchMint(address _to, uint256[] memory _ids, uint256[] memory _amounts) public onlyOwner {
        _batchMint(_to, _ids, _amounts, "");
    }

    function burn(address _from, uint256 _id, uint256 _amount) public onlyOwner {
        _burn(_from, _id, _amount);
    }

    function batchBurn(address _from, uint256[] memory _ids, uint256[] memory _amounts) public onlyOwner {
        _batchBurn(_from, _ids, _amounts);
    }
}