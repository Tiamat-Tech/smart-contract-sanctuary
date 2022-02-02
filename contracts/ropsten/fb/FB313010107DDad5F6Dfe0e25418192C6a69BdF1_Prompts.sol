//SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

import "hardhat/console.sol";

/// @title Prompts
/// @author Burak Arıkan & Sam Hart
/// @notice extends ERC721 with collective creation and verified contributions

contract Prompts is ERC721URIStorage, Ownable {

    /// ============ Events ============

    event Minted(uint256 tokenId, address to, uint256 end, address[] members, string contributionURI, address minter);
    event MemberAdded(uint256 tokenId, address account);
    event Contributed(uint256 tokenId, string contributionURI, address creator);
    event Finalized(uint256 tokenId, string tokenURI, address to);
    event ContributedAndFinalized(uint256 tokenId, string tokenURI, address owner, string contributionURI, address contributor);

    /// ============ Structs ============

    struct Contribution {
        string contributionURI;
        uint256 createdAt;
        address creator;
    }

    /// ============ Mutable storage ============

    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    mapping (uint256 => uint256) public endsAt; // endsAt[tokenId]
    mapping (uint256 => address[]) public members; // endsAt[tokenId]
    mapping (uint256 => mapping (address => bool)) public membership; // membership[tokenId][address]
    mapping (uint256 => uint256) public memberCount; // memberCount[tokenId]
    mapping (uint256 => Contribution[]) public contributions; // contributions[tokenId]
    mapping (uint256 => uint256) public contributionCount; // contributionCount[tokenId]
    mapping (uint256 => mapping (address => bool)) public contributed; // contributed[tokenId][address]
    mapping (address => bool) public allowlist; // allowlist[address]


    /// ============ Immutable storage ============

    uint256 public memberLimit;
    uint256 public totalSupply;
    uint public mintCost;
    address public feeAddress;

    /// ============ Constructor ============

    /// @notice Creates a new Prompts NFT contract
    /// @param tokenName name of NFT
    /// @param tokenSymbol symbol of NFT
    /// @param _memberLimit member limit of each NFT
    /// @param _totalSupply total NFTs to mint
    /// @param _mintCost in wei per NFT
    /// @param _feeAddress where mint costs are paid
    constructor(
        string memory tokenName,
        string memory tokenSymbol,
        uint256 _memberLimit,
        uint256 _totalSupply,
        uint256 _mintCost,
        address _feeAddress
    ) ERC721(
        tokenName,
        tokenSymbol
    ) {
        require(_memberLimit >= 2, "_memberLimit cannot be smaller than 2");
        require(_totalSupply > 0, "_totalSupply cannot be 0");
        require(_mintCost > 0, "_mintCost cannot be 0");
        require(_feeAddress != address(0), "feeAddress cannot be null address");

        memberLimit = _memberLimit;
        totalSupply = _totalSupply;
        mintCost = _mintCost;
        feeAddress = _feeAddress;
        allowlist[msg.sender] = true;
    }

    /// ============ Modifiers ============

    modifier isAllowed() {
        require (allowlist[msg.sender] == true,
            'account is not in allowlist');
        _;
    }
    modifier onlyOwnerOf(uint256 _tokenId) {
        if (msg.sender != ownerOf(_tokenId)) {
            revert('not the prompt owner');
        }
        _;
    }
    modifier onlyMemberOf(uint256 _tokenId) {
        if (membership[_tokenId][msg.sender] == false) {
            revert('not a prompt member');
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
        require(bytes(_content).length != 0, 'URI cannot be empty');
        _;
    }
    modifier memberNotContributed(uint256 _tokenId) {
        require (contributed[_tokenId][msg.sender] == false,
            'member already contributed');
        _;
    }
    modifier isLastContribution(uint _tokenId) {
        require(contributionCount[_tokenId] == memberLimit - 1,
            'is not the last contribution');
        _;
    }
    modifier finalizable(uint _tokenId) {
        require(contributionCount[_tokenId] == memberLimit || endsAt[_tokenId] <= block.timestamp,
            'not all members contributed or prompt has not ended yet');
        _;
    }

    /// ============ Functions ============

    function mint(address _to, uint256 _endsAt, address[] memory _members, string memory _contributionURI)
        external
        isNotEmpty(_contributionURI)
        isAllowed()
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
            allowlist[_members[i]] = true;
        }

        endsAt[newTokenId] = _endsAt;

        contributions[newTokenId].push(Contribution(_contributionURI, block.timestamp, msg.sender));
        contributed[newTokenId][msg.sender] = true;
        contributionCount[newTokenId]++;

        // TODO: payable mint (transfer mintCost from sender to feeAddress)
        // TODO: name in members?
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
        require(memberCount[_tokenId] < memberLimit, "reached member limit");

        membership[_tokenId][_account] = true;
        memberCount[_tokenId]++;
        members[_tokenId].push(_account);
        allowlist[_account] = true;

        emit MemberAdded(_tokenId, _account);
    }

    function contribute(uint256 _tokenId, string memory _contributionURI)
        external
        isNotEnded(_tokenId)
        onlyMemberOf(_tokenId)
        isNotEmpty(_contributionURI)
        memberNotContributed(_tokenId)
    {
        contributions[_tokenId].push(Contribution(_contributionURI, block.timestamp, msg.sender));
        contributed[_tokenId][msg.sender] = true;
        contributionCount[_tokenId]++;

        emit Contributed(_tokenId, _contributionURI, msg.sender);
    }

    function contributeAndFinalize(uint256 _tokenId, string memory _contributionURI, string memory _tokenURI)
        external
        onlyMemberOf(_tokenId)
        isNotEmpty(_contributionURI)
        isNotEmpty(_tokenURI)
        memberNotContributed(_tokenId)
        isLastContribution(_tokenId)
    {
        contributions[_tokenId].push(Contribution(_contributionURI, block.timestamp, msg.sender));
        contributed[_tokenId][msg.sender] = true;
        contributionCount[_tokenId]++;

        _setTokenURI(_tokenId, _tokenURI);

        emit ContributedAndFinalized(_tokenId, _tokenURI, ownerOf(_tokenId), _contributionURI, msg.sender);
    }

    function finalize(uint256 _tokenId, string memory _tokenURI)
        external
        onlyMemberOf(_tokenId)
        isNotEmpty(_tokenURI)
        finalizable(_tokenId)
    {
        _setTokenURI(_tokenId, _tokenURI);

        emit Finalized(_tokenId, _tokenURI, ownerOf(_tokenId));
    }

    /// ============ Read-only funtions ============

    /// @notice Get current count of minted tokens
    /// @return Returns number
    function tokenCount() external view virtual returns (uint256) {
        return _tokenIds.current();
    }

    /// @notice Check if an address is member of a prompt
    /// @return Returns true or false
    function isMember(uint256 _tokenId, address _account) external view virtual returns (bool) {
        return membership[_tokenId][_account];
    }

    /// @notice Check if all prompt members contributed
    /// @return Returns true or false
    function isCompleted(uint256 _tokenId) external view virtual returns (bool) {
        return contributionCount[_tokenId] == memberLimit;
    }

    /// @notice Get a prompt's all data
    /// @return Returns (owner: address, endsAt: blocktime, tokenURI: string, members: address[], contributions: Contribution[])
    function getPrompt(uint256 _tokenId) external view virtual
        returns (
            address,
            uint256,
            string memory,
            address[] memory,
            Contribution[] memory
        )
    {
        return(
            ownerOf(_tokenId),
            endsAt[_tokenId],
            tokenURI(_tokenId),
            members[_tokenId],
            contributions[_tokenId]
        );
    }
}