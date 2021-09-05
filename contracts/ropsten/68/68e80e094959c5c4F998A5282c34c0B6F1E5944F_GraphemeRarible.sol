pragma solidity 0.7.5;
// pragma solidity ^0.8.0;
pragma abicoder v2;
//SPDX-License-Identifier: MIT

//import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@rarible/royalties/contracts/impl/RoyaltiesV2Impl.sol";

// GET LISTED ON OPENSEA: https://testnets.opensea.io/get-listed/step-two

contract GraphemeRarible is ERC721, Ownable, RoyaltiesV2Impl {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    event Roll(address indexed owner, uint256[] tokens);
    event Claimed(uint256 tokenId);

    mapping(uint256 => ItemDetail) private _items;
    mapping(uint256 => uint256[]) private _wordTokenIds;
    mapping(uint256 => uint256[]) private _wordRows;
    mapping(uint256 => uint256[]) private _wordColumns;

    uint256 _claimFee = 0;
    uint256 _mintFee = 0;

    struct ItemDetail {
        bool isPrimitive;
        uint256 dna;
        bool isClaimed;
    }

    struct ItemPosition {
        uint256 tokenId;
        uint256 row;
        uint256 column;
    }

    constructor() public ERC721("Grapheme", "PHEME") {
        _setBaseURI("https://ipfs.io/ipfs/");
    }

    function mintItem(address payable to, string memory tokenURI)
        public
        returns (uint256)
    {
        _tokenIds.increment();

        uint256 id = _tokenIds.current();
        _mint(to, id);
        _setTokenURI(id, tokenURI);

        uint256 dna;
        _items[id] = ItemDetail({
            isPrimitive: false,
            dna: dna,
            isClaimed: false
        });

        // LibPart.Part[] memory royalties = new LibPart.Part[](1);
        // royalties[0] = LibPart.Part({account: to, value: 10});
        // _saveRoyalties(id, royalties);

        return id;
    }

    function mintItemForWord(
        address payable to,
        string memory tokenURI,
        uint256[] memory tokenIds
    ) public returns (uint256) {
        _tokenIds.increment();

        uint256 id = _tokenIds.current();
        _mint(to, id);
        _setTokenURI(id, tokenURI);

        uint256 dna;
        _items[id] = ItemDetail({
            isPrimitive: false,
            dna: dna,
            isClaimed: false
        });

        uint256 counter = 0;
        LibPart.Part[] memory royaltiesToSet = new LibPart.Part[](tokenIds.length);
        uint96 perShare = uint96(8000 / tokenIds.length); // 80% is Royalties to Letter owners
        for (counter = 0; counter < tokenIds.length; counter++) {
            address payable owner = royalties[tokenIds[counter]][0].account;
            royaltiesToSet[counter] = LibPart.Part({
                account: owner,
                value: perShare
            });
        }
        _saveRoyalties(id, royaltiesToSet);

        return id;
    }

    function reserveToken(address payable to, uint256 dna)
        private
        returns (uint256)
    {
        _tokenIds.increment();

        uint256 id = _tokenIds.current();
        _mint(to, id);
        _setTokenURI(id, 'QmW93rNp27mrdYChqa21jo2wfRoVpNp34N5V2KKgEdtrmm');
        _items[id] = ItemDetail({
            isPrimitive: true,
            dna: dna,
            isClaimed: false
        });

        LibPart.Part[] memory royalties = new LibPart.Part[](1);
        royalties[0] = LibPart.Part({account: to, value: 10});
        _saveRoyalties(id, royalties);
        return id;
    }

    /*
    // Fails as it will not accept struct[] as argument. Need to figure how to set this.
    function mintComplexCharacterToken(
        address to,
        ItemPosition[] memory itemPositions
    ) public returns (uint256) {
        _tokenIds.increment();

        uint256 id = _tokenIds.current();
        _mint(to, id);
        _setTokenURI(
            id,
            string(abi.encodePacked(customBaseUri, Strings.toString(id)))
        );
        _items[id] = ItemDetail({isPrimitive: false, identifier: _identifier});
        _itemPositions[id] = itemPositions;
        return id;
    }
    */

    function getDna(uint256 tokenId) public view returns (uint256) {
        return _items[tokenId].dna;
    }

    function isClaimed(uint256 tokenId) public view returns (bool) {
        return _items[tokenId].isClaimed;
    }

    function setMintFee(uint256 mintFee) public onlyOwner returns (bool) {
        _mintFee = mintFee;
        return true;
    }

    function setClaimFee(uint256 claimFee) public onlyOwner returns (bool) {
        _claimFee = claimFee;
        return true;
    }

    function transferFundsToOwner(address dao, uint256 amount)
        public
        payable
        onlyOwner
        returns (bool)
    {
        //  require(address(this).balance >= amount, "Address: insufficient balance");
        // _owner.transfer(amount);
        // To do
    }

    function rollToMint(address payable to) public payable {
        // should mint 'n' tokens.
        // should some funds go to DAO/Owner as creation fee??
        uint256 i = 0;
        uint256 prc = getRandomness();
        uint256[] memory tokensGenerated = new uint256[](6);
        for (i = 0; i <= 5; i++) {
            uint256 random = uint256(keccak256(abi.encodePacked(prc, i)));
            tokensGenerated[i] = reserveToken(to, random);
        }
        emit Roll(to, tokensGenerated);
    }

    function getRandomness() private view returns (uint256) {
        // do this as a temp measure. Investigate VRF options
        return
            uint256(
                keccak256(
                    abi.encodePacked(
                        block.timestamp,
                        msg.sender,
                        blockhash(block.number - 1)
                    )
                )
            );
    }

    function claimToken(uint256 tokenId, string memory tokenURI)
        public
        payable
    {
        require(
            _isApprovedOrOwner(_msgSender(), tokenId),
            "Grapheme: claimToken caller is not owner nor approved"
        );
        require(
            _items[tokenId].isClaimed == false,
            "Grapheme: Token is already claimed"
        );
        require(
            _items[tokenId].isPrimitive == true,
            "Grapheme: This type of token cannot be claimed"
        );

        // Claim fee
        require(msg.value >= _claimFee, "Claim fee is low");

        _items[tokenId].isClaimed = true;
        _setTokenURI(tokenId, tokenURI);

        emit Claimed(tokenId);
    }

    function mintWord(
        address payable to,
        string memory tokenURI,
        uint256[] memory tokenIds,
        uint256[] memory rows,
        uint256[] memory cols
    ) public returns (uint256) {
        uint256 tokenId = mintItemForWord(to, tokenURI, tokenIds);

        _wordTokenIds[tokenId] = tokenIds;
        _wordRows[tokenId] = rows;
        _wordColumns[tokenId] = cols;

        return tokenId;
    }

    function saveWord(
        uint256 tokenId,
        string memory tokenURI,
        uint256[] memory tokenIds,
        uint256[] memory rows,
        uint256[] memory cols
    ) public {
        require(
            _isApprovedOrOwner(_msgSender(), tokenId),
            "Grapheme: claimToken caller is not owner nor approved"
        );

        _setTokenURI(tokenId, tokenURI);
        _wordTokenIds[tokenId] = tokenIds;
        _wordRows[tokenId] = rows;
        _wordColumns[tokenId] = cols;
    }

    function GetWord(uint256 tokenId)
        public
        view
        returns (
            uint256[] memory tokenIds,
            uint256[] memory rows,
            uint256[] memory cols
        )
    {
        // require(
        //     _wordTokenIds[tokenId] != bytes4(0x0),
        //     "No words set"
        // );
        return (
            _wordTokenIds[tokenId],
            _wordRows[tokenId],
            _wordColumns[tokenId]
        );
    }

    function getInfo(uint256 tokenId)
        public
        view
        returns (
            uint256 dna,
            bool isClaimed,
            string memory tokenUri,
            address owner,
            bool isPrimitive
        )
    {
        return (
            _items[tokenId].dna,
            _items[tokenId].isClaimed,
            tokenURI(tokenId),
            ownerOf(tokenId),
            _items[tokenId].isPrimitive
        );
    }
}