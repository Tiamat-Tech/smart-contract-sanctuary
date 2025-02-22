// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.3;

import "./ERC1155MintBurnPackedBalance.sol";
import "../interfaces/IERC1155Metadata.sol";

contract NFT is ERC1155MintBurnPackedBalance, IERC1155Metadata {

    address public owner;
    string public baseURI;

    constructor(string memory _baseURI) {
        owner = msg.sender;
        baseURI = _baseURI;
    }

    modifier onlyOwner {
        require(msg.sender == owner, "not allowed");
        _;
    }

    function changeOwner(address _newOwner) public onlyOwner {
        owner = _newOwner;
    }

    function changeBaseURI(string memory _newBaseURI) public onlyOwner {
        baseURI = _newBaseURI;
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

    function supportsInterface(bytes4 _interfaceID) public override pure returns (bool) {
        if (_interfaceID == type(IERC1155).interfaceId || _interfaceID == type(IERC1155Metadata).interfaceId) {
            return true;
        }
        return super.supportsInterface(_interfaceID);
    }

    function uri(uint256 _id) external view override returns (string memory) {
        return string(abi.encodePacked(baseURI, _id));
    }
}