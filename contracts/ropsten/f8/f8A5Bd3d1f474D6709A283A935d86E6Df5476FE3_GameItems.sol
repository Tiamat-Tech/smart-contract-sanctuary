// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract GameItems is ERC1155, Ownable {
    mapping(uint256 => uint256) private totalSupply;
    mapping(uint256 => address) public creators;

    uint256 public tokenId;

    string public name;
    string public symbol;

    modifier onlyPermission(address _account) {
        require(
            _account == _msgSender() ||
                isApprovedForAll(_account, _msgSender()),
            "GameItems.sol: Caller is not owner nor approved"
        );
        _;
    }

    constructor(
        string memory _name,
        string memory _symbol,
        string memory _uri
    ) ERC1155(_uri) {
        name = _name;
        symbol = _symbol;

        // start with 1
        tokenId = 1;
    }

    function setURI(string memory _uri) external onlyOwner {
        _setURI(_uri);
    }

    function checkTotalSupply(uint256 _id) public view returns (uint256) {
        return totalSupply[_id];
    }

    // function exists(uint256 _id) public view returns (bool) {
    //     return totalSupply[_id] > 0;
    // }

    function create(uint256 _initialSupply, bytes memory _data)
        external
        onlyOwner
        returns (uint256)
    {
        uint256 id = tokenId;
        _mint(msg.sender, id, _initialSupply, _data);

        totalSupply[id] = _initialSupply;
        creators[id] = msg.sender;
        tokenId++;

        return id;
    }

    function mint(
        address _account,
        uint256 _id,
        uint256 _amount,
        bytes memory _data
    ) external {
        require(
            creators[_id] == msg.sender,
            "GameItems.sol: Caller is not creator"
        );

        _mint(_account, _id, _amount, _data);
        totalSupply[_id] += _amount;
    }

    function mintBatch(
        address _to,
        uint256[] memory _ids,
        uint256[] memory _amounts,
        bytes memory _data
    ) external {
        for (uint256 i = 0; i < _ids.length; ++i) {
            require(
                creators[_ids[i]] == msg.sender,
                "GameItems.sol: Caller is not creator"
            );
        }

        _mintBatch(_to, _ids, _amounts, _data);
        for (uint256 i = 0; i < _ids.length; ++i) {
            totalSupply[_ids[i]] += _amounts[i];
        }
    }

    function burn(
        address _account,
        uint256 _id,
        uint256 _amount
    ) public onlyPermission(_account) {
        _burn(_account, _id, _amount);
        totalSupply[_id] -= _amount;
    }

    function burnBatch(
        address _account,
        uint256[] memory _ids,
        uint256[] memory _amounts
    ) public onlyPermission(_account) {
        _burnBatch(_account, _ids, _amounts);
        for (uint256 i = 0; i < _ids.length; ++i) {
            totalSupply[_ids[i]] -= _amounts[i];
        }
    }
}