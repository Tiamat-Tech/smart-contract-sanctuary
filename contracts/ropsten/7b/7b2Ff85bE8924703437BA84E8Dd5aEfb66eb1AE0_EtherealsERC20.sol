//SPDX-License-Identifier: Unlicense

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract EtherealsERC20 is ERC20, Ownable, Pausable, ReentrancyGuard {

    IERC721 public ETHEREALS;

    uint256 constant public MAX_PER_TX = 50;
    uint256 constant public BASE_RATE = 10 ether;

    uint256 public totalStaked;
    mapping(address => uint256) public stash;
    mapping(address => uint256) public lastUpdate;
    mapping(uint256 => address) public tokenOwners;
    mapping(address => mapping(uint256 => uint256)) public ownedTokens;
    mapping(address => uint256) public stakedTokens;
    mapping(uint256 => uint256) public tokenIndex;
    mapping(address => bool) public allowed;

    constructor(address _ethereals)
        ERC20("EtherealsERC20", "TICKETS")
    {
        ETHEREALS = IERC721(_ethereals);
    }

    modifier onlyAllowed() {
        require(allowed[msg.sender], "Caller not allowed");
        _;
    }

    modifier isApprovedForAll() {
        require(
            ETHEREALS.isApprovedForAll(msg.sender, address(this)),
            "Contract not approved"
        );
        _;
    }

    function getOwnedByIndex(address account, uint256 index) public view returns (uint256) {
        require(index < stakedTokens[account], "Nonexistent token");

        return ownedTokens[account][index];
    }

    function getClaimable(address account) public view returns (uint256) {
        return stash[account] + _getPending(account);
    }

    function _getPending(address account) internal view returns (uint256) {
        return stakedTokens[account]
        * BASE_RATE
        * (block.timestamp - lastUpdate[account])
        / 1 days;
    }

    function _update(address account) internal {
        stash[account] += _getPending(account);
        lastUpdate[account] = block.timestamp;
    }

    function claim(address account) public nonReentrant {
        _claim(account);
    }

    function _claim(address account) internal whenNotPaused {
        require(msg.sender == account || allowed[msg.sender], "Caller not allowed");

        uint256 claimable = getClaimable(account);

        _mint(account, claimable);
        stash[account] = 0;
        lastUpdate[account] = block.timestamp;
    }

    function setAllowed(address account, bool isAllowed) external onlyOwner {
        allowed[account] = isAllowed;
    }

    function stake(uint256[] calldata tokenIds) external isApprovedForAll whenNotPaused {
        require(tokenIds.length <= MAX_PER_TX, "Exceeds max tokens per transaction");

        for (uint256 i = 0; i < tokenIds.length; i++) {
            require(ETHEREALS.ownerOf(tokenIds[i]) == msg.sender, "Caller is not token owner");
        }

        _update(msg.sender);

        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 current = tokenIds[i];

            tokenOwners[current] = msg.sender;
            tokenIndex[current] = stakedTokens[msg.sender];
            ownedTokens[msg.sender][tokenIndex[current]] = current;
            stakedTokens[msg.sender] += 1;

            ETHEREALS.transferFrom(msg.sender, address(this), tokenIds[i]);
        }

        totalStaked += tokenIds.length;
    }

    function unstake(uint256[] calldata tokenIds, bool claimTokens) external nonReentrant {
        require(tokenIds.length <= MAX_PER_TX, "Exceeds max tokens per transaction");

        for (uint256 i = 0; i < tokenIds.length; i++) {
            require(tokenOwners[tokenIds[i]] == msg.sender, "Caller is not token owner");
        }

        if (claimTokens) _claim(msg.sender);
        else _update(msg.sender);

        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 last = ownedTokens[msg.sender][stakedTokens[msg.sender] - 1];

            tokenOwners[tokenIds[i]] = address(0);
            tokenIndex[last] = tokenIndex[tokenIds[i]];
            ownedTokens[msg.sender][tokenIndex[tokenIds[i]]] = last;
            stakedTokens[msg.sender] -= 1;

            ETHEREALS.transferFrom(address(this), msg.sender, tokenIds[i]);
        }

        totalStaked -= tokenIds.length;
    }

    function burn(address from, uint256 amount) external onlyAllowed {
        _burn(from, amount);
    }

    function recoveryTransfer(address to, uint256 tokenId) external onlyOwner {
        require(ETHEREALS.ownerOf(tokenId) == address(this), "Staking contract is not token owner");
        require(tokenOwners[tokenId] == address(0),          "Token was not transferred accidentally");

        ETHEREALS.transferFrom(address(this), to, tokenId);
    }
}