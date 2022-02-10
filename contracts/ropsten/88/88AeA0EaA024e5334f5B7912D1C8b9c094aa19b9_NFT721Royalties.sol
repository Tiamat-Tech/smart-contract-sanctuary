//SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.11;

import '@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol';
import '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import '@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol';

import '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';

import '@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol';
import './@rarible/contracts/royalties/LibPart.sol';
import './@rarible/contracts/royalties/IRoyaltiesProvider.sol';
import './@rarible/contracts/royalties/impl/AbstractRoyalties.sol';
import './@rarible/contracts/royalties/impl/RoyaltiesV2Impl.sol';
import './@rarible/contracts/royalties/LibRoyalties2981.sol';
import './@rarible/contracts/royalties/LibRoyaltiesV2.sol';
import './@rarible/contracts/royalties/RoyaltiesV2.sol';


contract NFT721Royalties is Initializable, 
OwnableUpgradeable,
ERC721Upgradeable,
RoyaltiesV2Impl,
UUPSUpgradeable
{

    using CountersUpgradeable for CountersUpgradeable.Counter;

    CountersUpgradeable.Counter public _tokenIDTracker;

    string public _BASE_URI;
/**Function used in upgradeable contracts as a constructor */
    function initialize (
        string memory _name,
        string memory _symbol, 
        string memory _baseuri
    ) public initializer {
        
        ERC721Upgradeable.__ERC721_init(_name, _symbol);
        __Ownable_init();
        __UUPSUpgradeable_init();
        __RoyaltiesV2Impl_init();
        __NFT721Royalties_init_unchained(_baseuri);

    }

/**Fucntion to initailize this contracts address */
    function __NFT721Royalties_init_unchained(string memory _baseuri) internal {
        _BASE_URI = _baseuri;
    }

    function _baseURI() internal view override(ERC721Upgradeable) returns (string memory){
        return _BASE_URI;
    }


    function mint(address _to) public onlyOwner{
        _tokenIDTracker.increment();
        
        _mint(_to, _tokenIDTracker.current());
    }

    function setRoyalties(uint _tokenId, address payable _royaltiesReceipientAddress, uint96 _percentageBasisPoints) public onlyOwner {
        LibPart.Part[] memory _royalties = new LibPart.Part[](1);
        _royalties[0].value = _percentageBasisPoints;
        _royalties[0].account = _royaltiesReceipientAddress;
        _saveRoyalties(_tokenId, _royalties);
    }
/**Function override from UUPSUpgradeable */
    function _authorizeUpgrade(address newImplementation) 
    internal 
    override(UUPSUpgradeable) onlyOwner{}

   function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721Upgradeable) returns (bool) {
        if(interfaceId == LibRoyaltiesV2._INTERFACE_ID_ROYALTIES) {
            return true;
        }
        return super.supportsInterface(interfaceId);
    }
}