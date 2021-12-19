//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

import "hardhat/console.sol";

/// @title Prompts
/// @author Burak Arıkan & Sam Hart
/// @dev extends ERC721 with empty minting, duration, and verified contributors

contract Prompts is ERC721URIStorage, Ownable {

    event Minted(uint256 tokenId, address beneficiary, string promptURI, uint256 end, address minter);
    event MemberAdded(uint256 tokenId, address account);
    event Contributed(uint256 tokenId, uint256 contributionId, string metadata, address creator);
    event Filled(uint256 tokenId, string tokenURI);

    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    Counters.Counter private _contributionIds;

    struct Prompt {
        string metadata; // JSON URI
        uint256 endsAt;
    }
    struct Contribution {
        string metadata; // JSON URI
        uint256 createdAt;
        address creator;
    }

    Prompt[] public prompts;
    mapping (uint256 => mapping (address => bool)) public promptMembers;
    mapping (uint256 => uint256) private promptMemberCount;
    Contribution[] public contributions;
    mapping (uint256 => uint256) public promptContributions;
    mapping (uint256 => uint256[]) public promptContributionsArr;

    constructor(
        string memory tokenName,
        string memory tokenSymbol
    ) ERC721(
        tokenName,
        tokenSymbol
    ) {}

    modifier onlyMemberOf(uint _tokenId) {
        if (promptMembers[_tokenId][msg.sender] == false) {
            revert('not a prompt member');
        }
        _;
    }
    modifier onlyOwnerOf(uint _tokenId) {
        if (msg.sender != ownerOf(_tokenId)) {
            revert('not the prompt owner');
        }
        _;
    }
    modifier isNotEnded(uint _tokenId) {
        require(prompts[_tokenId].endsAt >= block.timestamp,
                'prompt has ended');
        _;
    }
    modifier isEnded(uint _tokenId) {
        require(prompts[_tokenId].endsAt <= block.timestamp,
                'prompt has not ended yet');
        _;
    }

    function mint(address _to, string memory _promptURI, uint256 _end, address[] memory _accounts) external {
        uint256 newTokenId = _tokenIds.current();
        _safeMint(_to, newTokenId);
        // _setTokenURI(newTokenId, _tokenURI); // empty NFT

        prompts.push(Prompt(_promptURI, _end));

        promptMembers[newTokenId][_to] = true;
        promptMemberCount[newTokenId]++;

        for (uint256 i=0; i < _accounts.length; i++) {
            require(_accounts[i] != address(0), 'address cannot be null address');
            require(!promptMembers[newTokenId][_accounts[i]], 'address is already a member of prompt');
            promptMembers[newTokenId][_accounts[i]] = true;
            promptMemberCount[newTokenId]++;
        }

        _tokenIds.increment();

        emit Minted(newTokenId, _to, _promptURI, _end, msg.sender);
    }

    function addMember(uint256 _tokenId, address _account)
        external
        isNotEnded(_tokenId)
        onlyOwnerOf(_tokenId)
    {
        require(_account != address(0), 'address cannot be null address');
        require(!promptMembers[_tokenId][_account], 'address is already a member of prompt');
        promptMembers[_tokenId][_account] = true;
        promptMemberCount[_tokenId]++;

        emit MemberAdded(_tokenId, _account);
    }

    function contribute(uint256 _tokenId, string memory _metadata)
        external
        isNotEnded(_tokenId)
        onlyMemberOf(_tokenId)
    {
        uint256 contributionId = _contributionIds.current();
        contributions.push(Contribution(_metadata, block.timestamp, msg.sender));
        promptContributions[_tokenId] = contributionId;
        promptContributionsArr[_tokenId].push(contributionId);
        _contributionIds.increment();

        emit Contributed(_tokenId, contributionId, _metadata, msg.sender);
    }

    function getContributions(uint256 _tokenId)
        external
        view
        returns (string[] memory)
    {
        string[] memory contributionMetadata = new string[](promptContributionsArr[_tokenId].length);

        for(uint i=0; i < promptContributionsArr[_tokenId].length; i++) {
            Contribution memory c = contributions[promptContributionsArr[_tokenId][i]];
            contributionMetadata[i] = c.metadata;
        }
        return contributionMetadata;
    }

    function fill(uint256 _tokenId, string memory _tokenURI, address _to)
        external
        onlyOwnerOf(_tokenId)
        isEnded(_tokenId)
    {
        _setTokenURI(_tokenId, _tokenURI);

        require(_to != address(0), 'address cannot be null address');
        require(_to != msg.sender, 'address is already the owner');
        _safeTransfer(msg.sender, _to, _tokenId, "");

        emit Filled(_tokenId, _tokenURI);
    }

    function isOwner(uint256 _tokenId, address _account) external view returns (bool) {
        return ownerOf(_tokenId) == _account;
    }

    function isMember(uint256 _tokenId, address _account) external view returns (bool) {
        return promptMembers[_tokenId][_account];
    }

    function getContributionContent(uint256 _contributionId) external view returns (string memory) {
        return contributions[_contributionId].metadata;
    }

    function memberCount(uint256 _tokenId) external view virtual returns (uint256) {
        return promptMemberCount[_tokenId];
    }
}