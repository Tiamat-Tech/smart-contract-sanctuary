pragma solidity ^0.8.0;

import "../node_modules/@openzeppelin/contracts/utils/Counters.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

contract NFT is ERC1155 {
    using Counters for Counters.Counter;
    Counters.Counter private Id;
    struct nftGenerateInfo {
        address creator;
        uint256 royalty;
        address nftContractAddress;
        uint256 nftTokenId;
        string tokenURI;
        uint256 timeOfGenerate;
    }

    mapping(uint256 => nftGenerateInfo) nftLogs;
    mapping(uint256 => address) creator;
    mapping(uint256 => address) owner;
    mapping(uint256 => mapping(address => uint256)) royalty;
    mapping(uint256 => mapping(address => bool)) isAPPROVED;
    mapping(uint256 => mapping(address => uint256)) nftPrice;

    event Mint(
        uint256 tokenId,
        string uri,
        address tokenOwner,
        nftGenerateInfo newNFT
    );

    constructor(string memory uri) public ERC1155(uri) {
        _setURI(uri);
    }

    function mint(
        uint256 amount,
        uint256 Royalty,
        string memory newuri
    ) public returns (nftGenerateInfo memory) {
        uint256 _Id = Id.current();
        _setURI(newuri);
        nftGenerateInfo memory newNft =
            nftGenerateInfo({
                creator: msg.sender,
                royalty: Royalty,
                nftContractAddress: address(this),
                nftTokenId: _Id,
                tokenURI: newuri,
                timeOfGenerate: block.timestamp
            });
        nftLogs[_Id] = newNft;
        _mint(msg.sender, _Id, amount, "");
        creator[_Id] = msg.sender;
        owner[_Id] = msg.sender;
        royalty[_Id][msg.sender] = Royalty;
        emit Mint(_Id, newuri, owner[_Id], newNft);
        Id.increment();
        return newNft;
    }

    function getRoyalty(uint256 id, address _creator)
        external
        view
        returns (uint256)
    {
        return royalty[id][_creator];
    }

    function getOwner(uint256 id) external view returns (address) {
        return owner[id];
    }

    function getCreator(uint256 id) external view returns (address) {
        return creator[id];
    }

    function getNFTDetails(uint256 id)
        external
        view
        returns (nftGenerateInfo memory)
    {
        return nftLogs[id];
    }
}