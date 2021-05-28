// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155Holder.sol";

import "./interface/IGoatStatus.sol";
import "./interface/IGoatRental.sol";


contract GoatRentalWrapper is ERC1155, ERC1155Holder {

    struct WrapInfo {
        address owner;
        address token;
        uint256 id;
        uint256 rentalTerm;
    }

    uint256 public nextTokenId = 1;

    IGoatStatus public goatStatus;

    mapping (uint256 => string)      private tokenUri;
    mapping (uint256 => WrapInfo)    private  wrapInfo;

    mapping (uint256 => address[])   private holders;
    mapping (uint256 => mapping(address => bool)) private isHolder;

    
    /** ====================  Event  ==================== */
    event LogWrap(address indexed token, uint256[] originIds, uint256[] wrappedIds, uint256[] amounts);
    event LogUnwrap(address indexed token, uint256[] originIds, uint256[] wrappedIds, uint256[] amounts);

    
    modifier onlyGoatRental() {
        require(msg.sender == goatStatus.rentalAddress(), "3001: no right to call");
        _;
    }
    
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


    function uri(
        uint256 _id
    ) 
        external 
        override 
        view 
        returns (string memory) 
    {
		require(_id < nextTokenId, "3002: id not exist");
		return tokenUri[_id];
	}

    function getWrapInfo(
        uint256 _wrappedId
    ) 
        external 
        view 
        returns (
            address owner,
            address originToken,
            uint256 originId,
            uint256 rentalTerm
        ) 
    {
        require(_wrappedId < nextTokenId, "3002: id not exist");
        WrapInfo memory info = wrapInfo[_wrappedId];
        return (
            info.owner,
            info.token, 
            info.id, 
            info.rentalTerm
        );
    }
    

    function wrap(
        address _owner,
        address _token,
        uint256[] memory _ids,
        uint256[] memory _amounts,
        address _receiver,
        uint256 _rentalTerm
    )
        external 
        onlyGoatRental
        returns (uint256[] memory) 
    {           
        IERC1155(_token).safeBatchTransferFrom(msg.sender, address(this), _ids, _amounts, "");
        
        uint256[] memory wrappedIds = new uint256[](_ids.length);
        
        for (uint256 i = 0; i < _ids.length; i++) {
            uint256 wrappedId = nextTokenId;
            nextTokenId++;

            wrappedIds[i] = wrappedId;
            
            string memory _uri = _getTokenUri(_token, _ids[i]);
            tokenUri[wrappedId] = _uri;
            if (bytes(_uri).length > 0) {
			    emit URI(_uri, wrappedId);
            }

            wrapInfo[wrappedId] =  WrapInfo(_owner, _token, _ids[i], _rentalTerm);
        }

        _mintBatch(_receiver, wrappedIds, _amounts, "");

        emit LogWrap(_token, _ids, wrappedIds, _amounts);

        return wrappedIds;
    }

    // can only unwrap the same rental order wrapped ids
    function unwrap(
        uint256[] memory _wrappedIds,
        uint256[] memory _amounts,
        address _receiver
    ) 
        public
        onlyGoatRental
    {   
        
        WrapInfo memory info = wrapInfo[_wrappedIds[0]];
        address originToken = info.token;
        uint256 rentalTerm = info.rentalTerm;

        require(block.timestamp >= rentalTerm, "3003: can not unwrap until rental term");
        
        uint256[] memory originIds = new uint256[](_wrappedIds.length);
        
        for (uint256 i = 0; i < _wrappedIds.length; i++) {
            uint256 wrappedId = _wrappedIds[i];
            originIds[i] = wrapInfo[wrappedId].id;
            
            address[] memory wrappedHolders = holders[wrappedId];
            for (uint256 j = 0; j < wrappedHolders.length; j++) {
                address holder = wrappedHolders[j];
                uint256 balance = balanceOf(holder, wrappedId);
                if (balance > 0) {
                    _burn(wrappedHolders[j], wrappedId, balance);
                }
            }
        }

        if (originToken != address(this)) {
            IERC1155(originToken).safeBatchTransferFrom(address(this), _receiver, originIds, _amounts, "");
            emit LogUnwrap(originToken, originIds, _wrappedIds, _amounts);
        }
    }


    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    )
        internal
        override
    { 
        if (to != address(0)) {
            for (uint256 i = 0; i < ids.length; i++) {
                require(wrapInfo[ids[i]].rentalTerm > block.timestamp, "3004: this wrapped token has expired");
                _addHolders(ids[i], to);
            }
        } else {
            require(msg.sender == goatStatus.rentalAddress(), "3005: wrapped token can not  be sent to zero address");
        }
    }

    function _addHolders(
        uint256 _id,
        address _holder
    )
        internal
    {
        if (!isHolder[_id][_holder]) {
            isHolder[_id][_holder] = true;
            holders[_id].push(_holder);
        }
    }

    function _getTokenUri(
        address _token, 
        uint256 _id
    ) 
        internal 
        view 
        returns (string memory originUri)
    {
        try IERC1155MetadataURI(_token).uri(_id) returns (string memory _uri) {
            originUri = _uri;
        } catch {}
    }
}