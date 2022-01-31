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
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract Moonopoly is ERC1155, Ownable, Pausable, ReentrancyGuard
{
    // Initialization
    string public constant name = "Moonopoly";
    string public constant symbol = "MOON";
    string public _BASE_URI = "https://ipfs.io/ipfs/QmVtiErs3McktXqkXC3uQ4XfNz9aCTtEAuQ5fTZXLjhrFE/";
    
    // Token Amounts
    uint256 public _CARDS_MINTED = 1;
    uint256 public _TOTAL_SUPPLY = 0;
    uint256 public _MAX_CARDS = 5555;
    uint256 public _MAX_CARDS_PURCHASE = 5;
    uint256 public _AIRDROP_AMOUNT = 3;
    
    // Price
    uint256 public _CARD_PRICE = 0.03 ether;

    // Sale State
    bool public _SALE_ACTIVE = false;
    bool public _AIRDROP_ACTIVE = false;
    bool public _ALLOW_MULTIPLE_PURCHASES = false;

    // Mint Mapping
    mapping (address => bool) private minted;

    // Airdrop Mapping
    mapping (address => uint256) public airdrop;

    // Card Random Mapping
    mapping (uint256 => uint256) private cardMapping;

    // Events
    event MoonopolyAirdropClaimed(address indexed recipient, uint indexed amt);
    event MoonopolyPublicMint(address indexed recipient, uint indexed amt);

    // Constructor That Initializes ERC-1155 & Reserves Cards For Team
    constructor() ERC1155("https://ipfs.io/ipfs/QmVtiErs3McktXqkXC3uQ4XfNz9aCTtEAuQ5fTZXLjhrFE/{id}.json") { }

    // URI for decoding storage of tokenIDs
    function uri(uint256 tokenId) override public view returns (string memory) { return(string(abi.encodePacked(_BASE_URI, Strings.toString(tokenId), ".json"))); }

    // Moonopoly Public Mint
    function MoonopolyMint(uint numberOfTokens) public payable nonReentrant
    {
        require(_SALE_ACTIVE, "Public Sale Must Be Active To Mint Cards");
        require(numberOfTokens <= _MAX_CARDS_PURCHASE, "Can Only Mint 5 Cards At A Time");
        require(_CARDS_MINTED + numberOfTokens <= _MAX_CARDS, "Purchase Would Exceed Max Supply Of Cards");
        require(_CARD_PRICE * numberOfTokens == msg.value, "Ether Value Sent Is Not Correct. 0.03 ETH Per Card | 30000000000000000 WEI");
        if(!_ALLOW_MULTIPLE_PURCHASES) { require(!minted[msg.sender], "Address Has Already Minted"); }
        minted[msg.sender] = true;

        // Mints Cards
        for(uint i = 0; i < numberOfTokens; i++) 
        {
            _mint(msg.sender, cardMapping[_CARDS_MINTED], 1, "");
            _CARDS_MINTED += 1;
        }
        
        emit MoonopolyPublicMint(msg.sender, numberOfTokens);
    }

    // Moonopoly Airdrop
    function MoonopolyAirdrop() public nonReentrant
    {
        require(_AIRDROP_ACTIVE, "Airdrop is not active");
        uint amt = airdrop[msg.sender];
        require(amt > 0, "Sender wallet is not on airdrop whitelist");
        airdrop[msg.sender] = 0;
        for(uint i = 0; i < amt; i++)
        {
            _mint(msg.sender, cardMapping[_CARDS_MINTED], 1, "");
            _CARDS_MINTED += 1;
        }
        emit MoonopolyAirdropClaimed(msg.sender, amt);
    }
    
    // Conforms to ERC-1155 Standard
    function _beforeTokenTransfer(address operator, address from, address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data) internal override 
    { 
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data); 
    }

    // Batch Transfers Tokens
    function __batchTransfer(address[] calldata recipients, uint256[] calldata tokenIDs, uint256[] calldata amounts) external onlyOwner 
    { 
        for(uint i=0; i < recipients.length; i++) 
        { 
            _safeTransferFrom(msg.sender, recipients[i], tokenIDs[i], amounts[i], ""); 
        }
    }

    // Adds Airdrop Recipients To Airdrop Whitelist
    function __addAirdropRecipients(address[] calldata wallets) external onlyOwner
    {
        for(uint i = 0; i < wallets.length; i++)
        {
            airdrop[wallets[i]] = _AIRDROP_AMOUNT;
        }
    }

    // Adds Airdrop Recipients To Airdrop Whitelist With Amounts
    function __addAirdropRecipientsAmt(address[] calldata wallets, uint256[] calldata amounts) external onlyOwner
    {
        for(uint i = 0; i < wallets.length; i++)
        {
            airdrop[wallets[i]] = amounts[i];
        }
    }

    // Seeds The Card Stack
    function __seedRandom(uint256[] calldata index, uint256[] calldata card) external onlyOwner
    {
        for(uint256 i = 0; i < index.length; i++)
        {
            cardMapping[index[i]] = card[i];
        }
    }

    // Reserves Cards For Marketing & Team
    function __reserveCards(uint256 amt, address account) external onlyOwner
    {
        for(uint i = 0; i < amt; i++)
        {
            _mint(account, cardMapping[_CARDS_MINTED], 1, "");
            _CARDS_MINTED += 1;
        }
    }

    // Mints Specific Card Future Expansions
    function __mintCard(address to, uint256 cardID, uint256 amt) external onlyOwner
    {
        _mint(to, cardID, amt, "");
        _CARDS_MINTED += 1;
    }

    // For Future Airdrops Outside of the Collection
    function __mintCards(address[] calldata addresses, uint256[] calldata cardIDs, uint256[] calldata amounts) external onlyOwner
    {
        require(addresses.length > 0, "Invalid Amount");
        _TOTAL_SUPPLY = _TOTAL_SUPPLY + addresses.length;
        for(uint256 i = 0; i < addresses.length; i++) { _mint(addresses[i], cardIDs[i], amounts[i], ""); }
    } 

    // Sets Base URI For .json hosting
    function __setBaseURI(string memory BASE_URI) external onlyOwner { _BASE_URI = BASE_URI; }

    // Sets Max Cards for future Card Expansion Packs
    function __setMaxCards(uint256 MAX_CARDS) external onlyOwner { _MAX_CARDS = MAX_CARDS; }

    // Sets Max Cards Purchaseable by Wallet
    function __setMaxCardsPurchase(uint256 MAX_CARDS_PURCHASE) external onlyOwner { _MAX_CARDS_PURCHASE = MAX_CARDS_PURCHASE; }

    // Sets Future Card Price
    function __setCardPrice(uint256 CARD_PRICE) external onlyOwner { _CARD_PRICE = CARD_PRICE; }

    // Flips Allowing Multiple Purchases for future Card Expansion Packs
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

    // Returns Total Supply
    function totalSupply() external view returns (uint256) { return(_TOTAL_SUPPLY+_CARDS_MINTED); }
}