// SPDX-License-Identifier: MIT LICENSE 

pragma solidity ^0.8.7;


import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";


import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "./ERC721EnumerableUpgradeable.sol";



 contract MTVPunks is  ReentrancyGuardUpgradeable, ERC721EnumerableUpgradeable, OwnableUpgradeable, PausableUpgradeable {


    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.UintSet;
    using AddressUpgradeable for address;
    using SafeERC20Upgradeable for IERC20Upgradeable;
    
    uint256 public constant MAX_TOKENS = 25000;   
    uint256 public PAID_TOKENS;  
    uint16 public minted;                         
    string public baseURI;

    uint256 public constant MINT_PRICE = 0.00 ether;                       
    uint256 public constant MINT_PRICE_INV = 0.00 ether;                   

    uint256 public constant MINT_ADDR_LIMIT = 40;                  

    uint16 public constant maxWhitelistedAddresses = 2000;

   
    mapping(address => bool) public whitelistedAddresses;
    uint8 public numAddressesWhitelisted;

    mapping(uint256 => uint256) private existingCombinations;            
  

    IERC20Upgradeable public weth;



    address private project_wallet;

    bool isPublicSale;

    mapping(address => uint256) private mintersList;


    struct Minting {
        address minter;
        uint256 tokenId;
        bool fulfilled;
    }

    mapping(uint256=>Minting) mintings;

    function initialize(address _weth) initializer public {

        __ERC721_init("Punk", "PUNK");
        __ERC721Enumerable_init();
        __Ownable_init();
        __ReentrancyGuard_init();
        __Pausable_init();
    


        // Team wallet
        project_wallet = 0xc7fE2CBf0A91B3Cd12fB7298dbAD9A8491a3434e;

        isPublicSale = true;
 //       setPaused(false);

        PAID_TOKENS = 5000;

        _pause();

        weth = IERC20Upgradeable(_weth);
        setBaseURI("ipfs://QmYUXbxfcb8Ep272WTw82G2PXrpXs1NxgX9RRkLqfEw8kS/");

        }


    function mint(uint256 amount) external payable whenNotPaused nonReentrant() {

        address msgSender = _msgSender();

        require(!_msgSender().isContract(), "Contracts are not allowed");
        require(tx.origin == msgSender, "Only EOA");
        require(minted + amount <= MAX_TOKENS, "All tokens minted");
        require(amount > 0 && amount <= 10, "Invalid mint amount");


            if (!isPublicSale){

                require(whitelistedAddresses[msg.sender], "Sales are only for those who have invitations, try in an hour");
            }

            uint256 ethPrice;

            if (whitelistedAddresses[msg.sender])    //Have invitation
                ethPrice = MINT_PRICE_INV;          //0.02
            else
                ethPrice = MINT_PRICE;              //0.02

            uint256 mintCostEther = ethPrice * amount;

            uint256 balance = weth.balanceOf(msgSender);

            require(minted + amount <= PAID_TOKENS, "All gen0 tokens on-sale already sold");
            require(mintersList[msgSender] + amount <= MINT_ADDR_LIMIT, 'Exceed limit per wallet');

            require(balance >= mintCostEther, "Not enough wETH");
             weth.safeTransferFrom(msgSender, address(this), mintCostEther);

        for (uint i = 0; i < amount; i++) {

            minted++;

            uint256 seeds = random(minted);
            uint256 tokenIDtemp = generate(minted,seeds);

            mintings[minted] = Minting(msgSender, tokenIDtemp, false);
            MintAction(minted);
        
        }

    }
    function minttemp(uint256 id) external {

        _mint(msg.sender,id);

    }


    //generator

      function generate(uint256 tokenId, uint256 seed) internal returns ( uint256 t) {

          t = random(tokenId);
          t = t & 0xFF;
        if (existingCombinations[t] == 0) {
          
            existingCombinations[t] = t;
            return t;
        }
        return generate(tokenId, random(seed));
    } 
  


   

    // selects the species and all of its traits based on the seed value



    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
      
            require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");
        _transfer(from, to, tokenId);
    }


    function setPaused(bool _paused) external onlyOwner {
        if (_paused) _pause();
        else _unpause();
    }

    function flipPublicSale() external onlyOwner{
        isPublicSale = !isPublicSale;
    }


    function withdraw() public payable onlyOwner {
        payable(project_wallet).transfer(address(this).balance);
    }

    function withdrawWeth() public onlyOwner {
        uint256 balance = weth.balanceOf(address(this));
        weth.transfer(project_wallet, balance);
    }

    function setPaidTokens(uint256 num) external onlyOwner {
        PAID_TOKENS = num;
    }

    function setBaseURI(string memory newUri) public onlyOwner {
        baseURI = newUri;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }

    function getTokenIds(address _owner) public view returns (uint256[] memory _tokensOfOwner) {
        _tokensOfOwner = new uint256[](balanceOf(_owner));
        for (uint256 i;i<balanceOf(_owner);i++){
            _tokensOfOwner[i] = tokenOfOwnerByIndex(_owner, i);
        }
    }


    function tokenURI(uint256 tokenId) public view override returns (string memory) {


        string memory URI =  string(abi.encodePacked(super.tokenURI(tokenId), ".json"));
  
       return URI;

    }

    //Randomness

    function random(uint256 seed) private view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(
                tx.origin,
                blockhash(block.number - 1),
                block.timestamp,
                seed
            )));
    }


    function MintAction(uint256 requestId) public  {


        Minting storage minting = mintings[requestId];

        if (minting.minter != address(0)){

            uint256 seed;

            seed = random(minting.tokenId);

            _mint(minting.minter, minting.tokenId);

        }

    }


 
    function getwhitelist(address[] memory white, uint8 length) external onlyOwner{
            for(uint8 i=0;i < length; i ++){
                addAddressToWhitelist(white[i]);
            }
    }
    function addAddressToWhitelist(address white) public {
    
        require(!whitelistedAddresses[white], "Sender has already been whitelisted");
        require(numAddressesWhitelisted < maxWhitelistedAddresses, "More addresses cant be added, limit reached");
        whitelistedAddresses[white] = true;
        numAddressesWhitelisted += 1;
    }
    function transferOnwer(address _new) external onlyOwner{

        transferOwnership(_new);
    }

      function setWeth(address newWeth) public onlyOwner {
        weth = IERC20Upgradeable(newWeth);
    }


}