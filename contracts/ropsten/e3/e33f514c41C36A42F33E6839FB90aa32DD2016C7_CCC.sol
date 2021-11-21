// SPDX-License-Identifier: MIT

// Author: sqrtofpi (square root of pi) https://twitter.com/sqrt_of_pi_314

pragma solidity ^0.8.0;
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/finance/PaymentSplitter.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";



contract CCC is
    ERC721,
    ERC721Enumerable,
    Ownable,
    PaymentSplitter
{
    using SafeMath for uint256;
    using SafeMath for uint16;

    uint256 public MAX_AC_SUPPLY = 10;
    uint256 public MAX_REG_SUPPLY = 20;
    uint256 public MAX_COL_SUPPLY = 10;
    uint256 public MAX_SUPPLY = MAX_AC_SUPPLY+MAX_REG_SUPPLY + MAX_COL_SUPPLY;

    uint256 public AC_MINT_COUNT = 0;
    uint256 public REG_MINT_COUNT = 0;
    uint256 public COLLECTOR_MINT_COUNT = 0;
    // uint256[] remaining_ACs;



    uint16 _maxPurchaseCount = 20;
    uint256 _mintPrice = 1 ether;
    string _baseURIValue;
    mapping(uint256 => address) _AC_owner;
    mapping(uint256 => bool) _AC_claimed;
    bool public saleIsActive = false;
    bool public ACsaleIsActive = false;
    bool public _AC_open_to_public = false;
    
    // Splitter inputs
    address LCLMACHINE = 0xC0a8666eCC7B6B66c3a7eA954923F1C8025687F3;
    uint256 LCLMACHINE_SHARE = 40;
    address TANGO = 0xf7CBbA9dACF655e16f3226b280301907f2d30CCF;
    uint256 TANGO_SHARE = 40;
    address SQRTOFPI = 0xE844A7183DF4c7013c26aBd1dc066775d0d93FD0;
    uint256 SQRTOFPI_SHARE = 20;
    
    address[] payee_addresses = [LCLMACHINE,TANGO,SQRTOFPI];
    uint256[] payee_shares = [LCLMACHINE_SHARE,TANGO_SHARE,SQRTOFPI_SHARE];

    constructor(
    ) ERC721("CM", "CM") PaymentSplitter(payee_addresses, payee_shares) {
        // for (uint i = 0; i < MAX_AC_SUPPLY; i++){
        //     remaining_ACs.push(i);
        // }

    }

    function _baseURI() internal view override returns (string memory) {
        return _baseURIValue;
    }

    function baseURI() public view returns (string memory) {
        return _baseURI();
    }

    function setBaseURI(string memory newBase) public onlyOwner {
        _baseURIValue = newBase;
    }
    
    
    // Toggles for Sale and Presale states
    function flipSaleState() public onlyOwner {
        saleIsActive = !saleIsActive;
    }
    
    function flipACSaleState() public onlyOwner {
        ACsaleIsActive = !ACsaleIsActive;
    }
    
    function flipACPublicState() public onlyOwner {
        _AC_open_to_public = !_AC_open_to_public;
    }



    // getters and setters for minting limits
    function maxPurchaseCount() public view returns (uint256) {
        return _maxPurchaseCount;
    }

    function setMaxPurchaseCount(uint16 count) public onlyOwner {
        _maxPurchaseCount = count;
    }

    
    
    // getters and setters for mint price
    function baseMintPrice() public view returns (uint256) {
        return _mintPrice;
    }

    function setBaseMintPrice(uint256 price) public onlyOwner {
        _mintPrice = price;
    }

    function mintPrice(uint256 numberOfTokens) public view returns (uint256) {
        return _mintPrice.mul(numberOfTokens);
    }

    
    
    // Validate AC holders
    function addACOwners(uint8[] calldata ACtokenIDs,address[] calldata addresses) external onlyOwner{
        require(ACtokenIDs.length == addresses.length);
        for (uint256 i = 0; i < addresses.length; i++) {
            _AC_owner[ACtokenIDs[i]] = addresses[i];
            _AC_claimed[ACtokenIDs[i]] = false;
        }
    }
    
    
    function ownsAllACs(uint256[] calldata requested_tokens) public view returns (bool) {
        for (uint256 i = 0; i < requested_tokens.length; i++) {
            require(_AC_owner[requested_tokens[i]] == msg.sender);
        }
        return true;
    }
    
    function checkIfACclaimed(uint256 AC_id) public view returns (bool) {

           return _AC_claimed[AC_id];
    }
    
    


    // MODIFIERS
    modifier ACmintCountMeetsSupply(uint256 numberOfTokens) {
        require(
            AC_MINT_COUNT.add(numberOfTokens) <= MAX_AC_SUPPLY,
            "Purchase would exceed max AC Owner supply"
        );
        _;
    }
    
    modifier REGmintCountMeetsSupply(uint256 numberOfTokens) {
        require(
            REG_MINT_COUNT.add(numberOfTokens) <= MAX_REG_SUPPLY,
            "Purchase would exceed max REG supply"
        );
        _;
    }
    
    modifier COLmintCountMeetsSupply(uint256 numberOfTokens) {
        require(
            COLLECTOR_MINT_COUNT.add(numberOfTokens) <= MAX_COL_SUPPLY,
            "Purchase would exceed max COL supply"
        );
        _;
    }
    


    modifier doesNotExceedMaxPurchaseCount(uint256 numberOfTokens) {
        require(
            numberOfTokens <= _maxPurchaseCount,
            "Cannot mint more than 1 token at a time"
        );
        _;
    }

    modifier validatePurchasePrice(uint256 numberOfTokens) {
        require(
            mintPrice(numberOfTokens) == msg.value,
            "Ether value sent is not correct"
        );
        _;
    }
    
    // modifier validatePurchasePriceArray(uint256[] calldata tokens_to_mint) {
    //     require(
    //         mintPrice(tokens_to_mint.length) == msg.value,
    //         "Ether value sent is not correct"
    //     );
    //     _;
    // }
    
    
    // Minting Functions
    function _mintREGTokens(uint256 numberOfTokens, address to) internal {
        for (uint256 i = 0; i < numberOfTokens; i++) {
            _safeMint(to, MAX_AC_SUPPLY + REG_MINT_COUNT + 1);
            REG_MINT_COUNT += 1;
        }
    }
    
    function _mintCOLTokens(uint256 numberOfTokens, address to) internal {
        for (uint256 i = 0; i < numberOfTokens; i++) {
            _safeMint(to, MAX_AC_SUPPLY+MAX_REG_SUPPLY + COLLECTOR_MINT_COUNT + 1);
            COLLECTOR_MINT_COUNT += 1;
        }
    }
    
    function OwnerMint(uint256 numberOfTokens)
        public
        REGmintCountMeetsSupply(numberOfTokens)
        onlyOwner
    {

        _mintREGTokens(numberOfTokens, msg.sender);
    }
    
    
    // mint Chromamorph by the owner of the corresponding AutoChroma holder
    function mint_CM_from_AC(uint256[] calldata tokens_to_mint)
        internal
    {

        for (uint256 i = 0; i < tokens_to_mint.length; i++) {
            require(tokens_to_mint[i]<=MAX_AC_SUPPLY);
            _safeMint(msg.sender, tokens_to_mint[i]);
            AC_MINT_COUNT +=1;
            _AC_claimed[tokens_to_mint[i]] = true;

            
            
        }


    }
    
    
    // mint Collectos Edition by the owner of the corresponding AutoChroma holder
    function mint_COL_from_AC(uint256[] calldata tokens_to_mint)
        internal
    {

        for (uint256 i = 0; i < tokens_to_mint.length; i++) {
            require((MAX_AC_SUPPLY+MAX_REG_SUPPLY+tokens_to_mint[i])<=(MAX_AC_SUPPLY+MAX_REG_SUPPLY+MAX_AC_SUPPLY));
            _safeMint(msg.sender, MAX_AC_SUPPLY+MAX_REG_SUPPLY+tokens_to_mint[i]);        
            
        }


    }
    
    
    function mintACownerMorph(uint256[] calldata tokens_to_mint)
        public
        payable
        validatePurchasePrice(tokens_to_mint.length)
    {
        
        require(ACsaleIsActive, "Sale has not started yet");
        require(_AC_open_to_public || ownsAllACs(tokens_to_mint));


        mint_CM_from_AC(tokens_to_mint);
    }
    
    function mintCOLLECTORStokenr(uint256[] calldata tokens_to_mint)
        public
    {
        
        require(ACsaleIsActive, "Sale has not started yet");
        require(ownsAllACs(tokens_to_mint));


        mint_COL_from_AC(tokens_to_mint);
    }
    

    function mintMorphs(uint256 numberOfTokens)
        public
        payable
        REGmintCountMeetsSupply(numberOfTokens)
        doesNotExceedMaxPurchaseCount(numberOfTokens)
        validatePurchasePrice(numberOfTokens)
    {
        require(saleIsActive, "Sale has not started yet");
        require((balanceOf(msg.sender) + numberOfTokens) <= _maxPurchaseCount, "This mint would put you above the sale limit of mints per account");


        _mintREGTokens(numberOfTokens, msg.sender);
    }
    
    
    // function mintTokensCOL(uint256 numberOfTokens)
    //     public
    //     payable
    //     COLmintCountMeetsSupply(numberOfTokens)
    //     doesNotExceedMaxPurchaseCount(numberOfTokens)
    //     validatePurchasePrice(numberOfTokens)
    // {
    //     require(saleIsActive, "Sale has not started yet");
    //     require((balanceOf(msg.sender) + numberOfTokens) <= _maxPurchaseCount, "This mint would put you above the sale limit of mints per account");


    //     _mintREGTokens(numberOfTokens, msg.sender);
    // }
    



    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}