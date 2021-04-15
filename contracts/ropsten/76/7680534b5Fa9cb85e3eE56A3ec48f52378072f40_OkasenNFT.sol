// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/presets/ERC721PresetMinterPauserAutoId.sol";

contract OkasenNFT is ERC721PresetMinterPauserAutoId {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    struct NFTs {
        uint256 id;
        address recipient;
        string uri;
    }

    struct Royalties {
        uint256 tokenId;
        address receiver;
        uint256 amount;
    }

    mapping(uint256 => NFTs) internal tokenIdToNFTs;
    mapping(address => NFTs) internal addressToNFTs;
    mapping(uint256 => Royalties) internal tokenIdToRoyalty;

    uint64 public _royaltyAmount = 500000;

    event LogNFT(address recipient, string uri, uint256 tokenId);

    event _receivedRoyalties(
        address indexed _royaltyRecipient,
        address indexed _buyer,
        uint256 indexed _tokenId,
        address _tokenPaid,
        uint256 _amount
    );

    constructor()
        public
        ERC721PresetMinterPauserAutoId(
            "OKASEN",
            "OKN",
            "https://gateway.pinata.cloud/ipfs/"
        )
    {}

    function royaltyInfo(uint256 _tokenId)
        external
        returns (address receiver, uint256 amount)
    {
        Royalties storage royalty = tokenIdToRoyalty[_tokenId];
        return (royalty.receiver, royalty.amount);
    }

    function receivedRoyalties(
        address _royaltyRecipient,
        address _buyer,
        uint256 _tokenId,
        address _tokenPaid,
        uint256 _amount
    ) external {
      emit _receivedRoyalties(_royaltyRecipient, _buyer, _tokenId, _tokenPaid, _amount);
    }

    function mintNFT(address _recipient, string memory _tokenURI)
        public
        returns (uint256)
    {
        _tokenIds.increment();

        uint256 newItemId = _tokenIds.current();
        _mint(_recipient, newItemId);
        _setTokenURI(newItemId, _tokenURI);

        NFTs memory nft = NFTs(uint256(newItemId), _recipient, _tokenURI);
        Royalties memory royalty =
            Royalties(uint256(newItemId), _recipient, _royaltyAmount);

        tokenIdToNFTs[newItemId] = nft;
        addressToNFTs[_recipient] = nft;
        tokenIdToRoyalty[newItemId] = royalty;

        emit LogNFT(_recipient, _tokenURI, newItemId);

        return newItemId;
    }

    function getNFTByTokenId(uint256 _tokenId)
        public
        view
        returns (
            uint256 id,
            address recipient,
            string memory uri
        )
    {
        NFTs storage nft = tokenIdToNFTs[_tokenId];
        return (nft.id, nft.recipient, nft.uri);
    }

    function getNFTByAddress(address _address)
        public
        view
        returns (
            uint256 id,
            address recipient,
            string memory uri
        )
    {
        NFTs storage nft = addressToNFTs[_address];
        return (nft.id, nft.recipient, nft.uri);
    }
}