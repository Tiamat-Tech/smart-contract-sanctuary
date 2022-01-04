//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract THORForce is Ownable, ERC721, ERC721Enumerable, ReentrancyGuard {
    using Counters for Counters.Counter;
    using Strings for uint256;

    Counters.Counter private _tokenIds;

    uint256 public constant MINT_COST = 0.45 ether;
    uint256 public constant MAX_MINT = 2;
    uint256 public constant MAX_SUPPLY = 260;
    uint256 public constant MINTABLE_MAX_SUPPLY = 222;
    uint256 private _whitelistTokenIds = 222;

    string public claimedUri;
    string public unclaimedUri;
    string public provenance;
    bool public isMintOpen;
    bool public isClaimOpen;

    mapping(uint256 => bool) internal claimStatus;
    mapping(address => uint256) internal mintCount;
    mapping(address => uint256) internal whitelist;

    event SetBaseURI(string claimedUri, string unclaimedUri);
    event SetProvenance(string provenance);
    event Minted(address indexed user, uint256 entries);
    event MintByOwner(uint256 entries);
    event ToggleMint();
    event ToggleClaim();
    event Claimed(uint256 tokenId);
    event Whitelisted(address indexed user, uint256 entries);
    event MintWhitelisted(address indexed user, uint256 entries);
    event Withdraw(address indexed owner, uint256 amount);

    constructor(string memory _nftName, string memory _nftSymbol)
        ERC721(_nftName, _nftSymbol)
    {
        isClaimOpen = true;
    }

    function setBaseURI(
        string calldata _claimedUri,
        string calldata _unclaimedUri
    ) public onlyOwner {
        claimedUri = _claimedUri;
        unclaimedUri = _unclaimedUri;

        emit SetBaseURI(claimedUri, unclaimedUri);
    }

    function setProvenance(string calldata _provenance) public onlyOwner {
        provenance = _provenance;
        emit SetProvenance(_provenance);
    }

    function mint(uint256 numOfTokens) external payable nonReentrant {
        require(isMintOpen == true, "Mint not started");
        require(numOfTokens <= MAX_MINT, "Mint amount exceeds max mint count.");
        require(
            mintCount[msg.sender] + numOfTokens <= MAX_MINT,
            "Mint amount exceeds max mint count."
        );
        require(
            _tokenIds.current() + numOfTokens <= MINTABLE_MAX_SUPPLY,
            "Max mints reached"
        );

        if (msg.sender != owner()) {
            require(msg.value == numOfTokens * MINT_COST, "Incorrect payment");
        }

        mintCount[msg.sender] += numOfTokens;

        for (uint256 i = 0; i < numOfTokens; i++) {
            _tokenIds.increment();
            _safeMint(msg.sender, _tokenIds.current());
        }

        if (_tokenIds.current() == MINTABLE_MAX_SUPPLY) {
            isMintOpen = false;
        }

        emit Minted(msg.sender, numOfTokens);
    }

    function mintWhitelist(uint256 numOfTokens) external nonReentrant {
        require(isMintOpen == true, "Mint not started");
        require(numOfTokens <= MAX_MINT, "Mint amount exceeds max mint count.");
        require(
            _whitelistTokenIds + numOfTokens <= MAX_SUPPLY,
            "Token amount exceeds max supply"
        );

        require(
            whitelist[msg.sender] >= numOfTokens,
            "Mint amount exceeds whitelisted count."
        );

        whitelist[msg.sender] -= numOfTokens;

        for (uint256 i = 0; i < numOfTokens; i++) {
            _whitelistTokenIds++;
            _safeMint(msg.sender, _whitelistTokenIds);
        }

        emit MintWhitelisted(msg.sender, numOfTokens);
    }

    function mintByOwner(uint256 numOfTokens) external onlyOwner {
        require(
            _whitelistTokenIds + numOfTokens <= MAX_SUPPLY,
            "Max mints reached"
        );

        for (uint256 i = 0; i < numOfTokens; i++) {
            _whitelistTokenIds++;
            _safeMint(msg.sender, _whitelistTokenIds);
        }

        emit MintByOwner(numOfTokens);
    }

    function setWhitelist(
        address[] calldata addresses,
        uint256[] calldata entries
    ) public onlyOwner {
        require(
            addresses.length == entries.length,
            "Addresses and entries are not matching."
        );

        for (uint256 i = 0; i < addresses.length; i++) {
            require(addresses[i] != address(0), "Cannot be zero address");

            whitelist[addresses[i]] = entries[i];

            emit Whitelisted(addresses[i], entries[i]);
        }
    }

    function claim(uint256 tokenId) external nonReentrant {
        require(ownerOf(tokenId) == msg.sender, "You can only claim your NFT");
        require(claimStatus[tokenId] == false, "You already claimed");
        require(isClaimOpen == true, "Claim paused by owner");

        claimStatus[tokenId] = true;

        emit Claimed(tokenId);
    }

    function withdraw() external onlyOwner {
        uint256 proceeds = address(this).balance;
        (bool sent, ) = msg.sender.call{value: proceeds}("");
        require(sent, "Could not send proceeds");

        emit Withdraw(msg.sender, proceeds);
    }

    function toggleMintOpen() public onlyOwner {
        isMintOpen = !isMintOpen;

        emit ToggleMint();
    }

    function toggleClaim() public onlyOwner {
        isClaimOpen = !isClaimOpen;

        emit ToggleClaim();
    }

    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        require(tokenId > 0, "Token id cannot be less than 1.");
        require(tokenId <= _tokenIds.current(), "Token id exceeds max limit");

        if (claimStatus[tokenId] == true)
            return
                string(
                    abi.encodePacked(claimedUri, tokenId.toString(), ".json")
                );

        return
            string(abi.encodePacked(unclaimedUri, tokenId.toString(), ".json"));
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override(ERC721, ERC721Enumerable) {
        return super._beforeTokenTransfer(from, to, tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}