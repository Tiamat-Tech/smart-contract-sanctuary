// contracts/DontBurnMeme.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract DontBurnMeme is ERC1155, Ownable {
    // Mapping from token ID to media key
    mapping(uint256 => string) private _tokenMedia;
    address public minter;

    constructor(address _minter, string memory _uri) ERC1155(_uri) {
        minter = _minter;
    }

    modifier onlyMinter() {
        require(
            owner() == msg.sender || minter == msg.sender,
            "must be owner or minter"
        );
        _;
    }

    function setMinter(address _minter) public virtual onlyOwner {
        minter = _minter;
    }

    function setURI(string memory newuri) public virtual onlyOwner {
        _setURI(newuri);
    }

    function setTokenMedia(uint256 id, string memory key)
        public
        virtual
        onlyOwner
    {
        _setTokenMedia(id, key);
    }

    function mint(
        address account,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public onlyMinter {
        // if (_isMediaEmpty(_tokenMedia[id])) {
        //     _setTokenMedia(id, _uint2str(id));
        // }
        _mint(account, id, amount, data);
    }

    function uri(uint256 id) public view override returns (string memory) {
        string memory _uri = _tokenMedia[id];
        if (bytes(_uri).length > 0) {
            return string(abi.encodePacked(super.uri(id), _uri));
        } else {
            revert("no uri data set for token id");
        }
    }

    function burn(
        address account,
        uint256 id,
        uint256 value
    ) public virtual {
        require(
            account == _msgSender() || isApprovedForAll(account, _msgSender()),
            "caller is not owner nor approved"
        );

        _burn(account, id, value);
        _afterBurn(account, id);
    }

    function burnBatch(
        address account,
        uint256[] memory ids,
        uint256[] memory values
    ) public virtual {
        require(
            account == _msgSender() || isApprovedForAll(account, _msgSender()),
            "caller is not owner nor approved"
        );

        _burnBatch(account, ids, values);
        _afterBurn(account, ids[0]);
    }

    function _setTokenMedia(uint256 id, string memory key) internal virtual {
        _tokenMedia[id] = key;
    }

    function _afterBurn(address account, uint256 id) internal virtual {
        uint256 nextId = id + 1;

        if (_isMediaEmpty(_tokenMedia[nextId])) {
            _setTokenMedia(nextId, _uint2str(nextId));
        }
        _mint(account, nextId, 1, "");
    }

    function _isMediaEmpty(string memory tokenMedia)
        internal
        virtual
        returns (bool)
    {
        bytes memory mediaToken = bytes(tokenMedia);

        if (mediaToken.length == 0) {
            return true;
        } else {
            return false;
        }
    }

    function _uint2str(uint256 _i)
        internal
        pure
        returns (string memory _uintAsString)
    {
        if (_i == 0) {
            return "0";
        }
        uint256 j = _i;
        uint256 len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint256 k = len - 1;
        while (_i != 0) {
            bstr[k--] = bytes1(uint8(48 + (_i % 10)));
            _i /= 10;
        }
        return string(bstr);
    }
}