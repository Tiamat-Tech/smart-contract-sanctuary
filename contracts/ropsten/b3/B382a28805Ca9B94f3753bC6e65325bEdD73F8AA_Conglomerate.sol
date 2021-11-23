// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./ConglomerateBuilder.sol";

contract Conglomerate is ERC721Enumerable, Ownable, ReentrancyGuard {
    bool public can_claim;
    bool public can_trade;
    address public builder;

    uint256 private balance;

    uint128 private constant maximumAmountOfTokens = 2030;

    string[] private colors = [
        "#fffbc7",
        "#ffe3cc",
        "#ffd1d4",
        "#ffb3f1",
        "#cdadff",
        "#99c3ff",
        "#85e0ff",
        "#85f5ff",
        "#8fffe7",
        "#b3ffba"
    ];

    string[] private months = [
        "January",
        "February",
        "March",
        "April",
        "May",
        "June",
        "July",
        "August",
        "September",
        "October",
        "November",
        "December"
    ];

    string[] private jobs = [
        "Specialist",
        "Inspector",
        "Tester",
        "Insider",
        "Engineer",
        "Representative",
        "Technician",
        "Broker",
        "Advisor",
        "Supervisor",
        "Counselor",
        "Trendwatcher",
        "Negotiator",
        "Breeder",
        "Minter",
        "Flipper",
        "Visionary",
        "Facilitator",
        "Farmer",
        "Auctioneer",
        "Clerk",
        "Professional",
        "Ghostwriter",
        "Critic",
        "Officer",
        "Consultant",
        "Expert",
        "Coordinator",
        "Strategist",
        "Researcher",
        "Recruiter",
        "Ambassador",
        "Spellchecker",
        "Evaluator",
        "Analyst",
        "Assessor",
        "Instructor",
        "Scientist",
        "Attache",
        "Creator",
        "Designer",
        "Agent",
        "Paralegal",
        "Manipulator",
        "Solutionist",
        "Trader",
        "Hackerman",
        "Observer",
        "Board member",
        "Adventurer",
        "CT Influencer",
        "Hedger",
        "Floorer",
        "Accumulator",
        "Predictor",
        "Compounder",
        "Educator",
        "Enjoyer",
        "Believer",
        "gm-er",
        "Airdropper",
        "Apprentice"
    ];

    mapping(string => uint256) issuedTokens;

    modifier onlyIfTradable() {
        require(
            can_trade,
            "The JPEG Megacorp: Trading is currently unavailable."
        );
        _;
    }

    constructor() ERC721("The JPEG Megacorp", "JPEG") Ownable() {}

    function setTradability(bool tradability) public onlyOwner {
        can_trade = tradability;
    }

    function setClaimability(bool claimability) public onlyOwner {
        can_claim = claimability;
    }

    function setBuilderAddress(address a) public onlyOwner {
        builder = a;
    }

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public override onlyIfTradable {
        super.transferFrom(from, to, tokenId);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public override onlyIfTradable {
        super.safeTransferFrom(from, to, tokenId);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) public override onlyIfTradable {
        super.safeTransferFrom(from, to, tokenId, _data);
    }

    function approve(address to, uint256 tokenId)
        public
        override
        onlyIfTradable
    {
        super.approve(to, tokenId);
    }

    function setApprovalForAll(address operator, bool approved)
        public
        override
        onlyIfTradable
    {
        super.setApprovalForAll(operator, approved);
    }

    function withdrawBalance() public nonReentrant onlyOwner {
        uint256 b = balance;

        payable(msg.sender).transfer(b);

        balance = 0;
    }

    function MINT_TOKEN__THE_JPEG_MEGACORP__GET_ID_CARD()
        public
        payable
        nonReentrant
    {
        require(
            totalSupply() < maximumAmountOfTokens,
            "The JPEG Megacorp: All positions are occupied. Good bye."
        );

        require(
            _msgSender() == owner() || can_claim,
            "The JPEG Megacorp: Claiming the token is currently unavailable"
        );

        require(
            msg.value == 0.05 ether,
            "The JPEG Megacorp: Mint fee is 0.05 ETH."
        );

        _mint(_msgSender(), totalSupply());

        balance += 0.05 ether;
    }

    function random(string memory phrase, uint256 tokenId)
        internal
        pure
        returns (uint256)
    {
        return uint256(keccak256(abi.encodePacked(phrase, tokenId)));
    }

    function getRarity(uint256 tokenId) public pure returns (Rarity) {
        uint256 modulo = uint256(keccak256(abi.encodePacked("R_", tokenId))) %
            maximumAmountOfTokens;

        if (modulo <= 101) {
            return Rarity.LEGENDARY;
        } else if (modulo <= 304) {
            return Rarity.EPIC;
        } else if (modulo <= 1014) {
            return Rarity.RARE;
        } else {
            return Rarity.COMMON;
        }
    }

    function getRandomData(
        string[] memory data,
        string memory seed,
        uint256 tokenId
    ) public pure returns (string memory) {
        return data[random(seed, tokenId) % data.length];
    }

    function getJob(
        Rarity rarity,
        uint256 tokenId,
        uint256 offset
    ) public view returns (string memory) {
        string memory uri = IConglomerateBuilder(builder).getURI(
            rarity,
            tokenId,
            offset,
            colors,
            months,
            jobs
        );

        if (issuedTokens[uri] > 0) {
            return getJob(rarity, tokenId, offset + 1);
        } else {
            return uri;
        }
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override {
        super._beforeTokenTransfer(from, to, tokenId);

        issuedTokens[tokenURI(tokenId)] = tokenId + 1;
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        require(
            builder != address(0),
            "The JPEG Megacorp: Cannot create token."
        );

        require(
            tokenId < totalSupply(),
            "The JPEG Megacorp: This token doesn't exist."
        );

        string memory uri = getJob(getRarity(tokenId), tokenId, 0);

        return uri;
    }
}