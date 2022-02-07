pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./ERC721Enumerable.sol";

contract HCTEST is ERC721Enumerable, Ownable {
    string public baseURI;

    address public airdropped1 = 0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db;
    address public airdropped2 = 0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB;

    address public withdrawAddress;

    bool    public publicSaleState = false;
    bool    public preSaleState = false;
    bytes32 public allowListMerkleRoot = 0x0;
    uint256 public MAX_SUPPLY = 8000;

    uint256 public constant MAX_PER_TX = 8;
    uint256 public constant RESERVES = 25;

    uint256 public preSalePrice = 0.02 ether;
    uint256 public publicSalePrice = 0.04 ether;
    uint256 public price = preSalePrice;

    mapping(address => bool) public projectProxy;
    mapping(address => uint) public addressToMinted;

    constructor(
        string memory _baseURI,
        address _withdrawAddress
    ) ERC721("HCTEST", "HCTEST")

    {
        baseURI = _baseURI;
        withdrawAddress = _withdrawAddress;

        // reserves
        _mint(airdropped1, 0);
        _mint(airdropped2, 1);


        for (uint256 i = 2; i <= 2 + RESERVES; i++) {
            _mint(withdrawAddress, i);
        }
    }

    function setBaseURI(string memory _baseURI) public onlyOwner {
        baseURI = _baseURI;
    }


    function flipProxyState(address proxyAddress) public onlyOwner {
        projectProxy[proxyAddress] = !projectProxy[proxyAddress];
    }

    function togglePublicSale() external onlyOwner {
        publicSaleState = true;
        preSaleState = false;
        delete allowListMerkleRoot;

        price = publicSalePrice;
    }

    function tokenURI(uint256 _tokenId) public view override returns (string memory) {
        require(_exists(_tokenId), "Token does not exist.");
        return string(abi.encodePacked(baseURI, Strings.toString(_tokenId)));
    }

    // This also starts the presale
    function setAllowlistMerkleRoot(bytes32 _allowListMerkleRoot) external onlyOwner {
        preSaleState = true;
        allowListMerkleRoot = _allowListMerkleRoot;

        price = preSalePrice;
    }

    function allowListMint(uint256 count, bytes32[] calldata proof) public payable {
        require(preSaleState == true, "pre sale not started");

        uint256 totalSupply = _owners.length;
        require(totalSupply + count < MAX_SUPPLY, "Exceeds max supply.");

        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
        require(MerkleProof.verify(proof, allowListMerkleRoot, leaf), "wrong proof");
        require(count <= MAX_PER_TX, "exceeds tx max");
        require(count * price == msg.value, "invalid funds");

        addressToMinted[_msgSender()] += count;
        for (uint i = 0; i < count; i++) {
            _mint(_msgSender(), totalSupply + i);
        }
    }

    function publicMint(uint256 count) public payable {
        uint256 totalSupply = _owners.length;
        require(publicSaleState == true, "public sale not started");
        require(totalSupply + count < MAX_SUPPLY, "Excedes max supply.");
        require(count <= MAX_PER_TX, "Exceeds max per transaction.");
        require(count * price == msg.value, "Invalid funds provided.");

        for (uint i = 0; i < count; i++) {
            _mint(_msgSender(), totalSupply + i);
        }
    }

    function pause() public onlyOwner {
        publicSaleState = false;
        preSaleState = false;
    }

    function burn(uint256 tokenId) public {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "Not approved to burn.");
        _burn(tokenId);
    }

    function withdraw() external onlyOwner {
        (bool success,) = withdrawAddress.call{value : address(this).balance}("");
        require(success, "Failed to send to apetoshi.");
    }

    function walletOfOwner(address _owner) public view returns (uint256[] memory) {
        uint256 tokenCount = balanceOf(_owner);
        if (tokenCount == 0) return new uint256[](0);

        uint256[] memory tokensId = new uint256[](tokenCount);
        for (uint256 i; i < tokenCount; i++) {
            tokensId[i] = tokenOfOwnerByIndex(_owner, i);
        }
        return tokensId;
    }


    function batchTransferFrom(address _from, address _to, uint256[] memory _tokenIds) public {
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            transferFrom(_from, _to, _tokenIds[i]);
        }
    }

    function batchSafeTransferFrom(address _from, address _to, uint256[] memory _tokenIds, bytes memory data_) public {
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            safeTransferFrom(_from, _to, _tokenIds[i], data_);
        }
    }

    function isOwnerOf(address account, uint256[] calldata _tokenIds) external view returns (bool){
        for (uint256 i; i < _tokenIds.length; ++i) {
            if (_owners[_tokenIds[i]] != account)
                return false;
        }

        return true;
    }

    function _mint(address to, uint256 tokenId) internal virtual override {
        _owners.push(to);
        emit Transfer(address(0), to, tokenId);
    }

    function setMintPrice(uint256 newPrice) external onlyOwner {
        // the new price can be reset
        price = newPrice;
    }

}


contract OwnableDelegateProxy {}

contract OpenSeaProxyRegistry {
    mapping(address => OwnableDelegateProxy) public proxies;
}