// SPDX-License-Identifier:MIT
pragma solidity >=0.7.0 <0.9.0;


import "@openzeppelin/contracts/token/ERC721/presets/ERC721PresetMinterPauserAutoId.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Pausable.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./BaseRelayRecipient.sol";


contract TechDay20211217 is
    Context,
    AccessControlEnumerable,
    ERC721Enumerable,
    ERC721Burnable,
    BaseRelayRecipient
{
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;
    bytes32 private constant _MINT_FROZEN_ROLE = keccak256("MINT_FROZEN_ROLE");

    mapping(uint16 => bool) private _mintables;
    mapping(uint16 => mapping(bool => string)) private _sessionCodeToURI;
    mapping(uint256 => uint16) private _tokenIdToSessionCode;
    mapping(address =>  mapping(uint16 => bool)) private _balances;

    constructor() ERC721("TEST Tech Day 9999-99-99", "TEST_TECH_DAY_9999-99-99") {
        _setupRole(_MINT_FROZEN_ROLE, _msgSender());
        _sessionCodeToURI[2011][false] = "https://bafkreieia7c7xudgjoxohbe5t7hym4qihvfndct5rlhdx4ejm4as2r77d4.ipfs.dweb.link";
        _sessionCodeToURI[2018][false] = "https://bafkreic2tvbrc56rfxbtvlbrkvpypv53fc3tdeaywwk7u4yfmdkqkmh7lq.ipfs.dweb.link";
        _sessionCodeToURI[1223][false] = "https://bafkreih6mc7hkkfhftou3ki4cwer27fuuk5aps4iyfpjvfv3ch6aprqzke.ipfs.dweb.link";
        _sessionCodeToURI[9777][false] = "https://bafkreia6kylskckn625okxjd4loarlrtjprypxphntz3v5id52mtgpkznu.ipfs.dweb.link";
        _sessionCodeToURI[8428][false] = "https://bafkreiauukftlvxe5rx4qqh3kvami25du6pt2foi7yttqzwepepohwn7tq.ipfs.dweb.link";
        _sessionCodeToURI[6220][false] = "https://bafkreifacd2t3fqg2zryaobyjvq3mxkdy3ev2y6g4l7tzj5vvf2uys2oza.ipfs.dweb.link";
        _sessionCodeToURI[9203][false] = "https://bafkreihhefbuy6n5j4aaklmvhppsfothfjadkrh6sfck3zsq6xkncc2gvu.ipfs.dweb.link";
        _sessionCodeToURI[8969][false] = "https://bafkreifwvzvnfw32ktkvqphhcpzey4yqd3edmnqi7yb5hk5t4g23cs25zy.ipfs.dweb.link";
        _sessionCodeToURI[1593][false] = "https://bafkreigq7ithcvzubi6tye4rkazwdgyskp5v3o2jscufctrqztvkc4yzga.ipfs.dweb.link";
        _sessionCodeToURI[1600][false] = "https://bafkreicfts7r3jc65i37qf5hxjvj4usymd2bfe57z4m4ani4dlstiqbyky.ipfs.dweb.link";
        _sessionCodeToURI[2011][true] = "https://bafkreiffcgkna7tmpobgdn4qvy6drzrw6x75etvwejylgeykluhslyc2ya.ipfs.dweb.link";
        _sessionCodeToURI[2018][true] = "https://bafkreicyiu2lagefrmtps6zfweshtp72v2ce3rsxwsgen6g7khlirh2qcq.ipfs.dweb.link";
        _sessionCodeToURI[1223][true] = "https://bafkreifkwow3fqakwkh5kogc2qzyi4f3ym2d6wixfbiznkybfbxnzp6c4m.ipfs.dweb.link";
        _sessionCodeToURI[9777][true] = "https://bafkreicgsd2dqfab52v27zivyw5wqgoqa2ogn6guavj7obpgkd33yjrzj4.ipfs.dweb.link";
        _sessionCodeToURI[8428][true] = "https://bafkreihsaymedwxrgvecygxz7ejcrczpsgzxzg25vorfh2ijtejlebqlba.ipfs.dweb.link";
        _sessionCodeToURI[6220][true] = "https://bafkreiby4hrhptbcz55t2eh4haaz7uv6py4eid6c4lyqf2hupm3cp2zoje.ipfs.dweb.link";
        _sessionCodeToURI[9203][true] = "https://bafkreig2ne5bwewphx3pxdb3h3xlwg7lfdjm2pztsfzhcblpelafaixv74.ipfs.dweb.link";
        _sessionCodeToURI[8969][true] = "https://bafkreidfkhsscyfcb557byjpsisunbfne4yb6mpmdya7vy6pkxdwtpbkvu.ipfs.dweb.link";
        _sessionCodeToURI[1593][true] = "https://bafkreiafgsgwd3tuwbsqz2krgispxqreaxjbe7ny2bwkagzu5qopfhtyzm.ipfs.dweb.link";
        _sessionCodeToURI[1600][true] = "https://bafkreidpfaajhct47mkoeq7iudid47f3ajsxtptp5f2ikpceqd6pgm7jwi.ipfs.dweb.link";
        _mintables[2011] = true;
        _mintables[2018] = true;
        _mintables[1223] = true;
        _mintables[9777] = true;
        _mintables[8428] = true;
        _mintables[6220] = true;
        _mintables[9203] = true;
        _mintables[8969] = true;
        _mintables[1593] = true;
        _mintables[1600] = true;
    }
    
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "URI query for nonexistent token");
        uint16 sessionCode = _tokenIdToSessionCode[tokenId];
        mapping(bool => string) storage uris = _sessionCodeToURI[sessionCode];
        string memory uri = uris[uint(keccak256(abi.encodePacked(tokenId))) % 10 == 0];
        return bytes(uri).length > 0 ? string(abi.encodePacked(uri, "")) : "";
    }
    
    function setMintable(bool mintable, uint16 sessionCode) public virtual {
        require(hasRole(_MINT_FROZEN_ROLE, _msgSender()), "Must have MINT_FROZEN role to change mintable");
        require(bytes(_sessionCodeToURI[sessionCode][false]).length != bytes("").length, "invalid sessionCode");
        _mintables[sessionCode] = mintable;
    }
    
    function mint(address to, uint16 sessionCode) public virtual {
        require(bytes(_sessionCodeToURI[sessionCode][false]).length != bytes("").length, "invalid sessionCode");
        require(_mintables[sessionCode], "Mint permission is not enable");
        require(!_balances[to][sessionCode], "Cannot own the same NFT.");
        uint256 tokenId = _tokenIdCounter.current();
        _mint(to, tokenId);
        _tokenIdToSessionCode[tokenId] = sessionCode;
        _balances[to][sessionCode] = true;
        _tokenIdCounter.increment();
    }
    
    function _msgSender() internal virtual view override(BaseRelayRecipient, Context) returns (address) {
        return BaseRelayRecipient._msgSender();
    }
    
    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        require(!_balances[to][_tokenIdToSessionCode[tokenId]], "Cannot own the same NFT.");
        super.safeTransferFrom(from, to, tokenId);
        _balances[from][_tokenIdToSessionCode[tokenId]] = false;
        _balances[to][_tokenIdToSessionCode[tokenId]] = true;
    }

    /**
     * @dev See {IERC721-transferFrom}.
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        require(!_balances[to][_tokenIdToSessionCode[tokenId]], "Cannot own the same NFT.");
        super.transferFrom(from, to, tokenId);
        _balances[from][_tokenIdToSessionCode[tokenId]] = false;
        _balances[to][_tokenIdToSessionCode[tokenId]] = true;
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(AccessControlEnumerable, ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}