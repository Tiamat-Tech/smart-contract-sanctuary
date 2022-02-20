// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract RareBears is
    ERC721EnumerableUpgradeable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable
{
    using StringsUpgradeable for uint256;
    using ECDSAUpgradeable for bytes32;

    string private _baseTokenURI;
    string private _contractURI;

    uint256 public maxSupply;
    uint256 public maxPresale;
    uint256 public maxPresaleMintQty;
    uint256 public maxPublicsaleMintQty;

    mapping(address => uint256) private mintedPresaleAddresses;
    mapping(address => uint256) private mintedPublicsaleAddresses;

    address private _internalSignerAddress;
    address private _withdrawalAddress;

    uint256 public pricePerToken;
    bool public metadataIsLocked;
    bool public publicSaleLive;
    bool public presaleLive;

    function initialize(
        string memory tokenName,
        string memory tokenSymbol,
        address internalSignerAddress,
        address withdrawalAddress,
        string memory initContractURI,
        string memory initBaseTokenURI
    ) public initializer {
        __ERC721_init(tokenName, tokenSymbol);
        __Ownable_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();
        _internalSignerAddress = internalSignerAddress;
        _withdrawalAddress = withdrawalAddress;
        _contractURI = initContractURI;
        _baseTokenURI = initBaseTokenURI;
        maxSupply = 7777;
        maxPresale = 6666;
        maxPresaleMintQty = 2;
        maxPublicsaleMintQty = 2;
        pricePerToken = 0.18 ether;
        metadataIsLocked = false;
        publicSaleLive = false;
        presaleLive = false;
    }

    function mint(uint256 qty) external payable nonReentrant {
        uint256 mintedAmount = mintedPublicsaleAddresses[msg.sender];

        require(publicSaleLive, "Public Sale not live");
        require(
            mintedAmount + qty <= maxPublicsaleMintQty,
            "Exceeded maximum quantity"
        );
        require(totalSupply() + qty <= maxSupply, "Out of stock");
        require(pricePerToken * qty == msg.value, "Invalid value");

        for (uint256 i = 0; i < qty; i++) {
            uint256 tokenId = totalSupply() + 1;
            _safeMint(msg.sender, tokenId);
        }
        mintedPublicsaleAddresses[msg.sender] = mintedAmount + qty;
    }

    function presaleMint(
        bytes32 hash,
        bytes memory sig,
        uint256 qty
    ) external payable nonReentrant {
        uint256 mintedAmount = mintedPresaleAddresses[msg.sender];

        require(presaleLive, "Presale not live");
        require(hashSender(msg.sender) == hash, "hash check failed");
        require(
            mintedAmount + qty <= maxPresaleMintQty,
            "Exceeded maximum quantity"
        );
        require(isInternalSigner(hash, sig), "Direct mint unavailable");
        require(totalSupply() + qty <= maxPresale, "Presale out of stock");
        require(pricePerToken * qty == msg.value, "Invalid value");

        for (uint256 i = 0; i < qty; i++) {
            uint256 tokenId = totalSupply() + 1;
            _safeMint(msg.sender, tokenId);
        }
        mintedPresaleAddresses[msg.sender] = mintedAmount + qty;
    }

    function adminMint(uint256 qty, address to) external payable onlyOwner {
        require(qty > 0, "minimum 1 token");
        require(totalSupply() + qty <= maxSupply, "out of stock");
        for (uint256 i = 0; i < qty; i++) {
            _safeMint(to, totalSupply() + 1);
        }
    }

    function burn(uint256 tokenId) public virtual {
        require(
            _isApprovedOrOwner(_msgSender(), tokenId),
            "caller is not owner nor approved"
        );
        _burn(tokenId);
    }

    function tokenExists(uint256 _tokenId) external view returns (bool) {
        return _exists(_tokenId);
    }

    function isApprovedOrOwner(address _spender, uint256 _tokenId)
        external
        view
        returns (bool)
    {
        return _isApprovedOrOwner(_spender, _tokenId);
    }

    function tokenURI(uint256 _tokenId)
        public
        view
        override
        returns (string memory)
    {
        require(
            _exists(_tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );
        return
            string(
                abi.encodePacked(_baseTokenURI, _tokenId.toString(), ".json")
            );
    }

    function withdrawEarnings() external onlyOwner {
        (bool success, ) = payable(_withdrawalAddress).call{
            value: address(this).balance
        }("");
        require(success, "Transfer failed.");
    }

    function reclaimERC20(IERC20Upgradeable erc20Token) external onlyOwner {
        erc20Token.transfer(msg.sender, erc20Token.balanceOf(address(this)));
    }

    function changePrice(uint256 newPrice) external onlyOwner {
        pricePerToken = newPrice;
    }

    function togglePresaleStatus() external onlyOwner {
        presaleLive = !presaleLive;
    }

    function togglePublicSaleStatus() external onlyOwner {
        publicSaleLive = !publicSaleLive;
    }

    function changeMaxPresale(uint256 _newMaxPresale) external onlyOwner {
        maxPresale = _newMaxPresale;
    }

    function changeMaxPresaleMintQty(uint256 _maxPresaleMintQty)
        external
        onlyOwner
    {
        maxPresaleMintQty = _maxPresaleMintQty;
    }

    function changeMaxPublicsaleMintQty(uint256 _maxPublicsaleMintQty)
        external
        onlyOwner
    {
        maxPublicsaleMintQty = _maxPublicsaleMintQty;
    }

    function setNewMaxSupply(uint256 newMaxSupply) external onlyOwner {
        require(newMaxSupply < maxSupply, "you can only decrease it");
        maxSupply = newMaxSupply;
    }

    function setBaseURI(string memory newBaseURI) external onlyOwner {
        require(!metadataIsLocked, "Metadata is locked");
        _baseTokenURI = newBaseURI;
    }

    function setContractURI(string memory newuri) external onlyOwner {
        require(!metadataIsLocked, "Metadata is locked");
        _contractURI = newuri;
    }

    function setWithdrawalAddress(address withdrawalAddress)
        external
        onlyOwner
    {
        _withdrawalAddress = withdrawalAddress;
    }

    function hashSender(address sender) private pure returns (bytes32) {
        bytes32 hash = keccak256(
            abi.encodePacked(
                "\x19Ethereum Signed Message:\n32",
                keccak256(abi.encode(sender))
            )
        );
        return hash;
    }

    function isInternalSigner(bytes32 hash, bytes memory signature)
        private
        view
        returns (bool)
    {
        return _internalSignerAddress == hash.recover(signature);
    }

    function setInternalSigner(address addr) external onlyOwner {
        _internalSignerAddress = addr;
    }

    function getInternalSigner() external view onlyOwner returns (address) {
        return _internalSignerAddress;
    }

    function getWithdrawalAddress() external view onlyOwner returns (address) {
        return _withdrawalAddress;
    }

    function contractURI() public view returns (string memory) {
        return _contractURI;
    }

    function lockMetaData() external onlyOwner {
        metadataIsLocked = true;
    }
    
    function _authorizeUpgrade(address) internal override onlyOwner {}
}