// contracts/NFT.sol
// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";
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

// These contract definitions are used to create a reference to the OpenSea
// ProxyRegistry contract by using the registry's address (see isApprovedForAll).
contract OwnableDelegateProxy {

}

contract ProxyRegistry {
    mapping(address => OwnableDelegateProxy) public proxies;
}

contract GenesisNFT is Ownable, ERC721, IERC2981, ReentrancyGuard {
    using Address for address payable;
    using SafeMath for uint256;
    using Strings for uint256;

    enum MintStatus {
        CLOSED,
        PRESALE,
        PUBLIC
    }

    uint256 public constant PRE_SALE_LIMIT = 1;
    uint256 public constant PUBLIC_LIMIT = 2;
    uint256 public constant PRICE = 0.085 ether;
    uint256 public constant MERCH_PASS_PRICE = 0.04 ether;
    uint256 public constant META_PASS_PRICE = 0.04 ether;
    uint256 public constant UTILITY_PASS_PRICE = 0.03 ether;

    MintStatus public mintStatus = MintStatus.PUBLIC;
    string public baseTokenURI;
    uint256 public tokenCount = 0;
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

    MintNFTAbi private merchPassContract;
    MintNFTAbi private metaPassContract;
    MintNFTAbi private utilityPassContract;

    address private openSeaProxyRegistryAddress;
    bool private isOpenSeaProxyActive = true;

    uint256 private royaltyDivisor = 20;

    uint256 public giveawaySupply = 0;
    uint256 public supply = 5;
    uint256 public mintableSupply = supply - giveawaySupply;

    event MintFailure(address indexed to, string failure);

    constructor(
        address _openSeaProxyRegistryAddress,
        uint256 _supply,
        uint256 _giveawaySupply
    ) ERC721("Psychedelics NFT", "PSYCH") {
        openSeaProxyRegistryAddress = _openSeaProxyRegistryAddress;
        supply = _supply;
        giveawaySupply = _giveawaySupply;
        mintableSupply = _supply - _giveawaySupply;
    }

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
            _safeMint(_to, tokenCount++);
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
            bool _result = merchPassContract.mint(msg.sender);
            if (!_result) {
                // Refund sender
                payable(msg.sender).sendValue(MERCH_PASS_PRICE);
                // Can listen on frontend
                emit MintFailure(msg.sender, "Merch failure");
            }
        }

        if (_includeMeta) {
            bool _result = metaPassContract.mint(msg.sender);
            if (!_result) {
                // Refund sender
                payable(msg.sender).sendValue(META_PASS_PRICE);
                // Can listen on frontend
                emit MintFailure(msg.sender, "Meta failure");
            }
        }

        if (_includeUtility) {
            bool _result = utilityPassContract.mint(msg.sender);
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

    // function to disable gasless listings for security in case
    // opensea ever shuts down or is compromised
    function setIsOpenSeaProxyActive(bool _isOpenSeaProxyActive)
        external
        onlyOwner
    {
        isOpenSeaProxyActive = _isOpenSeaProxyActive;
    }

    function setMerchPassAddress(address _merchPassAddress) public onlyOwner {
        merchPassAddress = _merchPassAddress;
        merchPassContract = MintNFTAbi(payable(_merchPassAddress));
    }

    function setMetaPassAddress(address _metaPassAddress) public onlyOwner {
        metaPassAddress = _metaPassAddress;
        metaPassContract = MintNFTAbi(payable(_metaPassAddress));
    }

    function setMerkleRoot(bytes32 _merkleRoot) external onlyOwner {
        merkleRoot = _merkleRoot;
    }

    function setOpenSeaProxyRegistryAddress(
        address _openSeaProxyRegistryAddress
    ) external onlyOwner {
        openSeaProxyRegistryAddress = _openSeaProxyRegistryAddress;
    }

    function setRoyaltyDivisor(uint256 _divisor) external onlyOwner {
        royaltyDivisor = _divisor;
    }

    function setStatus(uint8 _status) external onlyOwner {
        mintStatus = MintStatus(_status);
    }

    function setUtilityPassAddress(address _utilityPassAddress)
        public
        onlyOwner
    {
        utilityPassAddress = _utilityPassAddress;
        utilityPassContract = MintNFTAbi(payable(_utilityPassAddress));
    }

    function setWithdrawDests(address _dest1, address _dest2) public onlyOwner {
        withdrawDest1 = _dest1;
        withdrawDest2 = _dest2;
    }

    ///
    /// Giveaway
    ///
    function giveaway(address _to, uint256 _amount) external onlyOwner {
        require(tokenCount + _amount <= supply, "Not enough supply");
        require(_amount < giveawaySupply, "Giving away too many NFTs");
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
        require(tokenCount < mintableSupply, "Collection is sold out");

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

        payable(withdrawDest1).sendValue(address(this).balance.div(20));
        payable(withdrawDest2).sendValue(address(this).balance);
    }

    ///
    /// Misc
    ///

    /**
     * @dev Override isApprovedForAll to allowlist user's OpenSea proxy accounts to enable gas-less listings.
     */
    function isApprovedForAll(address owner, address operator)
        public
        view
        override
        returns (bool)
    {
        // Get a reference to OpenSea's proxy registry contract by instantiating
        // the contract using the already existing address.
        ProxyRegistry proxyRegistry = ProxyRegistry(
            openSeaProxyRegistryAddress
        );
        if (
            isOpenSeaProxyActive &&
            address(proxyRegistry.proxies(owner)) == operator
        ) {
            return true;
        }

        return super.isApprovedForAll(owner, operator);
    }

    /**
     * @dev See {IERC2981-royaltyInfo}.
     */
    function royaltyInfo(uint256 tokenId, uint256 salePrice)
        external
        view
        override
        returns (address receiver, uint256 royaltyAmount)
    {
        require(_exists(tokenId), "Nonexistent token");

        return (address(this), salePrice.div(royaltyDivisor));
    }
}