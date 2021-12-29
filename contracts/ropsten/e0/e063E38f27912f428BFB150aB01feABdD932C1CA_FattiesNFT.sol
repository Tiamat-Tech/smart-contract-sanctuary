// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;
pragma abicoder v2;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/finance/PaymentSplitter.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract FattiesNFT is ERC721, ERC721Enumerable, PaymentSplitter, Ownable {
    using Strings for uint256;

    struct PresaleVoucher {
        address to;
        address verifyingContract;
    }

    struct InfluencerVoucher {
        address to;
        string uri;
        address verifyingContract;
    }
    
    uint256 public constant MAX_SUPPLY = 8008;
    uint256 public constant PRICE_PER_TOKEN = 0.06 ether;

    uint256 public constant MAX_INFLUENCER_SUPPLY = 50;
    uint256 public constant MAX_PRESALE_MINT = 20;
    uint256 public constant MAX_MINT_PER_FREN = 10;

    uint256 private _tokenIds;

    bool public mintActive;

    address public signer;
    string private _baseUri;

    mapping(address => uint256) private _frensList;
    mapping(string => bool) private _influencerClaimed;
    mapping(uint256 => string) private _influencerTokenUris;

    constructor(
        address[] memory payees,
        uint256[] memory shares,
        address voucherSigner,
        string memory baseUri,
        address[] memory frens)
        ERC721("FattiesNFT", "FATTIES")
        PaymentSplitter(payees, shares) {
        signer = voucherSigner;
        _baseUri = baseUri;

        for (uint256 i = 0; i < frens.length; i++) {
            _frensList[frens[i]] = 1;
        }
    }

    function mint_540(uint256 quantity) public payable {
        require(_tokenIds < MAX_SUPPLY, "Sale ended");        
        require(mintActive, "Sale has not started");
        require(_tokenIds + quantity <= MAX_SUPPLY, "Not enough supply for quantity");

        if (_frensList[msg.sender] != 0) {
            require(_frensList[msg.sender] - 1 + quantity <= MAX_MINT_PER_FREN, "Max FREN mint limit reached");
            _frensList[msg.sender] += quantity;
        } else {
            require(msg.value >= PRICE_PER_TOKEN * quantity, "Not enough ETH sent");
        }

        for (uint256 i = 0; i < quantity; i++) {
            _tokenIds += 1;
            _safeMint(msg.sender, _tokenIds);
        }
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function presaleMint(uint256 quantity, PresaleVoucher calldata voucher, bytes calldata signature) public payable {
        require(_tokenIds < MAX_SUPPLY, "Sale ended");
        require(_tokenIds + quantity <= MAX_SUPPLY, "Not enough supply for quantity");
        require(balanceOf(msg.sender) + quantity <= MAX_PRESALE_MINT, "Over presale max mint balance");

        if (_frensList[msg.sender] != 0) {
            require(_frensList[msg.sender] - 1 + quantity <= MAX_MINT_PER_FREN, "Max FREN mint limit reached");
            _frensList[msg.sender] += quantity;
        } else {
            require(msg.value >= PRICE_PER_TOKEN * quantity, "Not enough ETH sent");
        }
        
        require(msg.sender == voucher.to, "Invalid presale address");
        require(voucher.verifyingContract == address(this), "Invalid domain contract");

        bytes32 digest = ECDSA.toEthSignedMessageHash(
            keccak256(abi.encodePacked(
                voucher.to,
                voucher.verifyingContract)));
        address recoveredSigner = ECDSA.recover(digest, signature);
        require(signer == recoveredSigner, "Invalid signer");

        for (uint256 i = 0; i < quantity; i++) {
            _tokenIds += 1;
            _safeMint(msg.sender, _tokenIds);
        }
    }

    function influencerMint(InfluencerVoucher calldata voucher, bytes calldata signature) public {
        uint256 claimed = totalSupply() - _tokenIds;
        require(!_influencerClaimed[voucher.uri], "Already claimed");
        require(totalSupply() - _tokenIds < MAX_INFLUENCER_SUPPLY, "Max influencer mint reached");
        require(msg.sender == voucher.to, "Invalid influencer address");
        require(voucher.verifyingContract == address(this), "Invalid domain contract");

        bytes32 digest = ECDSA.toEthSignedMessageHash(
            keccak256(abi.encodePacked(
                voucher.to,
                voucher.uri,
                voucher.verifyingContract)));
        address recoveredSigner = ECDSA.recover(digest, signature);
        require(signer == recoveredSigner, "Invalid signer");

        uint256 id = MAX_SUPPLY + claimed + 1;
        _safeMint(msg.sender, id);
        _influencerTokenUris[id] = voucher.uri;
        _influencerClaimed[voucher.uri] = true;
    }

    function setMintState(bool state) public onlyOwner {
        mintActive = state;
    }

    function setBaseUri(string memory baseUri) public onlyOwner {
        _baseUri = baseUri;
    }

    function setSigner(address value) public onlyOwner {
        signer = value;
    }

    function influencerSupply() public view returns (uint256) {
        return totalSupply() - _tokenIds;
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "Nonexistent token");
        if (tokenId <= MAX_SUPPLY) {
            return string(abi.encodePacked(_baseUri, tokenId.toString()));
        }
        return _influencerTokenUris[tokenId];
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, ERC721Enumerable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}