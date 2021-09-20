// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/Counters.sol";


contract NFTTest is
    Context,
    ERC721
{
    event Mint(
        bytes32 indexed phraseId,
        uint256 indexed tokenId,
        string phrase
    );

    uint MAX_SUPPLY = 1000;
    uint DEV_RESERVED = 33;
    uint256 PRICE = 5 * 10 ** 16; // 0.05 ETH
    uint256 DAO_DONATION = 5 * 10 ** 15; // 0.005 ETH

    // DAO 0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266
    // Dev1 0x70997970c51812dc3a010c7d01b50e0d17dc79c8
    // Dev2 0x3c44cdddb6a900fa2b585dd299e03d12fa4293bc

    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdTracker;
    Counters.Counter private _devReserveTracker;

    mapping(bytes32 => uint256) private _phraseIdToTokenId;

    mapping(uint256 => bytes32) private _tokenIdToPhraseId;

    mapping(uint256 => string) private _tokenIdToWords;

    constructor(
        string memory name,
        string memory symbol
    ) ERC721(name, symbol) {
        _tokenIdTracker.increment(); // start tokenIds from 1
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");
        return string(abi.encodePacked("https://3wordsproject.com/metadata/", Strings.toString(tokenId), ".json"));
    }

    function tokenIdToPhraseId(uint256 tokenId) public view returns (bytes32) {
        require(_exists(tokenId), "ERC721Metadata: tokenPhrase query for nonexistent token");

        return _tokenIdToPhraseId[tokenId];
    }

    function phraseToTokenId(string memory _phrase) public view returns (uint256) {
        return phraseIdToTokenId(phraseToPhraseId(_phrase));
    }

    function phraseToPhraseId(string memory _phrase) public view returns (bytes32) {
        return keccak256(abi.encodePacked(_phrase));
    }

    function phraseIdToTokenId(bytes32 phraseId) public view returns (uint256) {
        uint256 tokenId = _phraseIdToTokenId[phraseId];
        require(tokenId != 0 && _exists(tokenId), "ERC721Metadata: tokenPhrase query for nonexistent token");
        return tokenId;
    }

    function tokenIdToWords(uint256 tokenId) public view returns (string memory) {
        return _tokenIdToWords[tokenId];
    }

    function mint(string memory _phrase)
        public
        payable
    {
        address payable dao = payable(0xa689f0c3E7aec4B6702b9C5F9c55f31115604f76);
        address payable dev1 = payable(0x85Ca88234f68B6019aB0C4Bb5B54816488ae7790);
        address payable dev2 = payable(0x9a4a2e7e0c31898Dcb89487471E45c662858b4A0);

        require (bytes(_phrase).length <= 64, "phrase must be less than 64 bytes");
        address receiver = _msgSender();
        require (msg.value >= PRICE, "must pay mint fee");
        uint256 afterFee = msg.value - DAO_DONATION;
        dao.call{value: DAO_DONATION}("");
        dev1.call{value: afterFee / 2}("");
        dev2.call{value: afterFee / 2}("");
        bytes32 phraseId = phraseToPhraseId(_phrase);
        require(_phraseIdToTokenId[phraseId] == 0, "phrase already minted"); // this is why we start tokenid at 1
        uint256 tokenId = _tokenIdTracker.current();
        _phraseIdToTokenId[phraseId] = tokenId;
        _tokenIdToPhraseId[tokenId] = phraseId;
        _tokenIdToWords[tokenId] = _phrase;
        _mint(receiver, tokenId);
        _tokenIdTracker.increment();
        emit Mint(phraseId, tokenId, _phrase);
    }
}