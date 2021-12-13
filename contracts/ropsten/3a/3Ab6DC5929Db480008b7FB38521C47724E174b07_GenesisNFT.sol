// contracts/NFT.sol
// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.4;

import "./ERC721B.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

// TODO: delete before deploying
// import "hardhat/console.sol";

contract MintNFTAbi {
    function mint(address _to) public returns (bool) {}
}

contract GenesisNFT is Ownable, ERC721B, ReentrancyGuard {
    using Address for address payable;
    using SafeMath for uint256;
    using Strings for uint256;

    enum MintStatus {
        CLOSED,
        PRESALE,
        PUBLIC
    }

    uint256 public constant GIVEAWAY = 250;
    uint256 public constant PRE_SALE_LIMIT = 1;
    uint256 public constant PUBLIC_LIMIT = 2;
    uint256 public constant PRICE = 0.085 ether;
    uint256 public constant MERCH_PASS_PRICE = 0.04 ether;
    uint256 public constant META_PASS_PRICE = 0.04 ether;
    uint256 public constant UTILITY_PASS_PRICE = 0.03 ether;
    uint256 public constant SUPPLY = 9595;
    uint256 public constant MINTABLE_SUPPLY = SUPPLY - GIVEAWAY;

    MintStatus public mintStatus = MintStatus.CLOSED;
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

    address public merchPassAddress;
    address public metaPassAddress;
    address public utilityPassAddress;

    event MintFailure(address indexed to, string failure);

    constructor() ERC721B("Psychedelics NFT", "PSYCH") {}

    ///
    /// Mint
    //

    // Private mint function, does not check for payment
    function _mintPrivate(address _to, uint256 _amount) private {
        uint256 supply = _owners.length;
        for (uint256 i; i < _amount; i++) {
            _safeMint(_to, supply++);
        }
    }

    function _mintPresale(bytes32[] memory proof) private {
        require(mintStatus == MintStatus.PRESALE, "Wrong mint status");

        if (
            MerkleProof.verify(
                proof,
                merkleRoot,
                keccak256(abi.encodePacked(msg.sender))
            )
        ) {
            require(
                _tokensMintedByAddressAtPresale[msg.sender] + 1 <=
                    PRE_SALE_LIMIT,
                "Trying to mint too many NFTs"
            );
            _mintPrivate(msg.sender, 1);
        } else {
            revert("Not on presale list");
        }

        _tokensMintedByAddressAtPresale[msg.sender] += 1;
    }

    function _mintPublic() private {
        require(mintStatus == MintStatus.PUBLIC, "Wrong mint status");
        require(
            _tokensMintedByAddress[msg.sender] + 1 <= PUBLIC_LIMIT,
            "Trying to mint too many NFTs"
        );

        _mintPrivate(msg.sender, 1);
        _tokensMintedByAddress[msg.sender] += 1;
    }

    function mint(
        bytes32[] memory _proof,
        bool _includeMerch,
        bool _includeMeta,
        bool _includeUtility
    )
        public
        payable
        onlyIfAvailable(_includeMerch, _includeMeta, _includeUtility)
        nonReentrant
    {
        if (mintStatus == MintStatus.PRESALE) {
            _mintPresale(_proof);
        } else if (mintStatus == MintStatus.PUBLIC) {
            _mintPublic();
        }

        if (_includeMerch) {
            MintNFTAbi merchPass = MintNFTAbi(payable(merchPassAddress));
            bool _result = merchPass.mint(msg.sender);
            if (!_result) {
                // Refund sender
                payable(msg.sender).sendValue(MERCH_PASS_PRICE);
                // Can listen on frontend
                emit MintFailure(msg.sender, "Merch failure");
            }
        }

        if (_includeMeta) {
            MintNFTAbi metaPass = MintNFTAbi(payable(metaPassAddress));
            bool _result = metaPass.mint(msg.sender);
            if (!_result) {
                // Refund sender
                payable(msg.sender).sendValue(META_PASS_PRICE);
                // Can listen on frontend
                emit MintFailure(msg.sender, "Meta failure");
            }
        }

        if (_includeUtility) {
            MintNFTAbi utilityPass = MintNFTAbi(payable(utilityPassAddress));
            bool _result = utilityPass.mint(msg.sender);
            if (!_result) {
                // Refund sender
                payable(msg.sender).sendValue(UTILITY_PASS_PRICE);
                // Can listen on frontend
                emit MintFailure(msg.sender, "Utility failure");
            }
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

    function setMetaPassAddress(address _metaPassAddress) public onlyOwner {
        metaPassAddress = _metaPassAddress;
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
        require(_owners.length + _amount <= SUPPLY, "Not enough supply");
        require(_amount < GIVEAWAY, "Giving away too many NFTs");
        require(_amount > 0, "Amount must be greater than zero");

        _mintPrivate(_to, _amount);
    }

    ///
    /// Modifiers
    ///
    modifier onlyIfAvailable(
        bool _includeMerch,
        bool _includeMeta,
        bool _includeUtility
    ) {
        require(mintStatus != MintStatus.CLOSED, "Minting is closed");
        // Assumes giveaways are done AFTER minting
        require(_owners.length < MINTABLE_SUPPLY, "Collection is sold out");

        uint256 expectedValue = PRICE;
        if (_includeMerch) {
            expectedValue += MERCH_PASS_PRICE;
        }
        if (_includeMeta) {
            expectedValue += META_PASS_PRICE;
        }
        if (_includeUtility) {
            expectedValue += UTILITY_PASS_PRICE;
        }
        require(msg.value == expectedValue, "Ether sent is not correct");

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

    ///
    /// MISC
    ///
    function tokenURI(uint256 tokenId)
        external
        view
        virtual
        override
        returns (string memory)
    {
        require(
            _exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );
        return string(abi.encodePacked(baseTokenURI, tokenId.toString()));
    }
}