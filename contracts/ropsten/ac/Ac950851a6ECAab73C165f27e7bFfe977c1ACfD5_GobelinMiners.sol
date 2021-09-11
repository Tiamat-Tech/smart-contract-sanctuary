//Contract based on [https://docs.openzeppelin.com/contracts/3.x/erc721](https://docs.openzeppelin.com/contracts/3.x/erc721)
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/finance/PaymentSplitter.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract GobelinMiners is
    ERC721URIStorage,
    ERC721Enumerable,
    Ownable,
    Pausable,
    PaymentSplitter,
    ReentrancyGuard
{
    enum State {
        Initialized,
        CommunityGrantStarted,
        CommunityGrantCompleted,
        PublicSaleStarted,
        PublicSaleCompleted
    }

    /*
     * Constants
     */

    // uint256 private constant _MAX_TOKEN = 10000;
    uint256 private constant _MAX_TOKEN = 5;
    uint256 private constant _MAX_MINT_PER_ADDRESS = 25;
    uint256 private constant _MAX_COMMUNITY_GRANT_MINT_PER_ADDRESS = 2;
    uint256 private constant _START_PRICE = 0.09 * 10**18;

    /*
     * Core
     */
    State public state = State.Initialized;

    /*
     * Community grant
     */
    event CommunityGrantSaleStarted(address account);
    event CommunityGrantSaleEnded(address account);
    mapping(address => bool) private _communityGrantAddresses;
    mapping(address => uint256) private _communityGrantAddressToTokenMinted;

    /*
     * Public sale
     */
    event PublicSaleStarted(address account);
    event PublicSaleEnded(address account);
    string private _IPFS_URI = "";
    /*
     * Random index assignment
     */
    uint256[_MAX_TOKEN] private _indices;
    uint256 private _nonce = 0;

    event Mint(uint256 indexed index, address indexed minter);

    constructor(
        // string memory IPFS_URI_,
        address[] memory payees_,
        uint256[] memory shares_
    ) PaymentSplitter(payees_, shares_) ERC721("GobelinMiners", "GM") {
        // _IPFS_URI = IPFS_URI_;
        _IPFS_URI = "biquetto.mypinata.cloud/ipfs/QmXtnukovnh2J18z1iJcoLvZYZQ7bk15PtUrDVxeaRze7F";
        // To avoid mistakes, we enforce shares being a percentage.
        uint256 shares = 0;
        for (uint256 i = 0; i < shares_.length; i++) {
            shares += shares_[i];
        }
        require(shares == 100, "Shares must be equal to 100");
    }

    function _baseURI() internal view override returns (string memory) {
        return _IPFS_URI;
    }

    function getPrice() public pure returns (uint256) {
        return _START_PRICE;
    }

    function mintForCommunityGrantSale(uint256 amount_)
        external
        payable
        whenNotPaused
        whenCurrentState(State.CommunityGrantStarted)
        nonReentrant
    {
        require(
            _communityGrantAddresses[msg.sender],
            "Address is not part of the community grant."
        );
        uint256 amount = _min(
            _MAX_COMMUNITY_GRANT_MINT_PER_ADDRESS -
                _communityGrantAddressToTokenMinted[_msgSender()],
            amount_
        );
        uint256 price = amount * getPrice();
        _hasEnoughFundsGuard(msg.value, price);
        _hasEnoughTokenGuard(amount);

        _communityGrantAddressToTokenMinted[_msgSender()] += amount;

        if (msg.value > price) {
            payable(msg.sender).transfer(msg.value - price);
        }

        _mint(amount);
    }

    function requestMintNFTForPublicSale(uint256 amount_)
        external
        payable
        whenNotPaused
        whenCurrentState(State.PublicSaleStarted)
        nonReentrant
    {
        uint256 amount = _min(_MAX_MINT_PER_ADDRESS, amount_);
        uint256 price = amount * getPrice();

        _hasEnoughFundsGuard(msg.value, price);
        _hasEnoughTokenGuard(amount);

        if (msg.value > price) {
            payable(msg.sender).transfer(msg.value - price);
        }

        _mint(amount);
    }

    function requestMintNFTForOwner(uint256 amount_)
        external
        payable
        onlyOwner
        whenNotPaused
        nonReentrant
    {
        _hasEnoughTokenGuard(amount_);
        _mint(amount_);
    }

    function _mint(uint256 amount_) internal {
        for (uint256 i = 0; i < amount_; i++) {
            uint256 index = _getRandomIndex();
            uint256 totalSize = _MAX_TOKEN - totalSupply();
            uint256 tokenId = (_indices[index] != 0 ? _indices[index] : index) +
                1;

            _indices[index] = _indices[totalSize - 1] == 0
                ? totalSize - 1
                : _indices[totalSize - 1];

            _safeMint(_msgSender(), tokenId);

            emit Mint(tokenId, _msgSender());
        }
    }

    function _getRandomIndex() internal returns (uint256) {
        _nonce++;
        return
            uint256(
                keccak256(
                    abi.encodePacked(
                        _nonce,
                        msg.sender,
                        block.difficulty,
                        block.timestamp
                    )
                )
            ) % (_MAX_TOKEN - totalSupply());
    }

    function _hasEnoughFundsGuard(uint256 price_, uint256 requiredPrice_)
        private
        pure
    {
        require(price_ >= requiredPrice_, "Insufficient funds.");
    }

    function _hasEnoughTokenGuard(uint256 amount) private view {
        require(
            totalSupply() + amount <= _MAX_TOKEN,
            "Not enough token available."
        );
    }

    /*
     * Release funds
     */
    function release(address payable account_) public override onlyOwner {
        super.release(account_);
    }

    /*
     * Community grant
     */

    function addAddressesToCommunityGrant(address[] memory addresses_)
        external
        onlyOwner
        whenNotPaused
    {
        for (uint256 i = 0; i < addresses_.length; i++) {
            _communityGrantAddresses[addresses_[i]] = true;
            _communityGrantAddressToTokenMinted[addresses_[i]] = 0;
        }
    }

    function removeAddressFromCommunityGrant(address address_)
        external
        onlyOwner
        whenNotPaused
    {
        delete _communityGrantAddresses[address_];
        delete _communityGrantAddressToTokenMinted[address_];
    }

    /*
     * State
     */

    function startCommunityGrantSale()
        external
        onlyOwner
        whenNotPaused
        whenCurrentState(State.Initialized)
    {
        state = State.CommunityGrantStarted;

        emit CommunityGrantSaleStarted(_msgSender());
    }

    function endCommunityGrantSale()
        external
        onlyOwner
        whenNotPaused
        whenCurrentState(State.CommunityGrantStarted)
    {
        state = State.CommunityGrantCompleted;

        emit CommunityGrantSaleEnded(_msgSender());
    }

    function startPublicSale()
        external
        onlyOwner
        whenNotPaused
        whenCurrentState(State.CommunityGrantCompleted)
    {
        state = State.PublicSaleStarted;

        emit PublicSaleStarted(_msgSender());
    }

    function endPublicSale()
        external
        onlyOwner
        whenNotPaused
        whenCurrentState(State.PublicSaleStarted)
    {
        state = State.PublicSaleCompleted;

        emit PublicSaleEnded(_msgSender());
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    modifier whenCurrentState(State state_) {
        require(uint256(state_) == uint256(state), "Unexpected state");
        _;
    }

    /*
     * Hooks
     */

    function _beforeTokenTransfer(
        address from_,
        address to_,
        uint256 tokenId_
    ) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from_, to_, tokenId_);

        require(!paused(), "Contract paused");
    }

    /*
     * Overrides
     */

    function tokenURI(uint256 tokenId_)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId_);
    }

    function _burn(uint256 tokenId_)
        internal
        override(ERC721, ERC721URIStorage)
    {
        super._burn(tokenId_);
    }

    function supportsInterface(bytes4 interfaceId_)
        public
        view
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId_);
    }

    function _min(uint256 a, uint256 b) private pure returns (uint256) {
        return a < b ? a : b;
    }
}