// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract NFT is ERC721Enumerable, Ownable, ReentrancyGuard {
    using Strings for uint256;
    using Math for uint256;
    using ECDSA for bytes32;

    // sale parameters
    uint256 public constant MINT_PRICE = 0.1 ether; // aUSD has 12 decimals, the price is 100 aUSD
    uint256 public constant MAX_PURCHASE = 10;
    uint256 public MAX_SUPPLY = 10000;
    IERC20 public aUSD = IERC20(0x0000000000000000000000000000000001000001);

    // contract state
    bool public saleIsActive = false;
    bool public publicSaleIsActive = false;
    address private _signer;
    string private _baseURIExtended;
    // data structure for randomness
    // if a rid is used before, orderToIndex[rid] will be pointed to its the index that used it
    // at the end of minting, orderToIndex[n-i] = the token id of i-th mint
    mapping(uint256 => uint256) private orderToIndex;
    mapping(address => bool) private whitelistUsed;
    mapping(address => bool) private freeUsed;

    // contributers
    address private constant beneficiary1 =
        0xb1B6356EA9E2f3Bf9867d6Ac1c1Bfd2cB1553Abb;
    address private constant beneficiary2 =
        0xb1B6356EA9E2f3Bf9867d6Ac1c1Bfd2cB1553Abb;
    uint256 private nSold = 0;
    mapping(address => uint256) claimed;

    constructor(
        string memory name,
        string memory symbol,
        string memory baseURI_
    ) ERC721(name, symbol) {
        _baseURIExtended = baseURI_;
        _signer = msg.sender;
    }

    // sale state management
    modifier saleActive() {
        require(saleIsActive == true, "Sale is not active");
        _;
    }

    modifier publicSaleActive() {
        require(publicSaleIsActive == true, "Public Sale is not active");
        _;
    }

    function flipSaleState() public onlyOwner {
        saleIsActive = !saleIsActive;
    }

    function flipPublicSaleActive() external onlyOwner {
        publicSaleIsActive = !publicSaleIsActive;
    }

    // random index
    function _randMod(uint256 mod) internal view returns (uint256) {
        return
            uint256(
                keccak256(
                    abi.encodePacked(
                        block.timestamp,
                        block.difficulty,
                        block.number,
                        msg.sender
                    )
                )
            ) % mod;
    }

    function _randID() internal returns (uint256) {
        uint256 id = MAX_SUPPLY - totalSupply() - 1;
        uint256 rid = _randMod(id + 1); // rid is less than or equal to id
        uint256 tmp = orderToIndex[id] > 0 ? orderToIndex[id] : id;
        orderToIndex[id] = orderToIndex[rid] > 0 ? orderToIndex[rid] : rid; // if rid is used, point to the id that used it
        orderToIndex[rid] = tmp; // remember who used this rid
        return orderToIndex[id];
    }

    // token minting
    function reserveTokens(uint256 n) public onlyOwner {
        require(totalSupply() + n <= MAX_SUPPLY, "NFT: Exceeds maximum supply");
        for (uint256 i = 0; i < n; i++) {
            _safeMint(msg.sender, _randID());
        }
    }

    function mint(uint256 n) internal saleActive {
        require(n > 0, "NFT: #tokens must > 0");
        require(n <= MAX_PURCHASE, "NFT: Exceeds maximum #tokens per mint");
        require(totalSupply() + n <= MAX_SUPPLY, "NFT: Exceeds maximum supply");
        bool success = aUSD.transferFrom(
            _msgSender(),
            address(this),
            MINT_PRICE * n
        ); //ask for approve!
        nSold += n;
        require(success, "NFT: insuficient fund");
        for (uint256 i = 0; i < n; i++) {
            _safeMint(msg.sender, _randID());
        }
    }

    function publicMint(uint256 n)
        public
        payable
        nonReentrant
        publicSaleActive
    {
        mint(n);
    }

    function privateMint(uint256 n, bytes calldata signature)
        public
        payable
        nonReentrant
    {
        require(
            !whitelistUsed[_msgSender()],
            "NFT: address already minted whitelist NFTs"
        );
        address signer = keccak256(abi.encodePacked(msg.sender, name()))
            .toEthSignedMessageHash()
            .recover(signature);
        require(signer == _signer, "NFT: not whitelisted to private sale");
        mint(n);
    }

    function freeMint(uint256 n, bytes calldata signature)
        public
        payable
        saleActive
        nonReentrant
    {
        require(n > 0, "NFT: #tokens must > 0");
        require(!publicSaleIsActive); // free mint must happen during private sale
        require(
            !freeUsed[_msgSender()],
            "NFT: address already minted free NFTs"
        );
        address signer = keccak256(
            abi.encodePacked(msg.sender, name(), "freeNFT", n)
        ).toEthSignedMessageHash().recover(signature);
        require(
            signer == _signer,
            "NFT: the number of free NFTs is invalid for the user"
        );
        for (uint256 i = 0; i < n && totalSupply() <= MAX_SUPPLY; i++) {
            _safeMint(msg.sender, _randID());
        }
    }

    // metadata
    function setBaseURI(string memory baseURI_) external onlyOwner {
        _baseURIExtended = baseURI_;
    }

    function _baseURI() internal view override returns (string memory) {
        return _baseURIExtended;
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        require(
            _exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );
        // token+1 since the jsons are 1 indexed
        return
            string(
                abi.encodePacked(_baseURI(), (tokenId + 1).toString(), ".json")
            );
    }

    function getMintedIndex(uint256 order) public view returns (uint256) {
        return orderToIndex[MAX_SUPPLY - order];
    }

    // withdraw
    function withdrawETH() public onlyOwner {
        (bool success, ) = owner().call{value: address(this).balance}("");
        require(success);
    }

    function calcShare(address addr) public view returns (uint256) {
        uint256 share2 = Math.min(
            (nSold * MINT_PRICE) / 2,
            Math.max(80 * MINT_PRICE, (nSold * MINT_PRICE) / 20)
        );
        if (addr == beneficiary1) {
            return nSold * MINT_PRICE - share2;
        } else if (addr == beneficiary2) {
            return share2;
        }
        return 0; // cannot withdraw if not beneficiaries
    }

    function withdrawUSD(uint256 n) public {
        require(claimed[msg.sender] + n <= calcShare(msg.sender));
        claimed[msg.sender] += n;
        bool success = aUSD.transferFrom(address(this), msg.sender, n);
        require(success);
    }

    // receive and fallback
    receive() external payable {
        (bool success, ) = owner().call{value: msg.value}("");
        require(success);
    }

    fallback() external payable {
        (bool success, ) = owner().call{value: msg.value}("");
        require(success);
    }
}