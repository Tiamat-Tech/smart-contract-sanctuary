// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import '@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol';
import '@openzeppelin/contracts/security/Pausable.sol';
import '@imtbl/imx-contracts/contracts/Mintable.sol';
import './utils/IMXMethods.sol';

contract FunkyMonkeyFratHouse is ERC721Enumerable, Pausable, Ownable, IMXMethods {

    // Events
    event ClaimedFunds(address wallet, uint256 _amountInWei);
    event AmountReserved(address addr, uint256 amount);
    event TreasuryWallet(address treasury);
    event ImmutableXAddress(address imx);
    event PresaleMintedTokens(address wallet, uint256 hasMinted);
    event StartingIndexBlock(uint256 startingIndexBlock);
    event StartingIndex(uint256 startingIndex);
    event DiscountPrice(uint256 pricePerMintInWei);
    event MaxSupply(uint256 maxSupply);
    event RevealTimestamp(uint256 timestamp);
    event MaxMintPerTransaction(uint256 maxMintPerTransaction);
    event BaseURI(string baseURI);

    // uint256 -> pricePerMint;
    uint256 public pricePerMint = 0.08 ether;
    // uint256 -> maxSupply;
    uint256 public maxSupply = 10000;
    // uint256 -> maxMintPerTransaction;
    uint256 public maxMintPerTransaction = 8;
    // uint256 -> revealTimestamp;
    uint256 public revealTimestamp;
    // uint256 -> startingIndex;
    uint256 public startingIndex;
    // uint256 -> startingIndexBlock;
    uint256 public startingIndexBlock;
    // uint256 -> amountReserved;
    uint256 public amountReserved;

    // struct -> User
    struct User {
        uint hasMinted;
    }
    // address => User
    mapping(address => User) public wallet;

    // address -> treasury
    address payable public treasury;

    // string -> baseURI
    string private baseURI;

    constructor(address _imx) ERC721("FunkyMonkeyFratHouse", "FFH") IMXMethods(_imx) {}

    /* MODIFIERS */

    /**
    * @dev Checks if the msg sender is the treasury wallet
    */
    modifier onlyTreasuryAndOwner() {
        require(_msgSender() == address(treasury) || _msgSender() == address(owner()), "FunkyMonkeyFratHouse: Msg sender is not the treasury address or the contract owner");
        _;
    }

    /* CALLABLE FUNCTIONS */

    /**
    * @dev Called by IMX, receives the parsed version of the blueprint the forward address of the contract.
    * @param to: Address of the recieving wallet, must be registered in IMX.
    * @param id: ID of the Token that will be minted
    * @param blueprint: Parsed blueprint without the TokenID prefix
    */
    function _mintFor(
        address to,
        uint256 id,
        bytes calldata blueprint
    ) internal override {
          _safeMint(to, id);
    }

    /**
    * @dev Reserves mints for giveaway
    */
    function reserveGiveaway(address addr, uint256 amount) external onlyOwner {
        uint supply = totalSupply();
        uint i;
        for (i = 0; i < amount; i++) {
            _safeMint(addr, supply + i);
        }

        amountReserved = amountReserved + amount;

        emit AmountReserved(addr, amount);
    }

    /**
    * @dev Only the treasury wallet can claim the eth in the contract.
    */
    function claimAllETH() external onlyTreasuryAndOwner {
        payable(address(treasury)).transfer(address(this).balance);

        emit ClaimedFunds(treasury, address(this).balance);
    }

    /**
    * @dev Only the treasury wallet can claim a porition of the eth in the contract.
    */
    function claimPortionOfETH(uint256 _amountInWei) external onlyTreasuryAndOwner {
        require(treasury == _msgSender(), "Ownable: caller is not the treasury");
        payable(address(treasury)).transfer(_amountInWei);

        emit ClaimedFunds(treasury, _amountInWei);
    }

    /* GETTERS */

    /**
    * @dev Gets the tokenId based on modulo of the max supply
    */
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        if (startingIndex == 0) {
            return super.tokenURI(0);
        }
        uint256 moddedId = (tokenId + startingIndex) % maxSupply;
        return super.tokenURI(moddedId);
    }

    /**
    * @dev Gets the base URI
    */
    function _baseURI() internal view override virtual returns (string memory) {
        return baseURI;
    }

    /* SETTERS */

    /**
    * @dev Sets the new base URI
    */
    function setBaseURI(string memory _URI) external onlyOwner {
        baseURI = _URI;

        emit BaseURI(_URI);
    }

    /**
    * @dev Sets the new treasury wallet.
    */
    function setTreasuryWallet(address payable _treasury) external onlyOwner {
        treasury = _treasury;

        emit TreasuryWallet(_treasury);
    }


    /**
    * @dev Sets the starting index for the collection to reveal.
    */
    function setStartingIndex() external onlyOwner {
        require(startingIndex == 0, "FunkyMonkeyFratHouse: Starting index is already set");
        require(startingIndexBlock != 0, "FunkyMonkeyFratHouse: Starting index block must be set");
        startingIndex = uint(blockhash(startingIndexBlock)) % maxSupply;
        // Just a sanity case in the worst case if this function is called late (EVM only stores last 256 block hashes)
        if ((block.number - startingIndexBlock) > 255) {
            startingIndex = uint(blockhash(block.number - 1)) % maxSupply;
        }

        emit StartingIndex(startingIndex);
    }

    /**
    * @dev Sets the starting index & starting index block for the collection to reveal. ONLY USE THIS FOR EMERGENCY.
    */
    function setEmergencyStartingIndex(uint256 _startingIndex, uint256 _startingIndexBlock) external onlyOwner {
        startingIndex = _startingIndex;
        startingIndexBlock = _startingIndexBlock;

        emit StartingIndex(_startingIndex);
        emit StartingIndexBlock(_startingIndexBlock);
    }

    /**
    * @dev Sets the new mint price
    */
    function setDiscountPrice(uint256 _pricePerMintInWei) external onlyOwner {
        pricePerMint = _pricePerMintInWei;

        emit DiscountPrice(_pricePerMintInWei);
    }

    /**
    * @dev Sets the new max supply
    */
    function setMaxSupply(uint256 _maxSupply) external onlyOwner {
        maxSupply = _maxSupply;

        emit MaxSupply(_maxSupply);
    }

    /**
    * @dev Sets the new reveal timestamp
    */
    function setRevealTimestamp(uint256 _timestamp) external onlyOwner {
        revealTimestamp = _timestamp;

        emit RevealTimestamp(_timestamp);
    }

    /**
    * @dev Sets the max mint per transaction
    */
    function setMaxMintPerTransaction(uint256 _maxMintPerTransaction) external onlyOwner {
        maxMintPerTransaction = _maxMintPerTransaction;

        emit MaxMintPerTransaction(_maxMintPerTransaction);
    }

    /**
    * @dev Sets the minted tokens for a user in the presale. EMERGENCY ONLY
    */
    function setPresaleMintedTokens(address _wallet, uint256 _hasMinted) external onlyOwner {
        wallet[_wallet].hasMinted = _hasMinted;

        emit PresaleMintedTokens(_wallet, _hasMinted);
    }
}