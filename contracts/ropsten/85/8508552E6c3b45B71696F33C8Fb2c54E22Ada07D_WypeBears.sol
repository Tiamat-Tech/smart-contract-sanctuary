// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";


contract WypeBears is ERC721("WypeBears", "WB"), ERC721Enumerable, Ownable {
    using ECDSA for bytes32;
    using SafeMath for uint256;
    using Strings for uint256;

    address public proxyRegistryAddress = 0xF57B2c51dED3A29e6891aba85459d600256Cf317;//testnet

    string private baseURI = "https://storage.googleapis.com/hdpunks-cdn/metadata/";
    string private blindURI = "https://lostpoets.api.manifoldxyz.dev/metadata/3";
    uint256 public mintLimit = 1;
    uint256 private constant TOTAL_NFT = 10000;
    uint256 public NFTPrice = 0.1 ether; //todo
    bool public reveal;
    bool public mintActive;
    mapping (address => bool) whitelist;
    mapping (address => bool) addressMinted;
    address public whitelistSigner;
    uint256 public partnerMintAmount = 100;
    mapping(address => uint256) public freeMintAvailableBy;

    constructor() {
        freeMintAvailableBy[0xBC3C2C6e7BaAeB7C7EA2ad4B2Fa8681a91d47Ccd] = 50; //todo
        freeMintAvailableBy[0xaD3197b735d76B50b8e15A78D30b0F945a8BD3E5] = 49; //todo
        freeMintAvailableBy[0xc762879Edd0a994e349F475E99Efe0C2cfc0fb32] = 1; //todo
    }


    function revealNow(bool _status) external onlyOwner { //todo test
        reveal = _status;
    }

    function setMintActive(bool _isActive) external onlyOwner {
        mintActive = _isActive;
    }

    function setURIs(string memory _blindURI, string memory _URI) external onlyOwner {
        blindURI = _blindURI;
        baseURI = _URI;
    }

    function setWhitelistSigner(address _address) external onlyOwner {
        whitelistSigner = _address;
    }

    function addToWhitelist(address _newAddress) external onlyOwner {
        whitelist[_newAddress] = true;
    }

    function removeFromWhitelist(address _address) external onlyOwner {
        whitelist[_address] = false;
    }

    function addMultipleToWhitelist(address[] calldata _addresses) external onlyOwner {
        require(_addresses.length <= 10000, "Provide less addresses in one function call");
        for (uint256 i = 0; i < _addresses.length; i++) {
            whitelist[_addresses[i]] = true;
        }
    }

    function removeMultipleFromWhitelist(address[] calldata _addresses) external onlyOwner {
        require(_addresses.length <= 10000, "Provide less addresses in one function call");
        for (uint256 i = 0; i < _addresses.length; i++) {
            whitelist[_addresses[i]] = false;
        }
    }

    function canMint(address _address, bytes memory _signature) public view returns (bool, string memory) {
        if (!whitelist[_address]) {
            bytes32 hash = keccak256(abi.encodePacked(whitelistSigner, _address));
            bytes32 messageHash = hash.toEthSignedMessageHash();

            address signer = messageHash.recover(_signature);

            if (signer != whitelistSigner) {
                return (false, "Invalid signature");
            }
        }

        if (addressMinted[_address]) {
            return (false, "Already withdrawn");
        }
        return (true, "");
    }

    function withdraw() public onlyOwner {
        uint256 balance = address(this).balance;
        uint256 amount1 = balance * 70 / 100;
        uint256 amount2 = balance- amount1;
//        payable(0xe0F7204f04b060715f858Ba8Ae357f57E5494d18).transfer(amount1);
//        payable(0x029c2D9EDC080A5A077f30F3bf6122e100F2aDc6).transfer(amount2);
        payable(0xBC3C2C6e7BaAeB7C7EA2ad4B2Fa8681a91d47Ccd).transfer(amount1);//todo test
        payable(0xaD3197b735d76B50b8e15A78D30b0F945a8BD3E5).transfer(amount2);//todo test
    }

    function updateMintLimit(uint256 _newLimit) public onlyOwner {
        mintLimit = _newLimit;
    }

    function addPartnerMint(address account, uint256 amount) public onlyOwner {
        partnerMintAmount += amount;
        require(totalSupply().add(partnerMintAmount) <= TOTAL_NFT, "Can't add partner more than available");
        freeMintAvailableBy[account] += amount;
    }

    function mintNFT(uint256 _numOfTokens, bytes memory _signature) public payable {
        require(mintActive, 'Not active');
        require(_numOfTokens <= mintLimit, "Can't mint more than limit per tx");
        require(NFTPrice.mul(_numOfTokens) <= msg.value, "Insufficient payable value");
        require(totalSupply().add(_numOfTokens).add(partnerMintAmount) <= TOTAL_NFT, "Can't mint more than 10000");
        (bool success, string memory reason) = canMint(msg.sender, _signature);
        require(success, reason);

        for(uint i = 0; i < _numOfTokens; i++) {
            _safeMint(msg.sender, totalSupply());
        }
        addressMinted[msg.sender] = true;
    }

    function partnersMintMultiple(address[] memory _to) public {
        uint256 amount = _to.length;
        require(partnerMintAmount >= amount, "Can't mint more than total available for partners");
        require(freeMintAvailableBy[msg.sender] >= amount, "Can't mint more than available for msg.sender");
        for(uint256 i = 0; i < amount; i++){
            _safeMint(_to[i],totalSupply());
        }
        partnerMintAmount -= amount;
        freeMintAvailableBy[msg.sender] -= amount;
    }

    function tokenURI(uint256 _tokenId) public view virtual override returns (string memory) {
        require(_exists(_tokenId), "ERC721Metadata: URI query for nonexistent token");
        if (!reveal) {
            return string(abi.encodePacked(blindURI));
        } else {
            return string(abi.encodePacked(baseURI, _tokenId.toString()));
        }
    }

    function supportsInterface(bytes4 _interfaceId) public view override (ERC721, ERC721Enumerable) returns (bool) {
        return super.supportsInterface(_interfaceId);
    }

    function _beforeTokenTransfer(address _from, address _to, uint256 _tokenId) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(_from, _to, _tokenId);
    }

}