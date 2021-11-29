// contracts/NFT.sol
// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

// TODO: delete before deploying
// import "hardhat/console.sol";

contract MerchPassNFTAbi {
    function mint(address _to) public {}
}

contract UtilityPassNFTAbi {
    function mint(address _to) public {}
}

contract GenesisNFT is ERC721Enumerable, Ownable, ReentrancyGuard {
    using Address for address payable;
    using Counters for Counters.Counter;
    using SafeMath for uint256;

    enum MintStatus {
        CLOSED,
        PRESALE,
        PUBLIC
    }

    enum MintType {
        JUST_GENESIS,
        GENESIS_AND_MERCH,
        GENESIS_AND_UTILITY,
        GENESIS_AND_UTILITY_AND_MERCH
    }

    uint256 public constant GIVEAWAY = 250;
    uint256 public constant PRE_SALE_LIMIT = 1;
    uint256 public constant PUBLIC_LIMIT = 2;
    uint256 public constant PRICE = 0.085 ether;
    uint256 public constant MERCH_PASS_PRICE = 0.04 ether;
    uint256 public constant UTILITY_PASS_PRICE = 0.03 ether;
    uint256 public constant SUPPLY = 9595;

    MintStatus public mintStatus = MintStatus.CLOSED;
    Counters.Counter private _tokenIds;
    string public baseTokenURI;
    mapping(address => uint256) private _tokensMintedByAddress;
    mapping(address => uint256) private _tokensMintedByAddressAtPresale;
    // TODO: change
    address public withdrawDest1 = 0xb0B035d2E95d2c7820D58A56575b0c24bA8a9641;
    // TODO: change
    address public withdrawDest2 = 0x27a05D42046eace2ed21282643B1530867Ffb2Bb;

    // TODO: change
    bytes32 public merkleRoot =
        0x71eb2b2e3c82409bb024f8b681245d3eea25dcfd0dc7bbe701ee18cf1e8ecbb1;
    uint256 public giveawaySupply = GIVEAWAY;
    uint256 public mintableSupply = SUPPLY - GIVEAWAY;

    address public merchPassAddress;
    address public utilityPassAddress;

    constructor() ERC721("Psychedelics NFT", "PSYCH") {}

    // Override so the openzeppelin tokenURI() method will use this method to
    // create the full tokenURI instead
    function _baseURI() internal view virtual override returns (string memory) {
        return baseTokenURI;
    }

    ///
    /// Mint
    //

    // Private mint function, does not check for payment
    function _mintPrivate(address _to, uint256 _amount) private {
        for (uint256 i; i < _amount; i++) {
            _safeMint(_to, _tokenIds.current());
            _tokenIds.increment();
        }
    }

    function _mintPresale(uint256 _amount, bytes32[] memory proof) private {
        require(mintStatus == MintStatus.PRESALE, "Wrong mint status");

        if (
            MerkleProof.verify(
                proof,
                merkleRoot,
                keccak256(abi.encodePacked(msg.sender))
            )
        ) {
            require(
                _tokensMintedByAddressAtPresale[msg.sender] + _amount <=
                    PRE_SALE_LIMIT,
                "Trying to mint too many NFTs"
            );
            _mintPrivate(msg.sender, _amount);
        } else {
            revert("Not on presale list");
        }

        _tokensMintedByAddressAtPresale[msg.sender] += _amount;
    }

    function _mintPublic(uint256 _amount) private {
        require(mintStatus == MintStatus.PUBLIC, "Wrong mint status");
        // TODO: double check default value is 0
        require(
            _tokensMintedByAddress[msg.sender] + _amount <= PUBLIC_LIMIT,
            "Trying to mint too many NFTs"
        );

        _mintPrivate(msg.sender, _amount);
        _tokensMintedByAddress[msg.sender] += _amount;
    }

    // TODO: make sure amount is handled correctly
    function mint(
        uint256 _amount,
        bytes32[] memory _proof,
        MintType _mintType
    ) public payable onlyIfAvailable(_amount, _mintType) nonReentrant {
        if (mintStatus == MintStatus.PRESALE) {
            _mintPresale(_amount, _proof);
        } else if (mintStatus == MintStatus.PUBLIC) {
            _mintPublic(_amount);
        }
        mintableSupply.sub(_amount);

        if (
            _mintType == MintType.GENESIS_AND_MERCH ||
            _mintType == MintType.GENESIS_AND_UTILITY_AND_MERCH
        ) {
            MerchPassNFTAbi merchPass = MerchPassNFTAbi(
                payable(merchPassAddress)
            );
            merchPass.mint(msg.sender);
        }

        if (
            _mintType == MintType.GENESIS_AND_UTILITY ||
            _mintType == MintType.GENESIS_AND_UTILITY_AND_MERCH
        ) {
            UtilityPassNFTAbi utilityPass = UtilityPassNFTAbi(
                payable(utilityPassAddress)
            );
            utilityPass.mint(msg.sender);
        }
    }

    ///
    /// Setters
    ///
    function setBaseURI(string memory _uri) public onlyOwner {
        baseTokenURI = _uri;
    }

    function setMerchPassAddress(address _merchPassAddress) public onlyOwner {
        merchPassAddress = _merchPassAddress;
    }

    function setMerkleRoot(bytes32 _merkleRoot) external onlyOwner {
        merkleRoot = _merkleRoot;
    }

    function setStatus(uint8 _status) external onlyOwner {
        mintStatus = MintStatus(_status);
    }

    function setUtilityPassAddress(address _utilityPassAddress)
        public
        onlyOwner
    {
        utilityPassAddress = _utilityPassAddress;
    }

    function setWithdrawDests(address _dest1, address _dest2) public onlyOwner {
        withdrawDest1 = _dest1;
        withdrawDest2 = _dest2;
    }

    ///
    /// Giveaway
    ///
    function giveaway(address _to, uint256 _amount) external onlyOwner {
        require(_amount <= giveawaySupply, "Not enough supply");
        require(_amount > 0, "Amount must be greater than zero");

        _mintPrivate(_to, _amount);
        giveawaySupply -= _amount;
    }

    ///
    /// Modifiers
    ///
    // TODO: make sure amount is handled correctly
    modifier onlyIfAvailable(uint256 _amount, MintType _mintType) {
        require(mintStatus != MintStatus.CLOSED, "Minting is closed");
        require(_tokenIds.current() < SUPPLY, "Collection is sold out");
        require(_amount > 0, "Amount must be greater than zero");
        require(_amount <= mintableSupply, "Not enough NFTs available");

        if (_mintType == MintType.JUST_GENESIS) {
            require(msg.value == PRICE * _amount, "Ether sent is not correct");
        } else if (_mintType == MintType.GENESIS_AND_MERCH) {
            require(
                msg.value == (PRICE * _amount) + MERCH_PASS_PRICE,
                "Ether sent is not correct"
            );
        } else if (_mintType == MintType.GENESIS_AND_UTILITY) {
            require(
                msg.value == (PRICE * _amount) + UTILITY_PASS_PRICE,
                "Ether sent is not correct"
            );
        } else if (_mintType == MintType.GENESIS_AND_UTILITY_AND_MERCH) {
            require(
                msg.value ==
                    (PRICE * _amount) + UTILITY_PASS_PRICE + MERCH_PASS_PRICE,
                "Ether sent is not correct"
            );
        }

        _;
    }

    ///
    /// Withdrawal
    ///
    function withdraw() public onlyOwner {
        require(address(this).balance != 0, "Balance is zero");

        uint256 _onePercent = address(this).balance.div(100);
        uint256 _amt1 = _onePercent.mul(5);
        uint256 _amt2 = address(this).balance.sub(_amt1);

        payable(withdrawDest1).sendValue(_amt1);
        payable(withdrawDest2).sendValue(_amt2);
    }
}