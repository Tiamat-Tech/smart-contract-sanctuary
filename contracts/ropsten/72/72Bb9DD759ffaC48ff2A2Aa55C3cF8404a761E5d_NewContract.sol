// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract NewContract is ERC721, Ownable {

    using Strings for uint256;
    using Counters for Counters.Counter;
    Counters.Counter private supply;

    string private uriPrefix = "";
    string public uriSuffix = ".json";
    string public hiddenMetadataUri;
    uint256 public cost = 0.01 ether;
    uint256 public maxSupply = 10000;
    uint256 public maxMintAmountPerTx = 4;
    uint256 public maxMintAmount = 7;
    uint256 public nftPerAddressLimit = 4;
    bool public paused = true;
    bool public revealed = false;
    bool public onlyWhitelisted = true;
    address[] public whitelistedAddresses;
    address redLizard = 0x37b866D9B2abC358043f3cA0b38576a41c83c114;
    address blueLizard = 0xd79337a9e9567d02e04ED47F8497bEAdf2C78A94;
    address greenLizard = 0x87C696034EC1b3793ec3B1552Ce94f4c427000Cb;

   mapping (address => uint256) public mintedCount;

    constructor() ERC721("matan", "MAT") {
        setHiddenMetadataUri(
            "ipfs://__CID__/hidden.json"
        );
  
    }

    modifier mintCompliance(uint256 _mintAmount) {
        if (msg.sender != owner()) {
            require(
                balanceOf(msg.sender) + _mintAmount <= maxMintAmount,
                "max mint amount per session exceeded"
            );
            require(
                _mintAmount > 0 && _mintAmount <= maxMintAmountPerTx,
                "Invalid mint amount!"
            );
        }
        require(
            supply.current() + _mintAmount <= maxSupply,
            "Max supply exceeded!"
        );
        _;
    }

    function totalSupply() public view returns (uint256) {
        return supply.current();
    }

    function mint(uint256 _mintAmount)
        public
        payable
        mintCompliance(_mintAmount)
    {
        require(!paused, "The contract is paused!");
        if (msg.sender != owner()) {
            require(msg.value >= cost * _mintAmount, "Insufficient funds!");
            if (onlyWhitelisted == true) {
                require(isWhitelisted(msg.sender), "user is not whitelisted");
                uint256 ownerMintedCount = mintedCount[msg.sender];
                require(ownerMintedCount + _mintAmount <= nftPerAddressLimit, "max NFT per address exceeded");
                }
        }
        _mintLoop(msg.sender, _mintAmount);
    }

    function mintForAddress(uint256 _mintAmount, address _receiver)
        public
        mintCompliance(_mintAmount)
        onlyOwner
    {
        _mintLoop(_receiver, _mintAmount);
    }

    function walletOfOwner(address _owner)
        public
        view
        returns (uint256[] memory)
    {
        uint256 ownerTokenCount = balanceOf(_owner);
        uint256[] memory ownedTokenIds = new uint256[](ownerTokenCount);
        uint256 currentTokenId = 1;
        uint256 ownedTokenIndex = 0;

        while (
            ownedTokenIndex < ownerTokenCount && currentTokenId <= maxSupply
        ) {
            address currentTokenOwner = ownerOf(currentTokenId);

            if (currentTokenOwner == _owner) {
                ownedTokenIds[ownedTokenIndex] = currentTokenId;

                ownedTokenIndex++;
            }

            currentTokenId++;
        }

        return ownedTokenIds;
    }

    function tokenURI(uint256 _tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        require(
            _exists(_tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );

        if (revealed == false) {
            return hiddenMetadataUri;
        }

        string memory currentBaseURI = _baseURI();
        return
            bytes(currentBaseURI).length > 0
                ? string(
                    abi.encodePacked(currentBaseURI,_tokenId.toString(),uriSuffix)
                )
                : "";
    }

    function isWhitelisted(address _user) public view returns (bool) {
        for (uint256 i = 0; i < whitelistedAddresses.length; i++) {
            if (whitelistedAddresses[i] == _user) {
                return true;
            }
        }
        return false;
    }

    function setRevealed(bool _state) public onlyOwner {
        revealed = _state;
    }

    function setCost(uint256 _cost) public onlyOwner {
        cost = _cost;
    }

    function setMaxMintAmountPerTx(uint256 _maxMintAmountPerTx)
        public
        onlyOwner
    {
        maxMintAmountPerTx = _maxMintAmountPerTx;
    }

    function setHiddenMetadataUri(string memory _hiddenMetadataUri)
        public
        onlyOwner
    {
        hiddenMetadataUri = _hiddenMetadataUri;
    }

    function setUriPrefix(string memory _uriPrefix) public onlyOwner {
        uriPrefix = _uriPrefix;
    }

    function setUriSuffix(string memory _uriSuffix) public onlyOwner {
        uriSuffix = _uriSuffix;
    }

    function setPaused(bool _state) public onlyOwner {
        paused = _state;
    }

    function withdraw() public {
        uint256 balance = address(this).balance;
        payable(redLizard).transfer((balance * 400) / 1000);
        payable(greenLizard).transfer((balance * 400) / 1000);
        payable(blueLizard).transfer((balance * 200) / 1000);
    }    

    function setmaxMintAmount(uint256 _newmaxMintAmount) public onlyOwner {
        maxMintAmount = _newmaxMintAmount;
    }

    function setOnlyWhitelisted(bool _state) public onlyOwner {
        onlyWhitelisted = _state;
    }

    function whitelistUsers(address[] calldata _users) public onlyOwner {
        delete whitelistedAddresses;
        whitelistedAddresses = _users;
    }

    function setNftPerAddressLimit(uint256 _limit) public onlyOwner {
        nftPerAddressLimit = _limit;
    }

    function _mintLoop(address _receiver, uint256 _mintAmount) internal {
        for (uint256 i = 0; i < _mintAmount; i++) {
            supply.increment();
            _safeMint(_receiver, supply.current());
        }
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return uriPrefix;
    }
}