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

    event Minted(uint256 tokenId, address to, uint256 end, address[] members, uint256 contributionId, string _contribution, address minter);
    event MemberAdded(uint256 tokenId, address account);
    event Contributed(uint256 tokenId, uint256 contributionId, string metadata, address creator);
    event Filled(uint256 tokenId, string tokenURI);

    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    Counters.Counter private _contributionIds;

    struct Contribution {
        string metadata; // JSON URI
        uint256 createdAt;
        address creator;
    }

    uint256 public memberLimit;
    uint256 public supply;
    uint public mintFee;
    address public feeAddress;

    mapping (uint256 => uint256) public promptEndsAt;
    mapping (uint256 => address[]) public promptMembers;
    mapping (uint256 => mapping (address => bool)) public promptMembership;
    mapping (uint256 => uint256) private promptMemberCount;

    Contribution[] public contributions;
    mapping (uint256 => uint256) public promptContributions;
    mapping (uint256 => uint256[]) public promptContributionsArr;

    constructor(
        string memory tokenName,
        string memory tokenSymbol,
        uint256 _memberLimit,
        uint256 _supply,
        uint256 _mintFee,
        address _feeAddress
    ) ERC721(
        tokenName,
        tokenSymbol
    ) {
        require(_memberLimit >= 2, "_memberLimit cannot be smaller than 2");
        require(_supply > 0, "_supply cannot be 0");
        require(_mintFee > 0, "_mintFee cannot be 0");
        require(_feeAddress != address(0), "feeAddress cannot be null address");

        memberLimit = _memberLimit;
        supply = _supply;
        mintFee = _mintFee;
        feeAddress = _feeAddress;
    }

    modifier onlyMemberOf(uint256 _tokenId) {
        if (promptMembership[_tokenId][msg.sender] == false) {
            revert('not a prompt member');
        }
        _;
    }
    modifier onlyOwnerOf(uint256 _tokenId) {
        if (msg.sender != ownerOf(_tokenId)) {
            revert('not the prompt owner');
        }
        _;
    }
    modifier isNotEnded(uint256 _tokenId) {
        require(promptEndsAt[_tokenId] >= block.timestamp,
                'prompt has ended');
        _;
    }
    modifier isEnded(uint256 _tokenId) {
        require(promptEndsAt[_tokenId] <= block.timestamp,
                'prompt has not ended yet');
        _;
    }
    modifier isNotEmpty(string memory _content) {
        require(bytes(_content).length != 0, 'contribution cannot be empty');
        _;
    }

    function mint(address _to, uint256 _endsAt, address[] memory _accounts, string memory _contribution)
        external
        isNotEmpty(_contribution)
    {
        require(_tokenIds.current() < supply, "reached token supply limit");
        require(_to != address(0), 'address cannot be null address');
        require(_accounts.length <= memberLimit, "reached member limit");

        uint256 newTokenId = _tokenIds.current();

        promptEndsAt[newTokenId] = _endsAt;
        promptMembers[newTokenId] = _accounts;

        for (uint256 i=0; i < _accounts.length; i++) {
            require(_accounts[i] != address(0), 'address cannot be null address');
            require(!promptMembership[newTokenId][_accounts[i]], 'address is already a member of prompt');
            promptMembership[newTokenId][_accounts[i]] = true;
            promptMemberCount[newTokenId]++;
        }

        uint256 contributionId = _contributionIds.current();
        contributions.push(Contribution(_contribution, block.timestamp, msg.sender));
        promptContributions[newTokenId] = contributionId;
        promptContributionsArr[newTokenId].push(contributionId);
        _contributionIds.increment();

        _safeMint(_to, newTokenId);
        // _setTokenURI(newTokenId, _tokenURI); // <- empty NFT
        _tokenIds.increment();

        emit Minted(newTokenId, _to, _endsAt, _accounts, contributionId, _contribution, msg.sender);
    }

    function addMember(uint256 _tokenId, address _account)
        external
        isNotEnded(_tokenId)
        onlyOwnerOf(_tokenId)
    {
        require(_account != address(0), 'address cannot be null address');
        require(!promptMembership[_tokenId][_account], 'address is already a member');
        require(promptMemberCount[_tokenId] <= memberLimit, "reached member limit");

        promptMembership[_tokenId][_account] = true;
        promptMemberCount[_tokenId]++;

        emit MemberAdded(_tokenId, _account);
    }

    function contribute(uint256 _tokenId, string memory _metadata)
        external
        isNotEnded(_tokenId)
        onlyMemberOf(_tokenId)
        isNotEmpty(_metadata)
    {
        uint256 contributionId = _contributionIds.current();
        contributions.push(Contribution(_metadata, block.timestamp, msg.sender));
        promptContributions[_tokenId] = contributionId;
        promptContributionsArr[_tokenId].push(contributionId);
        _contributionIds.increment();

        emit Contributed(_tokenId, contributionId, _metadata, msg.sender);
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

    function getContributions(uint256 _tokenId) external view returns (string[] memory) {
        string[] memory contributionMetadata = new string[](promptContributionsArr[_tokenId].length);

        for(uint i=0; i < promptContributionsArr[_tokenId].length; i++) {
            Contribution memory c = contributions[promptContributionsArr[_tokenId][i]];
            contributionMetadata[i] = c.metadata;
        }
        return contributionMetadata;
    }

    function getContribution(uint256 _contributionId) external view returns (string memory) {
        return contributions[_contributionId].metadata;
    }

    function getMembers(uint256 _tokenId) external view virtual returns (address[] memory) {
        return promptMembers[_tokenId];
    }

    function memberCount(uint256 _tokenId) external view virtual returns (uint256) {
        return promptMemberCount[_tokenId];
    }

    function isMember(uint256 _tokenId, address _account) external view returns (bool) {
        return promptMembership[_tokenId][_account];
    }

    function isOwner(uint256 _tokenId, address _account) external view returns (bool) {
        return ownerOf(_tokenId) == _account;
    }
}