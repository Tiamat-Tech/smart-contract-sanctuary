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

    event Minted(uint256 tokenId, address to, uint256 end, address[] members, string contributionURI, address minter);
    event MemberAdded(uint256 tokenId, address account);
    event Contributed(uint256 tokenId, string contributionURI, address creator);
    event Finalized(uint256 tokenId, string tokenURI, address to);

    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    struct Contribution {
        string contributionURI;
        uint256 createdAt;
        address creator;
    }

    mapping (uint256 => uint256) public endsAt; // endsAt[tokenId]
    mapping (uint256 => address[]) public members; // endsAt[tokenId]
    mapping (uint256 => mapping (address => bool)) public membership; // membership[tokenId][address]
    mapping (uint256 => uint256) public memberCount;
    mapping (uint256 => Contribution[]) public contributions; // contributions[tokenId]

    uint256 public memberLimit;
    uint256 public totalSupply;
    uint public mintFee;
    address public feeAddress;

    constructor(
        string memory tokenName,
        string memory tokenSymbol,
        uint256 _memberLimit,
        uint256 _totalSupply,
        uint256 _mintFee,
        address _feeAddress
    ) ERC721(
        tokenName,
        tokenSymbol
    ) {
        require(_memberLimit >= 2, "_memberLimit cannot be smaller than 2");
        require(_totalSupply > 0, "_totalSupply cannot be 0");
        require(_mintFee > 0, "_mintFee cannot be 0");
        require(_feeAddress != address(0), "feeAddress cannot be null address");

        memberLimit = _memberLimit;
        totalSupply = _totalSupply;
        mintFee = _mintFee;
        feeAddress = _feeAddress;
    }

    modifier onlyMemberOf(uint256 _tokenId) {
        if (membership[_tokenId][msg.sender] == false) {
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
        require(endsAt[_tokenId] >= block.timestamp,
                'prompt has ended');
        _;
    }
    modifier isEnded(uint256 _tokenId) {
        require(endsAt[_tokenId] <= block.timestamp,
                'prompt has not ended yet');
        _;
    }
    modifier isNotEmpty(string memory _content) {
        require(bytes(_content).length != 0, 'contribution cannot be empty');
        _;
    }

    function mint(address _to, uint256 _endsAt, address[] memory _members, string memory _contributionURI)
        external
        isNotEmpty(_contributionURI)
    {
        require(_tokenIds.current() < totalSupply, "reached token supply limit");
        require(_to != address(0), 'address cannot be null address');
        require(_members.length <= memberLimit, "reached member limit");

        uint256 newTokenId = _tokenIds.current();

        for (uint256 i=0; i < _members.length; i++) {
            require(_members[i] != address(0), 'address cannot be null address');
            require(!membership[newTokenId][_members[i]], 'address is already a member of prompt');
            membership[newTokenId][_members[i]] = true;
            memberCount[newTokenId]++;
            members[newTokenId].push(_members[i]);
        }

        endsAt[newTokenId] = _endsAt;

        contributions[newTokenId].push(Contribution(_contributionURI, block.timestamp, msg.sender));

        // TODO: payable mint (transfer mintFee from sender to feeAddress)

        _safeMint(_to, newTokenId);
        // _setTokenURI(newTokenId, _tokenURI); // <- empty NFT

        _tokenIds.increment();

        emit Minted(newTokenId, _to, _endsAt, _members, _contributionURI, msg.sender);
    }

    function addMember(uint256 _tokenId, address _account)
        external
        isNotEnded(_tokenId)
        onlyOwnerOf(_tokenId)
    {
        require(_account != address(0), 'address cannot be null address');
        require(!membership[_tokenId][_account], 'address is already a member');
        require(memberCount[_tokenId] <= memberLimit, "reached member limit");

        membership[_tokenId][_account] = true;
        memberCount[_tokenId]++;
        members[_tokenId].push(_account);

        emit MemberAdded(_tokenId, _account);
    }

    function contribute(uint256 _tokenId, string memory _contributionURI)
        external
        isNotEnded(_tokenId)
        onlyMemberOf(_tokenId)
        isNotEmpty(_contributionURI)
    {
        contributions[_tokenId].push(Contribution(_contributionURI, block.timestamp, msg.sender));

        emit Contributed(_tokenId, _contributionURI, msg.sender);
    }

    function finalize(uint256 _tokenId, string memory _tokenURI, address _to)
        external
        onlyOwnerOf(_tokenId)
        isEnded(_tokenId)
    {
        require(_to != address(0), 'address cannot be null address');
        require(_to != msg.sender, 'address is already the owner');

        _setTokenURI(_tokenId, _tokenURI);
        _safeTransfer(msg.sender, _to, _tokenId, "");

        emit Finalized(_tokenId, _tokenURI, _to);
    }

    function tokenCount() external view virtual returns (uint256) {
        return _tokenIds.current();
    }

    function isMember(uint256 _tokenId, address _account) external view virtual returns (bool) {
        return membership[_tokenId][_account];
    }

    function getPrompt(uint256 _tokenId) external view virtual
        returns (
            address,
            uint256,
            address[] memory,
            Contribution[] memory
        )
    {
        return(
            ownerOf(_tokenId),
            endsAt[_tokenId],
            members[_tokenId],
            contributions[_tokenId]
        );
    }
}