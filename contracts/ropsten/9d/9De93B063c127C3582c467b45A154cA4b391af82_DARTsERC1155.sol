// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import {AddressArrayUtils} from "./lib/AddressArrayUtils.sol";
import {UintArrayUtils} from "./lib/UintArrayUtils.sol";
// import "./ERC2981TokenRoyalties.sol";
import "./DartsAccessControl.sol";
import "./lib/ERC1155/ERC1155.sol";
import "./ERC1155URIStorage.sol";
import "hardhat/console.sol";

contract DARTsERC1155 is ERC1155, DartsAccessControl, ERC1155URIStorage {

    using Counters for Counters.Counter;
    using Strings for string;
    using AddressArrayUtils for address[];
    using UintArrayUtils for uint32[];
    using DataTypes for DataTypes.Right;

    Counters.Counter private _tokenIds;

    modifier onlyValidToken(uint _tokenId) {
        require(exists(_tokenId));
        _;
    }

    constructor() ERC1155("") {
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _grantRole(URI_SETTER_ROLE, _msgSender());
        _grantRole(MINTER_ROLE, _msgSender());
        _grantRole(ADD_MEMBER_ROLE, _msgSender());
        _setERC1155construct();
    } 

    function create(
        address[] memory owners,
        address[] memory creators,
        address[] memory sponsors,
        address[] memory thanks,
        string memory _tokenUri
    ) external onlyRole(MINTER_ROLE) returns (bool) {
        require(owners[0] == _msgSender());

        _tokenIds.increment();
        uint newItemId = _tokenIds.current();

        _mint(owners[0], newItemId, 1, "");
        _setTokenURI(newItemId, _tokenUri);

        _create(owners, creators, sponsors, thanks, _tokenUri, newItemId);
        return true;
    }

    function clone(uint formerId, uint _initSupply, uint _editType) external onlyRole(MINTER_ROLE) {
        require(balanceOf(_msgSender(), formerId) == 1);
        require(_msgSender() == Rights[formerId].owners[0]);
        require(Rights[formerId].cloneable == true);

        uint initSupply = 1;
        bool cloneable = true;

        // SELL TYPE
        // if _edittype is 1; Clone for Sell
        if (_editType == 1) {
            initSupply = _initSupply;
            cloneable = false;
        }

        _tokenIds.increment();
        uint newItemId = _tokenIds.current();

        _clone(formerId, newItemId, tokenURI(formerId));

        _mint(_msgSender(), newItemId, initSupply, '');
        _setTokenURI(newItemId, tokenURI(formerId));   
    }

    function setGroupAdmin(uint _tokenId, address _newAdmin, uint8 _adminType) external onlyRole(MINTER_ROLE) onlyValidToken(_tokenId) {
        require(balanceOf(_msgSender(), _tokenId) == 1);
        _setGroupAdmin(_tokenId, _newAdmin, _adminType);
    }

    function propose(uint _tokenId, uint32 _newRoyalty) external onlyValidToken(_tokenId) {
        require(balanceOf(_msgSender(), _tokenId) == 1);
        _propose(_tokenId, _newRoyalty);

    }

    function admit(uint _tokenId) external onlyValidToken(_tokenId) {
        require(balanceOf(_msgSender(), Rights[_tokenId].formerId) == 1);

        Rights[_tokenId].admitPropose();
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data) public virtual override {
        require(
            from == _msgSender() || isApprovedForAll(from, _msgSender())
        );
        _safeTransferFrom(from, to, id, amount, data);
        // Rights[id].owners[0] = to;
        // _grantRole(ADD_MEMBER_ROLE, to);
        // if (Rights[id].cloneable == true) {_grantRole(MINTER_ROLE, to);}
    }

    function setTokenRoyalty(
        uint256 _tokenId,
        address[] memory recipient,
        uint32[] memory value,
        bool is_del_add
     ) external onlyValidToken(_tokenId) {
        _setTokenRoyalty(_tokenId, recipient, value, is_del_add);
    }

    function _beforeTokenTransfer(address operator, address from, address to, uint[] memory ids, uint[] memory amounts, bytes memory data)
        internal override (ERC1155, ERC1155Supply) {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }

    function _burn(
        address from,
        uint256 id,
        uint256 amount
     ) internal override {
        super._burn(from, id, amount);
        _removeTokenURI(id);
    }

    function _burnBatch(
        address from,
        uint256[] memory ids,
        uint256[] memory amounts
     ) internal override {
        super._burnBatch(from, ids, amounts);
        for (uint256 i = 0; i < ids.length; i++) {
            _removeTokenURI(ids[i]);
        }
    }

    function supportsInterface(bytes4 interfaceId)
        public view virtual override(ERC1155, DartsAccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function setTokenURI(uint256 _tokenId, string memory _newURI) external onlyValidToken(_tokenId) {
        require(balanceOf(_msgSender(), _tokenId) >= 1);
        _setTokenURI(_tokenId, _newURI);
    }

}