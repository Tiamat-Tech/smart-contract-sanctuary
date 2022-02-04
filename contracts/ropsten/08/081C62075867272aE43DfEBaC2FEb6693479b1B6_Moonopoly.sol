// SPDX-License-Identifier: MIT
// Developer: @Brougkr

/**@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@,.................................#@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@%............................................../@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@........................................................%@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@,[email protected]@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@......................................................................#@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@.............,,***[email protected]@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@..............,******...........................................................*@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@#.................,***,[email protected]@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@%........................................................................................,@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@.......,**,.................................................................................#@@@@@@@@@@@@@
@@@@@@@@@@@@*................................[email protected]@@@@@@@@@@@
@@@@@@@@@@@...................................[email protected]@@@@@@@@@@
@@@@@@@@@@..................................................................................................../@@@@@@@@@
@@@@@@@@@........,............................................................................................./@@@@@@@@
@@@@@@@@........,,..............................................................................................#@@@@@@@
@@@@@@@........,,.................................[email protected]@@@@@@
@@@@@@(........**..,*****,.........................[email protected]@@@@@
@@@@@@........,*,..,****,,........................................................................................&@@@@@
@@@@@%........***,................................................................................................,@@@@@
@@@@@,........**,*..................................[email protected]@@@@
@@@@@........,****..................................[email protected]@@@@
@@@@@........,**,**.................................[email protected]@@@@
@@@@@.........*****,    ................,*******....[email protected]@@@@
@@@@@*........**,***.     ..............********,..Moonopoly [email protected]@@@@
@@@@@&.........   ,**.    ...............******.........**........................................................,@@@@@
@@@@@@.....          *.  ...............................,,[email protected]@@@@@
@@@@@@%...           .*,...........................[email protected]@@@@@
@@@@@@@....          ,***...........        ......[email protected]@@@@@@
@@@@@@@@....       .******,.........        ...............   ..................................................&@@@@@@@
@@@@@@@@@.........,,,,,,,,,,,.........     .....,,,,,..........................................................%@@@@@@@@
@@@@@@@@@@..........**********,..................,,...........................................................&@@@@@@@@@
@@@@@@@@@@@..........***....,***,...............................................,**[email protected]@@@@@@@@@@
@@@@@@@@@@@@%..........*....****,**,..........................................,*****,......................,@@@@@@@@@@@@
@@@@@@@@@@@@@@...........*******,*****,.........,***,.......,,.................,,**,[email protected]@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@...........*****,,,*******.....******.....,****.........................................(@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@...........,.......*********,..,,.................................................../@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@.................**************,.......................................,,.......&@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@#.............,***,***,***,***,**,..........................,,,***,........,@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@*..............,******,.,******......**,*******************,[email protected]@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@&.................    .*************,*************,............*@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@#.......................,,,,****,,,,,..................*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@(............................................,@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*...............................%@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@&&%%&&@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@**/

