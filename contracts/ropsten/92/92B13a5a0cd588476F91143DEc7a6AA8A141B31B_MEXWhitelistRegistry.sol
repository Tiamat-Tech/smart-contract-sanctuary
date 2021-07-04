// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import '@openzeppelin/contracts/access/Ownable.sol';

interface IMEXWhitelistRegistry {
    function isWhitelisted(uint256 _tokenId, address _from, address _to) external view returns (bool); 
}

contract MEXWhitelistRegistry is IMEXWhitelistRegistry, Ownable {
    mapping (address => bool) private _recipientsGlobal;
    mapping (uint256 => mapping (address => bool)) private _recipientsPerItem;
    mapping (address => bool) private _senders;

    constructor()
    {
        _senders[address(0x0)] = true;
    }

    function addSender(address _addr)
        public onlyOwner
    {
        _senders[_addr] = true;
    }

    function removeSender(address _addr)
        public onlyOwner
    {
        delete _senders[_addr];
    }

    function addRecipient(address _addr, bool global, uint256 _tokenId)
        public onlyOwner
    {
        if(global) {
            _recipientsGlobal[_addr] = true;
        } else {
            _recipientsPerItem[_tokenId][_addr] = true;
        }
    }

    function removeRecipient(address _addr, bool global, uint256 _tokenId)
        public onlyOwner
    {
        if(global) {
            delete _recipientsGlobal[_addr];
        } else {
            delete _recipientsPerItem[_tokenId][_addr];
        }
    }

    function isWhitelisted(uint256 _tokenId, address _from, address _to)
        public view override returns (bool)
    {
        if(_senders[_from] || _recipientsPerItem[_tokenId][_to] || _recipientsGlobal[_to]) {
            return true;
        }
        return false;
    }
}
/**
 * @dev ERC721 token with transfer restriction
 */
abstract contract ERC721LimitedTransfer is ERC721 {
    enum AccessType {OPEN, NON_CONTRACT, LIMIT}

    // Mapping from token ID to owner address
    mapping (uint256 => AccessType) private _accessTypes;
    address public whitelistRegistryAddress;

    // Events
    event SetAccessType(uint256, AccessType);

    function _setWhitelistRegistryAddress(address _registry)
        internal virtual
    {
        whitelistRegistryAddress = _registry;
    }

    function _isContract(address _addr)
        internal virtual returns(bool)
    {
        uint size;
        require(msg.sender == tx.origin, "Permitted only sending to non-contract addressed");
        assembly { size := extcodesize(_addr) }
        return size > 0 || _addr.balance == 0;
    }

    function _beforeTokenTransfer(address _from, address _to, uint256 _tokenId)
        internal virtual override (ERC721)
    {

        if(whitelistRegistryAddress == address(0x0) || _from == address(0x0)) {
            return;
        }

        if(accessType(_tokenId) == AccessType.OPEN) {
            return;
        }

        if(IMEXWhitelistRegistry(whitelistRegistryAddress).isWhitelisted(_tokenId, _from, _to)) {
            return;
        }

        if(accessType(_tokenId) == AccessType.NON_CONTRACT && !_isContract(_to)) {
            return;
        }

        revert("Not permitted to send");
    }

    function accessType(uint256 tokenId)
        public view virtual returns (AccessType)
    {
        require(_exists(tokenId), "ERC721LimitedTransfer: AccessType query for nonexistent token");
        return _accessTypes[tokenId];
    }

    function _setAccessType(uint256 tokenId, AccessType _accessType)
        internal virtual
    {
        require(_exists(tokenId), "ERC721LimitedTransfer: AccessType set of nonexistent token");
        _accessTypes[tokenId] = _accessType;
        emit SetAccessType(tokenId, _accessType);
    }

    function _burn(uint256 tokenId)
        internal virtual override
    {
        super._burn(tokenId);
        delete _accessTypes[tokenId];
    }
}

contract MEXNFT is ERC721URIStorage, ERC721LimitedTransfer, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    constructor() public Ownable() ERC721("MostExpensive :: Physical Asset", "MEX") {}

    function mint(address _owner, string memory _tokenURI, AccessType _accessType)
        public onlyOwner
    {
        _tokenIds.increment();

        uint256 tokenId = _tokenIds.current();
        super._safeMint(_owner, tokenId);
        super._setTokenURI(tokenId, _tokenURI);
        super._setAccessType(tokenId, _accessType);
    }

    function getLastTokenId()
        public view returns(uint256)
    {
        return _tokenIds.current();
    }

    function tokenURI(uint256 tokenId)
        public view virtual override(ERC721URIStorage, ERC721) returns (string memory)
    {
        return ERC721URIStorage.tokenURI(tokenId);
    }

    function _burn(uint256 tokenId)
        internal virtual override(ERC721LimitedTransfer, ERC721URIStorage)
    {
        return ERC721URIStorage._burn(tokenId);
    }

    function _beforeTokenTransfer(address _from, address _to, uint256 _tokenId)
        internal virtual override (ERC721, ERC721LimitedTransfer) 
    {
        ERC721LimitedTransfer._beforeTokenTransfer(_from, _to, _tokenId);
    }

    function setWhitelistRegistryAddress(address _registry)
        public onlyOwner 
    {
        super._setWhitelistRegistryAddress(_registry);
    }

}