//Contract based on https://docs.openzeppelin.com/contracts/3.x/erc721
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./common/meta-transactions/ContentMixin.sol";
import "./common/meta-transactions/NativeMetaTransaction.sol";
import "hardhat/console.sol";

contract MiniMich is ERC721, Ownable, Pausable, ReentrancyGuard, ContextMixin, NativeMetaTransaction
    {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    Counters.Counter private _tokenIdCounter;
    string private _contractURI;
    string private _metadataBaseURI;
    bool public preLiveToggle;
    bool public saleLiveToggle;
    bool public freezeURI;
    bytes32 private wlisteRoot;
    bytes32 private xileMkRoot;
    uint32 public constant MAX_NFT = 10000;
    uint32 private constant MAX_MINT = 2;
    uint32 private constant MAX_GIFT = 300;
    uint32 public GIFT_COUNT = 0;
    uint256 public PRICE = 0.01 ether;
    uint256 public XILE_PRICE = 0.03 ether;

    address private _creators;
    mapping(address => uint256) private presalePurchased;

    // ** MODIFIERS ** //
    // *************** //

    modifier saleLive() {
        require(saleLiveToggle == true, "Sale is closed");
        _;
    }

    modifier preSaleLive() {
        require(preLiveToggle == true, "Presale is closed");
        _;
    }

    modifier allocTokens(uint32 numToMint) {
        require(
            _tokenIdCounter.current() + numToMint <=
                (MAX_NFT - (MAX_GIFT - GIFT_COUNT)),
            "Sorry, there are not enough artworks remaining."
        );
        _;
    }

    modifier maxOwned(uint32 numToMint) {
        require(
            presalePurchased[_msgSender()] + numToMint <= MAX_MINT,
            "Max 2 mints for presale"
        );
        _;
    }

    modifier correctPayment(uint256 mintPrice, uint32 numToMint) {
        require(
            msg.value == mintPrice * numToMint,
            "Payment failed, please ensure you are paying the correct amount."
        );
        _;
    }

    constructor(
        string memory _cURI,
        string memory _mURI,
        address _creatorAdd
    ) ERC721("MiniMich", "MM") {
        _contractURI = _cURI;
        _metadataBaseURI = _mURI;
        _creators = _creatorAdd;
        // start at 1 to save expensive 0 mint
        _tokenIdCounter.increment();
    }

    // ** ADMIN ** //
    // *********** //
    /*function giftMint(address[] calldata receivers) public onlyOwner {
        require(
            _tokenIdCounter.current() + receivers.length < MAX_NFT,
            "not enough artworks remaining."
        );
        require(
            GIFT_COUNT + receivers.length <= MAX_GIFT,
            "no gifts remaining"
        );

        for (uint32 i = 0; i < receivers.length; i++) {
            uint256 tokenId = _tokenIdCounter.current();
            _tokenIdCounter.increment();
            GIFT_COUNT++;
            _safeMint(receivers[i], tokenId);
        }
    }*/

     function getOwnersTokens(address _owner)
        public
        view
        returns (uint256[] memory)
    {
        require(balanceOf(_owner) > 0, "You don't currently hold any tokens");
        uint256 tokenCount = balanceOf(_owner);
        uint256 foundTokens = 0;
        uint256[] memory tokenIds = new uint256[](tokenCount);

        for (uint256 i = 1; i < _tokenIdCounter.current(); i++) {
            if (ownerOf(i) == _owner) {
                tokenIds[foundTokens] = i;
                foundTokens++;
            }
        }
        return tokenIds;
    }
    

    function _baseURI() internal view override returns (string memory) {
        return _metadataBaseURI;
    }

    function withdrawFunds(uint256 _amt) public onlyOwner {
        uint256 pay_amt;
        if (_amt == 0) {
            pay_amt = address(this).balance;
        } else {
            pay_amt = _amt;
        }

        (bool success, ) = payable(_creators).call{value: pay_amt}("");
        require(success, "Failed to send payment");
    }


    // ** MINTING FUNCS ** //
    // ******************* //

    //function _beforeTokenTransfer(
    //    address from,
    //    address to,
    //    uint256 tokenId
    //) internal override whenNotPaused {
    //    super._beforeTokenTransfer(from, to, tokenId);
    //}

    function aeMint(uint32 mintNum)
        external
        payable
        nonReentrant
        saleLive
        allocTokens(mintNum - 1)
        correctPayment(PRICE, mintNum)
    {
        require(
            balanceOf(_msgSender()) + mintNum <= MAX_MINT,
            "Limit of 2 per wallet"
        );
        for (uint32 i = 0; i < mintNum; i++) {
            uint256 tokenId = _tokenIdCounter.current();
            _tokenIdCounter.increment();
            _safeMint(_msgSender(), tokenId);
        }
    }

    function preMint(uint32 mintNum, bytes32[] calldata merkleProof)
        external
        payable
        nonReentrant
        preSaleLive
        maxOwned(mintNum)
        correctPayment(PRICE, mintNum)
    {
        require(
            MerkleProof.verify(
                merkleProof,
                wlisteRoot,
                keccak256(abi.encodePacked(_msgSender()))
            ),
            "Not on whitelist"
        );

        presalePurchased[_msgSender()] += mintNum;

        for (uint32 i = 0; i < mintNum; i++) {
            uint256 tokenId = _tokenIdCounter.current();
            _tokenIdCounter.increment();
            _safeMint(_msgSender(), tokenId);
        }
    }

    function xileMint(uint32 mintNum, bytes32[] calldata merkleProof)
        external
        payable
        nonReentrant
        preSaleLive
        maxOwned(mintNum)
        correctPayment(XILE_PRICE, mintNum)
    {
        require(
            MerkleProof.verify(
                merkleProof,
                xileMkRoot,
                keccak256(abi.encodePacked(_msgSender()))
            ),
            "Not on Xile whitelist"
        );

        presalePurchased[_msgSender()] += mintNum;

        for (uint32 i = 0; i < mintNum; i++) {
            uint256 tokenId = _tokenIdCounter.current();
            _tokenIdCounter.increment();
            _safeMint(_msgSender(), tokenId);
        }
    }

    // ** SETTINGS ** //
    // ************** //

    function setMetaURI(string calldata _URI) external onlyOwner {
        require(freezeURI == false, "Metadata has been frozen");
        _metadataBaseURI = _URI;
    }

    function setContractURI(string calldata _URI) external onlyOwner {
        _contractURI = _URI;
    }

    function setCreator(address to) external onlyOwner returns (address) {
        _creators = to;
        return _creators;
    }

    function tglLive() external onlyOwner {
        saleLiveToggle = !saleLiveToggle;
    }

    function tglPresale() external onlyOwner {
        preLiveToggle = !preLiveToggle;
    }

    function freezeAll() external onlyOwner {
        require(freezeURI == false, "Metadata is already frozen");
        freezeURI = true;
    }
    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function updatePrice(uint256 _price, uint32 _list) external onlyOwner {
        if (_list == 0) {
            // sale price
            PRICE = _price;
        } else {
            // xile price
            XILE_PRICE = _price;
        }
    }

    function setMerkleRoot(bytes32 _root, uint32 _list) external onlyOwner {
        if (_list == 0) {
            // update main whitelist
            wlisteRoot = _root;
        } else {
            // update xile whitelist
            xileMkRoot = _root;
        }
    }

    function contractURI() external view returns (string memory) {
        return _contractURI;
    }

    //function totalSupply() public view returns (uint256) {
    //    return _tokenIdCounter.current() - 1;
    //}

    //function _msgSender() internal view override returns (address sender) {
    //    return ContextMixin.msgSender();
    //}

}