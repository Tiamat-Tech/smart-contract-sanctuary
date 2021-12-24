pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract Web3GiftsNFT is Ownable, ERC721, ERC721Enumerable, ERC721URIStorage {
    string public contract_metadata;
    using Counters for Counters.Counter;
    Counters.Counter public _tokenIDs;

    struct Gift {
        uint256 tokenID;
        uint256 amount;
        bool redeemed;
        address from;
        uint256 redeem_at;
    }
    
    event GiftMintedToOwner(address indexed previousOwner,address indexed newOwner);
    event GiftRedeemed(address indexed owner,uint256 indexed tokenID);

    mapping(uint256 => Gift) private gifts;
    mapping(address => uint256[]) private ownerGifts;

    uint public _giftCharge = 0.01 ether;
    bool public _scheduledRedeemSwitch = true;

    constructor(
        string memory _name,
        string memory _symbol,
        string memory _metadata
    ) ERC721(_name, _symbol) {
        contract_metadata = _metadata;
    }

    function contractURI() public view returns (string memory) {
        return contract_metadata;
    }

    function mint(string memory uri, address ownerAddress, uint256 redeem_at, string memory message) public payable returns (uint256) {
        require(msg.value > _giftCharge, "Gift cannot be lesser than 0.01 ETH");

        // check if message length is greater than 140 chars
        require(bytes(message).length <= 140, "Message cannot be greater than 140 characters");

        _tokenIDs.increment();
        uint256 newID = _tokenIDs.current();

        uint256 amount = msg.value - _giftCharge;

        Gift memory newGift = Gift({
            tokenID: newID,
            amount: amount,
            redeemed: false,
            redeem_at: redeem_at,
            from: msg.sender
        });

        gifts[newID] = newGift;
        ownerGifts[ownerAddress].push(newID);

        _safeMint(msg.sender, newID);
        _setTokenURI(newID, uri);

        transferToken(msg.sender, ownerAddress, newID);

        emit GiftMintedToOwner(msg.sender, ownerAddress);

        return newID;
    }

    function getAllGifts(address owner) public view returns (Gift[] memory) {

        Gift[] memory result = new Gift[](ownerGifts[owner].length);

        for (uint256 i = 0; i < ownerGifts[owner].length; i++) {
            result[i] = gifts[ownerGifts[owner][i]];
        }

        return result;
    }

    function redeem(uint256 tokenID) public returns (uint256) {
        Gift memory gift = gifts[tokenID];
        require(gift.redeemed == false, "Gift has already been redeemed");

        address tokenOwner = ownerOf(tokenID);
        require(tokenOwner == msg.sender, "You do not own this gift");

        if(gift.redeem_at > 0 && _scheduledRedeemSwitch){
            require(gift.redeem_at < block.timestamp, "Gift can't be redeemed yet");
        }

        payable(msg.sender).transfer(gift.amount);
        gifts[tokenID].redeemed = true;

        emit GiftRedeemed(msg.sender, tokenID);

        return gift.amount;
    }

    function redeemAll() public {
        for (uint256 i = 0; i < ownerGifts[msg.sender].length; i++) {
            if(!gifts[ownerGifts[msg.sender][i]].redeemed) {
                if(gifts[ownerGifts[msg.sender][i]].redeem_at > 0){
                    require(gifts[ownerGifts[msg.sender][i]].redeem_at < block.timestamp, "Gift can't be redeemed yet");
                }

                payable(msg.sender).transfer(gifts[ownerGifts[msg.sender][i]].amount);
                gifts[ownerGifts[msg.sender][i]].redeemed = true;

                emit GiftRedeemed(msg.sender, gifts[ownerGifts[msg.sender][i]].tokenID);
            }
        }
    }

    function transferToken(
        address from,
        address to,
        uint256 tokenID
    ) public returns (bool) {
        super.safeTransferFrom(from, to, tokenID);
        return true;
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function _burn(uint256 tokenId)
        internal
        override(ERC721, ERC721URIStorage)
    {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function ownerOf(uint256 tokenId) public view override returns (address) {
        return super.ownerOf(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function withdraw() public onlyOwner {
        uint balance = address(this).balance;
        payable(msg.sender).transfer(balance);
    }

    function overrideRedeemTime(uint256 tokenID, uint256 timestamp) public onlyOwner returns(Gift memory)  {
        gifts[tokenID].redeem_at = timestamp;
        return gifts[tokenID];
    }

    function overrideGiftCharge(uint256 updatedCharge) public onlyOwner {
        _giftCharge = updatedCharge;
    }

    function updateScheduleRedeemSwitch(bool switchStatus) public onlyOwner {
        _scheduledRedeemSwitch = switchStatus;
    }

    function updateContractMetadata(string memory metadata) public onlyOwner {
        contract_metadata = metadata;
    }
}