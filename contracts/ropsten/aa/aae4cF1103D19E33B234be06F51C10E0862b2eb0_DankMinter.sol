// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;
pragma abicoder v2;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./@rarible/royalties/contracts/impl/RoyaltiesV2Impl.sol";
import "./@rarible/royalties/contracts/LibPart.sol";
import "./@rarible/royalties/contracts/LibRoyaltiesV2.sol";
import "./ERC2981ContractWideRoyalties.sol";
import "./IMintable.sol";

contract DankMinter is Initializable, ERC721Upgradeable, ERC721EnumerableUpgradeable, PausableUpgradeable, OwnableUpgradeable, ERC721BurnableUpgradeable, ERC2981ContractWideRoyalties, RoyaltiesV2Impl, IMintable {

    // events
    event MemeMinted(string memeHash, string creator, address owner, uint tokenId, string uri);
    event MemeBurned(string memeHash, address owner, uint tokenId);

    address public imx;
    string private baseURI;

    // mapping: memeId -> memeHash
    mapping (uint => string) private memeToHash;
    // mapping: hash -> memeId
    mapping (string => uint) private hashToMeme;
    // mapping: memeId -> creator address
    mapping (uint => string) private memeCreator;

    // meme struct used for returning memes from function calls
    struct Meme {
        string memeHash;
        string uri;
        uint memeId;
        string creator;
    }

    modifier tokenExists(uint _memeId) {
        require(_exists(_memeId), "meme does not exist");
        _;
    }

    modifier onlyIMX() {
        require(msg.sender == imx, "Function can only be called by IMX");
        _;
    }

    // check if a meme is original
    function isOriginalMeme(string memory _memeHash) public view returns (bool, uint) {
        uint memeId = hashToMeme[_memeHash];
        return (memeId == 0, memeId);
    }

    // getters
    // gets a tokenId with the template + text hash
    function getMemeWithHash(string memory _memeHash) public view returns (Meme memory) {
        uint memeId = hashToMeme[_memeHash];
        return getMeme(memeId);
    }

    // gets a meme template + text hash with token id
    function getMemeHash(uint _tokenId) internal view returns (string memory) {
        return memeToHash[_tokenId];
    }

    // gets meme onchain metadata
    function getMeme(uint _memeId) public view returns (Meme memory) {
        require(_exists(_memeId), "meme does not exist");
        string memory memeHash = getMemeHash(_memeId);
        string memory uri = tokenURI(_memeId);
        string memory creator = memeCreator[_memeId];
        return Meme(memeHash, uri, _memeId, creator);
    }

    // gets all memes in passed in array
    function getMemes(uint[] memory _memeIds) public view returns (Meme[] memory) {
        Meme[] memory userMemes = new Meme[](_memeIds.length);
        for (uint i = 0; i < _memeIds.length; i++) {
            userMemes[i] = getMeme(_memeIds[i]);
        }
        return userMemes;
    }

    // gets all memes owned by the address
    function getUsersMemes(address _userAddress) public view returns (Meme[] memory) {
        uint userNumMemes = balanceOf(_userAddress);
        uint[] memory result = new uint[](userNumMemes);
        for (uint i = 0; i < userNumMemes; i++) {
            uint tokenId = tokenOfOwnerByIndex(_userAddress, i);
            result[i] = tokenId;
        }
        return getMemes(result);
    }

    function mintFor(
        address user,
        uint256 quantity,
        bytes calldata mintingBlob
    ) external override onlyIMX {
        require(quantity == 1, "Mintable: invalid quantity");

        int256 index = indexOf(mintingBlob, ":", 0);
        int256 indexTwo = indexOf(mintingBlob, ":", uint256(index) + 1);

        require(index >= 0, "Separator must exist");

        // Trim the { and } from the parameters
        bytes memory tokenString = mintingBlob[1:uint256(index) - 1];
        uint256 tokenID = toUint(tokenString);
        bytes memory _hash = mintingBlob[uint256(index) + 2:uint256(indexTwo)];
        bytes memory _creator = mintingBlob[uint256(indexTwo) + 1:mintingBlob.length - 1];

        _mintFor(user, tokenID, string(_hash), string(_creator));
    }

    function toUint(bytes memory b) internal pure returns (uint256) {
        uint256 result = 0;
        for (uint256 i = 0; i < b.length; i++) {
            uint256 val = uint256(uint8(b[i]));
            if (val >= 48 && val <= 57) {
                result = result * 10 + (val - 48);
            }
        }
        return result;
    }

    function _mintFor(
        address user,
        uint256 id,
        string memory _hash,
        string memory _creator
    ) internal {
        // set memeid to hash
        memeToHash[id] = _hash;
        // map hash to memeid
        hashToMeme[_hash] = id;
        // assign creator
        memeCreator[id] = _creator;
        _safeMint(user, id);
        emit MemeMinted(_hash, _creator, user, id, tokenURI(id));
    }

   /**
   * Override isApprovedForAll to auto-approve OS's proxy contract
   */
    function isApprovedForAll(
        address _owner,
        address _operator
    ) public override view returns (bool isOperator) {
        // if OpenSea's ERC721 Proxy Address is detected, auto-return true
        if (_operator == address(0x58807baD0B376efc12F5AD86aAc70E78ed67deaE)) {
            return true;
        }
        
        // otherwise, use the default ERC721.isApprovedForAll()
        return ERC721Upgradeable.isApprovedForAll(_owner, _operator);
    }

    // update EIP-2981 royalty value
    function updateRoyalties(address payable _recipient, uint _royalties) public onlyOwner {
        _setRoyalties(_recipient, _royalties);
        setRoyalties(0, _recipient, uint96(_royalties));
    }

    // set rarible royalties
    function setRoyalties(uint _tokenId, address payable _royaltiesReceipientAddress, uint96 _percentageBasisPoints) public onlyOwner {
        LibPart.Part[] memory _royalties = new LibPart.Part[](1);
        _royalties[0].value = _percentageBasisPoints;
        _royalties[0].account = _royaltiesReceipientAddress;
        _saveRoyalties(_tokenId, _royalties);
    }

    function customInitialize(address _owner, address _imx, string calldata _uri) internal {
        imx = _imx;
        baseURI = _uri;
        transferOwnership(_owner); 
        updateRoyalties(payable(_owner), uint96(1000));
    }

    function initialize(address _owner, address _imx, string calldata _uri) initializer public {
        require(_owner != address(0), "Owner must not be empty");
        __ERC721_init("DankMeme", "MEME");
        __Pausable_init();
        __Ownable_init();
        __ERC721Burnable_init();
        customInitialize(_owner, _imx, _uri);
    }

    function setBaseTokenURI(string calldata _uri) public onlyOwner {
        baseURI = _uri;
    }

    function baseTokenURI() public view returns (string memory) {
        return baseURI;
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    // The following functions are overrides required by Solidity.
    function _beforeTokenTransfer(address from, address to, uint256 tokenId)
        internal
        whenNotPaused
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable)
    {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function _burn(uint256 tokenId)
        internal
        override(ERC721Upgradeable)
    {
        emit MemeBurned(memeToHash[tokenId], ownerOf(tokenId), tokenId);
        super._burn(tokenId);
    }

    function contractURI() public view returns (string memory) {
        return string(abi.encodePacked(baseTokenURI(), '/contract'));
    }

    function tokenURI(uint256 _tokenId) override(ERC721Upgradeable) public view returns (string memory) {
        return string(abi.encodePacked(baseTokenURI(), Strings.toString(_tokenId)));
    }

    function supportsInterface(bytes4 interfaceId) 
        public 
        view 
        override(ERC2981ContractWideRoyalties, ERC721Upgradeable, ERC721EnumerableUpgradeable) returns (bool) {
        if(interfaceId == LibRoyaltiesV2._INTERFACE_ID_ROYALTIES) {
            return true;
        }
        return super.supportsInterface(interfaceId);
    }

    function indexOf(
        bytes memory _base,
        string memory _value,
        uint256 _offset
    ) internal pure returns (int256) {
        bytes memory _valueBytes = bytes(_value);

        assert(_valueBytes.length == 1);

        for (uint256 i = _offset; i < _base.length; i++) {
            if (_base[i] == _valueBytes[0]) {
                return int256(i);
            }
        }

        return -1;
    }
}