pragma solidity 0.8.10;
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract Moonopoly is ERC1155, Ownable, Pausable, ReentrancyGuard
{
    // Initialization
    string public constant name = "Moonopoly";
    string public constant symbol = "MOON";
    string public _BASE_URI = "https://ipfs.io/ipfs/QmUQBkrxxk9dm78zhzNR41FmHPYrXKUB1QCAJ4ewtRPX7s/";

    // Variables
    uint256 public _CARDS_MINTED = 0;
    uint256 public _MAX_CARDS = 5555;
    uint256 public _MAX_CARDS_PURCHASE = 5;
    uint256 public _AIRDROP_AMOUNT = 3;
    uint256 public _CARD_PRICE = 0.03 ether;
    uint256 public _UNIQUE_CARDS = 33;
    uint256 public _MINIMUM_CARD_INDEX = 1;
    uint256 private _randomSeed = 0x00;

    // Sale State
    bool public _SALE_ACTIVE = true;
    bool public _AIRDROP_ACTIVE = true;
    bool public _ALLOW_MULTIPLE_PURCHASES = true;

    // Mappings
    mapping(uint256 => uint256) public _CARD_ID_ALLOCATION;
    mapping (address => bool) public minted;
    mapping (address => uint256) public airdrop;

    // Events
    event MoonopolyAirdropClaimed(address indexed recipient, uint indexed amt);
    event MoonopolyPublicMint(address indexed recipient, uint indexed amt);
    event AddAirdropRecipients(address[] indexed wallets);

    // Constructor That Initializes ERC-1155
    constructor() ERC1155("https://ipfs.io/ipfs/QmUQBkrxxk9dm78zhzNR41FmHPYrXKUB1QCAJ4ewtRPX7s/{id}.json") 
    { 
        _CARD_ID_ALLOCATION[1] = 1; // Lagos Full Miner
        _CARD_ID_ALLOCATION[2] = 3; // Lagos 4 Node
        _CARD_ID_ALLOCATION[3] = 5; // Lagos 3 Node
        _CARD_ID_ALLOCATION[4] = 7; // Lagos 2 Node
        _CARD_ID_ALLOCATION[5] = 9; // Lagos 1 Node
        _CARD_ID_ALLOCATION[6] = 40; // Miami
        _CARD_ID_ALLOCATION[7] = 40; // NYC
        _CARD_ID_ALLOCATION[8] = 60; // Beijing
        _CARD_ID_ALLOCATION[9] = 60; // Shanghai
        _CARD_ID_ALLOCATION[10] = 60; // Hong Kong
        _CARD_ID_ALLOCATION[11] = 90; // Mumbai
        _CARD_ID_ALLOCATION[12] = 90; // New Delhi
        _CARD_ID_ALLOCATION[13] = 90; // Kolkata
        _CARD_ID_ALLOCATION[14] = 100; // Zurich
        _CARD_ID_ALLOCATION[15] = 100; // Geneva
        _CARD_ID_ALLOCATION[16] = 100; // Basel
        _CARD_ID_ALLOCATION[17] = 150; // Lima
        _CARD_ID_ALLOCATION[18] = 150; // Cusko
        _CARD_ID_ALLOCATION[19] = 150; // Arequipa
        _CARD_ID_ALLOCATION[20] = 250; // Istanbul
        _CARD_ID_ALLOCATION[21] = 250; // Ankara
        _CARD_ID_ALLOCATION[22] = 250; // Izmir
        _CARD_ID_ALLOCATION[23] = 300; // Davao
        _CARD_ID_ALLOCATION[24] = 300; // Manila
        _CARD_ID_ALLOCATION[25] = 300; // Bohol
        _CARD_ID_ALLOCATION[26] = 400; // Saigon
        _CARD_ID_ALLOCATION[27] = 400; // Hanoi
        _CARD_ID_ALLOCATION[28] = 200; // Coinbase
        _CARD_ID_ALLOCATION[29] = 200; // Binance
        _CARD_ID_ALLOCATION[30] = 200; // Gemini
        _CARD_ID_ALLOCATION[31] = 200; // Kraken
        _CARD_ID_ALLOCATION[32] = 500; // Solar
        _CARD_ID_ALLOCATION[33] = 500; // Wind
    }

    // URI for decoding storage of tokenIDs
    function uri(uint256 tokenId) override public view returns (string memory) { return(string(abi.encodePacked(_BASE_URI, Strings.toString(tokenId), ".json"))); }

    /*---------------------*
    *   PUBLIC FUNCTIONS   * 
    *----------------------*/

    // Moonopoly Public Mint
    function MoonopolyMint(uint numberOfTokens) public payable nonReentrant
    {
        require(_SALE_ACTIVE, "Public Sale Must Be Active To Mint Cards");
        require(numberOfTokens <= _MAX_CARDS_PURCHASE, "Can Only Mint 5 Cards At A Time");
        require(_CARDS_MINTED + numberOfTokens <= _MAX_CARDS, "Purchase Would Exceed Max Supply Of Cards");
        require(_CARD_PRICE * numberOfTokens == msg.value, "Ether Value Sent Is Not Correct.");
        if(!_ALLOW_MULTIPLE_PURCHASES) { require(!minted[msg.sender], "Address Has Already Minted"); }
        minted[msg.sender] = true;
        for(uint i = 0; i < numberOfTokens; i++) 
        {
            uint256 cardID = _drawCard(numberOfTokens);
            _CARD_ID_ALLOCATION[cardID] -= 1;
            _CARDS_MINTED += 1;
            _mint(msg.sender, cardID, 1, "");
        }
        emit MoonopolyPublicMint(msg.sender, numberOfTokens);
    }

    // Moonopoly Airdrop
    function MoonopolyAirdrop() public nonReentrant
    {
        require(_AIRDROP_ACTIVE, "Airdrop is not active");
        uint amt = airdrop[msg.sender];
        require(amt > 0, "Sender wallet is not on airdrop Access List");
        airdrop[msg.sender] = 0;
        for(uint i = 0; i < amt; i++)
        {
            uint256 cardID = _drawCard(amt);
            _CARD_ID_ALLOCATION[cardID] -= 1;
            _CARDS_MINTED += 1;
            _mint(msg.sender, cardID, 1, "");
        }
        emit MoonopolyAirdropClaimed(msg.sender, amt);
    }

    /*---------------------*
    *   PRIVATE FUNCTIONS  * 
    *----------------------*/

    // Draws Pseudorandom Card From Available Stack
    function _drawCard(uint256 salt) private returns (uint256) 
    {
        for (uint256 i = 1; i < 4; i++) 
        {
            uint256 value = _pseudoRandom(i + _CARDS_MINTED + salt);
            if (_canMint(value)) 
            { 
                _randomSeed = value;
                return value; 
            }
        }

        // If Pseudorandom Card Is Not Valid After 3 Tries, Draw From Top Of The Stack
        return _drawAvailableCard();
    }

    /*---------------------*
    *    VIEW FUNCTIONS    * 
    *----------------------*/

    // Checks If Card ID Has Sufficient Allocation
    function _canMint(uint256 cardID) private view returns (bool) { return (_CARD_ID_ALLOCATION[cardID] > 0); }

    // Pseudorandom Number Generator
    function _pseudoRandom(uint256 salt) private view returns (uint256) 
    {
        uint256 pseudoRandom =
            uint256(
                keccak256(
                    abi.encodePacked(
                        salt,
                        block.timestamp,
                        blockhash(block.difficulty - 1),
                        block.number,
                        _randomSeed,
                        'MOONOPOLY',
                        'WEN MOON?',
                        msg.sender
                    )
                )
            ) % _UNIQUE_CARDS+_MINIMUM_CARD_INDEX;
        return pseudoRandom;
    }
    
    // Decrements Through Available Card Stack
    function _drawAvailableCard() private view returns (uint256) 
    {
        for(uint256 i = _UNIQUE_CARDS; i > _MINIMUM_CARD_INDEX; i--)
        {
            if(_canMint(i)) 
            { 
                return i;
            }
        }
        revert("Insufficient Card Amount"); // Insufficient Allocation Of CardIDs To Mint
    }

    // Returns Total Supply
    function totalSupply() external view returns (uint256) { return(_CARDS_MINTED); }

    // Conforms to ERC-1155 Standard
    function _beforeTokenTransfer(address operator, address from, address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data) internal override 
    { 
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data); 
    }

    /*---------------------*
    *    ADMIN FUNCTIONS   * 
    *----------------------*/

    // Batch Transfers Tokens
    function __batchTransfer(address[] calldata recipients, uint256[] calldata tokenIDs, uint256[] calldata amounts) external onlyOwner 
    { 
        for(uint i=0; i < recipients.length; i++) 
        { 
            _safeTransferFrom(msg.sender, recipients[i], tokenIDs[i], amounts[i], ""); 
        }
    }

    // Adds Airdrop Recipients To Airdrop Access List
    function __modifyAirdropRecipients(address[] calldata recipients) external onlyOwner
    {
        for(uint i = 0; i < recipients.length; i++)
        {
            airdrop[recipients[i]] = _AIRDROP_AMOUNT;
        }
        emit AddAirdropRecipients(recipients);
    }

    // Adds Airdrop Recipients To Airdrop Access List With Amounts
    function __modifyAirdropRecipientsAmt(address[] calldata recipients, uint256[] calldata amounts) external onlyOwner
    {
        require(recipients.length == amounts.length, "Invalid Data Formatting");
        for(uint i = 0; i < recipients.length; i++)
        {
            airdrop[recipients[i]] = amounts[i];
        }
        emit AddAirdropRecipients(recipients);
    }

    // For Future Expansions
    function __modifyCardAllocations(uint256[] calldata cardIDs, uint256[] calldata amounts) external onlyOwner
    {
        require(cardIDs.length == amounts.length, "Invalid Data Formatting");
        for(uint256 i = 0; i < cardIDs.length; i++)
        {
            _CARD_ID_ALLOCATION[cardIDs[i]] = amounts[i];
        }
    }

    // For Future Community Airdrops Outside Of The Core Collection :)
    function __mintExpansionCards(address[] calldata addresses, uint256[] calldata cardIDs, uint256[] calldata amounts) external onlyOwner
    {
        require(addresses.length == cardIDs.length && cardIDs.length == amounts.length, "Invalid Input Structure");
        _CARDS_MINTED += amounts.length;
        for(uint256 i = 0; i < addresses.length; i++) 
        { 
            _mint(addresses[i], cardIDs[i], amounts[i], ""); 
        }
    } 

    // Reserves Cards For Marketing & Core Team
    function __reserveCards(uint256 amt, address account) external onlyOwner
    {
        for(uint i = 0; i < amt; i++)
        {
            uint256 cardID = _drawCard(amt);
            _CARD_ID_ALLOCATION[cardID] -= 1;
            _CARDS_MINTED += 1;
            _mint(account, cardID, 1, "");
        }
    }

    // Sets Base URI For .json Hosting
    function __setBaseURI(string memory BASE_URI) external onlyOwner { _BASE_URI = BASE_URI; }

    // Sets Max Cards For future Card Expansion Packs
    function __setMaxCards(uint256 MAX_CARDS) external onlyOwner { _MAX_CARDS = MAX_CARDS; }

    // Sets Max Cards For Future Card Expansion Packs
    function __setUniqueCards(uint256 uniqueCards) external onlyOwner { _UNIQUE_CARDS = uniqueCards; }

    // Sets Minimum Card Index
    function __setCardIndex(uint256 MINIMUM_CARD_INDEX) external onlyOwner { _MINIMUM_CARD_INDEX = MINIMUM_CARD_INDEX; }

    // Sets Max Cards Purchasable By Wallet
    function __setMaxCardsPurchase(uint256 MAX_CARDS_PURCHASE) external onlyOwner { _MAX_CARDS_PURCHASE = MAX_CARDS_PURCHASE; }

    // Sets Future Card Price
    function __setCardPrice(uint256 CARD_PRICE) external onlyOwner { _CARD_PRICE = CARD_PRICE; }

    // Flips Allowing Multiple Purchases For Future Card Expansion Packs
    function __flip_allowMultiplePurchases() external onlyOwner { _ALLOW_MULTIPLE_PURCHASES = !_ALLOW_MULTIPLE_PURCHASES; }
    
    // Flips Sale State
    function __flip_saleState() external onlyOwner { _SALE_ACTIVE = !_SALE_ACTIVE; }
    
    // Flips Airdrop State
    function __flip_airdropState() external onlyOwner { _AIRDROP_ACTIVE = !_AIRDROP_ACTIVE; }

    // Withdraws Ether from Contract
    function __withdraw() external onlyOwner { payable(msg.sender).transfer(address(this).balance); }

    // Pauses Contract
    function __pause() external onlyOwner { _pause(); }

    // Unpauses Contract
    function __unpause() external onlyOwner { _unpause(); }
}