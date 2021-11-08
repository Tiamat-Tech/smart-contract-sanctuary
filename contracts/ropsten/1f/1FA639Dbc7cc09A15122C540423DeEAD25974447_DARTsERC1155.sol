// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

import "hardhat/console.sol";

contract DARTsERC1155 is ERC1155, Ownable, Pausable {
    using Counters for Counters.Counter;
    using Strings for string;

    string internal _uri;
    Counters.Counter private _tokenIds;

    struct Right {
        uint id;
        address owner;
        uint quantity;
        string uri;
        bool cloneable;
        bytes metadata;
    }

    mapping (uint => Right) public Rights;
    mapping (uint => address) public creators;


    /**
    * @dev Require msg.sender to be the creator of the token id
    */
    modifier creatorOnly(uint _id) {
        require(creators[_id] == msg.sender, "ERC1155Tradable#creatorOnly: ONLY_CREATOR_ALLOWED");
        _;
    }

    constructor(string memory _URI) ERC1155(_URI) {
        setURI(_URI);
    }

    function create(address _initialOwner, uint _initialSupply, bool _cloneable, bytes calldata _metadata) external onlyOwner returns (uint) {
        _tokenIds.increment();
        uint newItemId = _tokenIds.current();
        creators[newItemId] = _initialOwner;
        _mint(_initialOwner, newItemId, _initialSupply, _metadata);

        Rights[newItemId] = Right(newItemId, _initialOwner, _initialSupply, uri(newItemId), _cloneable, _metadata);
        return newItemId;
    }

    function clone(address _otherOwner, uint _tokenId, uint _supply) external returns (uint) {
        Right storage item = Rights[_tokenId];
        require(_exists(_tokenId), "ERC721Tradable#clone: NONEXISTENT_TOKEN");
        require(item.cloneable, "ERC721Tradable#clone: This item is not cloneable");

        _mint(_otherOwner, _tokenId, _supply, item.metadata);
        item.quantity += _supply;

        return item.id;
    }

    function getItem(uint _tokenId) public view returns (Right memory) {
        return Rights[_tokenId];
    }

    function setURI(string memory newuri) public onlyOwner {
        _setURI(newuri);
        _uri = newuri;
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function mint(address account, uint id, uint amount)
    public
    onlyOwner
    {
        _mint(account, id, amount, "");
    }

    function mintBatch(address to, uint[] memory ids, uint[] memory amounts, bytes memory data)
    public
    onlyOwner
    {
        _mintBatch(to, ids, amounts, data);
    }

    function _beforeTokenTransfer(address operator, address from, address to, uint[] memory ids, uint[] memory amounts, bytes memory data)
    internal
    whenNotPaused
    override
    {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }

    function uri(
        uint _id
    ) public view virtual override returns (string memory) {
        require(_exists(_id), "ERC721Tradable#uri: NONEXISTENT_TOKEN");
        return string(abi.encodePacked(_uri, Strings.toString(_id), ".json"));
    }

    /**
    * @dev Returns whether the specified token exists by checking to see if it has a creator
    * @param _id uint ID of the token to query the existence of
    * @return bool whether the token exists
    */
    function _exists(
        uint _id
    ) internal view returns (bool) {
        return creators[_id] != address(0);
    }
}