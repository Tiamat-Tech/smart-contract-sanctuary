// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155Holder.sol";

import "./interface/IGoatStatus.sol";


contract GoatSplitter is ERC1155, ERC1155Holder {

    struct OriginInfo {
        address token;
        uint256 id;
        uint256 parts;
        uint256[] fragments;
        bool restored;
    }

    IGoatStatus public goatStatus;
    uint256 public nextTokenId = 1;

    mapping(uint256 => string) private tokenUri;
    mapping(uint256 => OriginInfo) private originInfo;

    /** ====================  Event  ==================== */
    event LogSplit(address indexed token, uint256 indexed id, uint256 parts, uint256[] fragments);
    event LogRestore(address indexed token, uint256 indexed id, uint256 parts, uint256[] fragments);

    /** ====================  constractor  ==================== */
    constructor (
        address _goatStatusAddress,
        string memory _uri
    ) 
        public 
        ERC1155(_uri) 
    {
        goatStatus = IGoatStatus(_goatStatusAddress);
    }

    /** ====================  view function  ==================== */
    function uri(
        uint256 _id
    ) 
        external 
        override 
        view 
        returns (string memory) 
    {
		require(_id < nextTokenId, "4001: id not exist");
		return tokenUri[_id];
	}

    function getOriginInfo(
        uint256 _id
    )
        external
        view
        returns (
            address token,
            uint256 id,
            uint256 parts,
            uint256[] memory fragments,
            bool restored
        )
    {
        require(_id < nextTokenId, "4001: id not exist");
        OriginInfo memory info = originInfo[_id];
        return (
            info.token,
            info.id,
            info.parts,
            info.fragments,
            info.restored
        );
    }

    /** ====================  split function  ==================== */
    function split(
        address _token,
        uint256 _id,
        uint256 _parts,
        string[] memory _uris,
        address _receiver
    ) 
        external
        returns (uint256[] memory) 
    {
        require(_token != goatStatus.rentalWrapperAddress(), "4002: can not split the rented token");
        require(_parts == _uris.length, "4003: invalid uri length");

        IERC1155(_token).safeTransferFrom(msg.sender, address(this), _id, 1, "");
        
        uint256[] memory ids = new uint256[](_parts);
        uint256[] memory amounts = new uint256[](_parts);
        
        for (uint256 i = 0; i < _parts; i++) {
            uint256 splitId = _getNextTokenId();
            ids[i] = splitId;
            amounts[i] = 1;

            tokenUri[splitId] = _uris[i];

            if (bytes(_uris[i]).length > 0) {
                emit URI(_uris[i], splitId);
            }
        }

        OriginInfo memory info = OriginInfo(_token, _id, _parts, ids, false);

        for (uint256 i = 0; i < _parts; i++) {
            originInfo[ids[i]] = info;
        }

        _mintBatch(_receiver, ids, amounts, "");

        emit LogSplit(_token, _id, _parts, info.fragments);

        return ids;
    }

    /** ====================  restore function  ==================== */
    function restore(
        uint256 _fragmentId
    ) 
        external 
    {
        require(_fragmentId < nextTokenId, "4001: id not exist");
        OriginInfo memory info = originInfo[_fragmentId];
        require(!info.restored, "4004: fragments have been restored");
        
        uint256[] memory amounts = new uint256[](info.parts);
        for (uint256 i = 0; i < info.parts; i++) {
            amounts[i] = 1;
            originInfo[info.fragments[i]].restored = true;
        }

        _burnBatch(msg.sender, info.fragments, amounts);

        IERC1155(info.token).safeTransferFrom(address(this), msg.sender, info.id, 1, "");

        emit LogRestore(info.token, info.id, info.parts, info.fragments);
    }

    function _getNextTokenId() 
        internal 
        returns (uint256 id) 
    {
        id = nextTokenId;
        nextTokenId++;
    }

}