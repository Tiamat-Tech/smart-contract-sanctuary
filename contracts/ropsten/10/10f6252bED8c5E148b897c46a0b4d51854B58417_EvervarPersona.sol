// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract EvervarPersona is ERC721Enumerable, Ownable {
    using Counters for Counters.Counter;
    using SafeMath for uint256;
    using Strings for uint256;
    using ECDSA for bytes32;

    Counters.Counter public tokenIdCounter;
    Counters.Counter public whitelistIdCounter;
    Counters.Counter public prizeIdCounter;

    uint public constant MAX_PERSONA = 10000;
    uint public constant WHITELIST_MINTS = 500;
    uint public constant PRIZE_MINTS = 200;
    uint public constant RESERVED_MINTS = WHITELIST_MINTS + PRIZE_MINTS;
    
    bool public BLOCK_CONTRACTS = true;
    bool public ENABLE_DIRECT_MINT = false;
    bool public SALE_IS_ACTIVE = false;
    bool public PRESALE_IS_ACTIVE = false;
    uint public LIMIT_PER_ACCOUNT = 10;
    uint public mintPrice = 60000000000000000;
    uint public startingIndex;
    uint public startingIndexBlock;
    string public PROVENANCE_HASH;

    mapping(address => uint) public earlyMintAllowance;
    mapping(address => bool) public whitelistWinners;
    mapping(address => uint) private _publicSaleMintCounts;
    mapping(string => bool) private _usedNonces;

    string private _baseTokenURI;
    address private _signerAddress;


    constructor() ERC721("Evervar:Persona", "EVERVAR") {
        tokenIdCounter.increment();
        whitelistIdCounter.increment();
        prizeIdCounter.increment();
    }

    function mintPersona(uint _count) external payable {
        require(SALE_IS_ACTIVE, "Sale not active");
        require(_count <= 10, "You can't mint more than 10 personas at once");

        _mintPersona(_msgSender(), _count);

        _publicSaleMintCounts[_msgSender()] += _count;
    }

    function earlyMintPersona(uint _count) external payable {
        require(PRESALE_IS_ACTIVE, "Sale not active");
        require(_count <= earlyMintAllowance[_msgSender()], "Exceeds allowed amount");
        
        _mintPersona(_msgSender(), _count);

        earlyMintAllowance[_msgSender()] -= _count;
    }

    function _mintPersona(address to, uint _count) internal virtual {
        require(!BLOCK_CONTRACTS || tx.origin == _msgSender());
        require(_count > 0, "Count too low");
        require(msg.value >= price(_count), "Value below price");
        require(tokenIdCounter.current().sub(1).add(RESERVED_MINTS).add(_count) <= MAX_PERSONA, "Exceeds available mints");

        for(uint i = 0; i < _count; i++){
            _safeMint(to, tokenIdCounter.current().add(RESERVED_MINTS));
            tokenIdCounter.increment();
        }
    }

    function whitelistMintPersona() public {
        require(whitelistWinners[_msgSender()], "Exceeds allowed amount");
        require(whitelistIdCounter.current() <= WHITELIST_MINTS, "Exceeds available mints");
        
        _safeMint(_msgSender(), whitelistIdCounter.current().add(PRIZE_MINTS));
        whitelistIdCounter.increment();
        
        whitelistWinners[_msgSender()] = false;
    }

    function reservePersona(address reserveAddress) external onlyOwner {
        require(startingIndex == 0);

        for(uint i = 0; i < PRIZE_MINTS; i++){
            _safeMint(reserveAddress, prizeIdCounter.current());
            prizeIdCounter.increment();
        }

        if (startingIndexBlock == 0) {
            startingIndexBlock = block.number;
        }
    }

    function price(uint _count) public view returns (uint256) {
        return mintPrice * _count;
    }

    function calcStartingIndex() external onlyOwner {
        require(startingIndex == 0);
        require(startingIndexBlock != 0);

        startingIndex = uint(blockhash(startingIndexBlock)) % MAX_PERSONA;

        // Just a sanity case in the worst case if this function is called late (EVM only stores last 256 block hashes)
        if (block.number.sub(startingIndexBlock) > 255) {
            startingIndex = uint(blockhash(block.number - 1)) % MAX_PERSONA;
        }

        // To prevent original sequence
        if (startingIndex == 0) {
            startingIndex = startingIndex.add(1);
        }
    }

    function setProvenanceHash(string calldata hash) external onlyOwner {
        PROVENANCE_HASH = hash;
    }

    function hashTransaction(address sender, uint256 count, string memory nonce) private pure returns(bytes32) {
        return keccak256(abi.encodePacked(
            "\x19Ethereum Signed Message:\n32",
            keccak256(abi.encodePacked(sender, count, nonce)))
        );
    }
    
    function matchAddresSigner(bytes32 hash, bytes memory signature) private view returns(bool) {
        return _signerAddress == hash.recover(signature);
    }

    function setEarlyMintAllowance(address[] calldata earlyMintAddresses, uint[] calldata allowableAmounts) external onlyOwner {
        for (uint i = 0; i < earlyMintAddresses.length; i++) {
            earlyMintAllowance[earlyMintAddresses[i]] = allowableAmounts[i];
        }
    }

    function setWhitelistWinners(address[] calldata veeFriendAddresses, bool winner) external onlyOwner {
        for (uint i = 0; i < veeFriendAddresses.length; i++) {
            whitelistWinners[veeFriendAddresses[i]] = winner;
        }
    }

    function setMintLimit(uint _mintLimit) external onlyOwner {
        LIMIT_PER_ACCOUNT = _mintLimit;
    }

    function setBaseURI(string calldata baseURI) external onlyOwner {
        _baseTokenURI = baseURI;
    }
    
    function setSignerAddress(address signer) external onlyOwner {
        _signerAddress = signer;
    }

    function toggleSaleStatus() external onlyOwner {
        SALE_IS_ACTIVE = !SALE_IS_ACTIVE;
    }

    function togglePreSaleStatus() external onlyOwner {
        PRESALE_IS_ACTIVE = !PRESALE_IS_ACTIVE;
    }

    function toggleDirectMint() external onlyOwner {
        ENABLE_DIRECT_MINT = !ENABLE_DIRECT_MINT;
    }

    function toggleBlockContracts() external onlyOwner {
        BLOCK_CONTRACTS = !BLOCK_CONTRACTS;
    }

    function withdrawAll(address payable _to) public payable onlyOwner {
        (bool sent, ) = _to.call{value: address(this).balance}("");
        require(sent);
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId)
        internal
        override(ERC721Enumerable)
    {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}