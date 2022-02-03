//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.11;

import '@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721BurnableUpgradeable.sol";
/** Upgradeable Libraries */
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";

contract Avatar is 
    Initializable,
    ERC721Upgradeable,
    ERC721BurnableUpgradeable,
    AccessControlUpgradeable,
    OwnableUpgradeable

{
    using StringsUpgradeable for string;
    using StringsUpgradeable for uint256;
    using SafeMathUpgradeable for uint256;
    using SafeMathUpgradeable for uint8;

    using CountersUpgradeable for CountersUpgradeable.Counter;

    CountersUpgradeable.Counter public _tokenIDTracker;


    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    uint256 public _MAX_NUM_TOKENS;
    uint256 public _TOKEN_PRICE;
    uint256 public _MAX_NUM_TOKENS_PER_MINT;

    string public _BASE_URI;

    bool public _PUBLIC_MINTING_ENABLED; //checks if admin has given permission of public mint


    function Initialize(string memory name, string memory symbol, string memory _baseURI) 
        public initializer{
            ERC721Upgradeable.__ERC721_init(name, symbol);
            __AccessControl_init();
            __ERC721Burnable_init();
            __Ownable_init();

            _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
            _grantRole(ADMIN_ROLE,msg.sender);
            _grantRole(MINTER_ROLE,msg.sender);


            _MAX_NUM_TOKENS = 10000;
            _MAX_NUM_TOKENS_PER_MINT = 10;

            _TOKEN_PRICE = 5e16; //0.05 ETH
            _BASE_URI = _baseURI;
            _PUBLIC_MINTING_ENABLED = false;
    }
/**Event to be called everytime a token is minted */
    event tokenMinted(address from, address to, uint256 tokenID);

/**Modifier to check if the number of tokens to be minted are not 0 and less than 10 */
    modifier mintingValidation(uint8 count) {
        require(count > 0, "Minimum Token Minted should be 1");
        require(
            count <= _MAX_NUM_TOKENS_PER_MINT,
            "Too many number of tokens to mint in one transaction"
        );
        _;
    }

    
/**Function to Enable or disable Public minting */
    function adminUpdatePublicMinting( bool updateValue) external 
    onlyRole(ADMIN_ROLE) {
        _PUBLIC_MINTING_ENABLED = updateValue;
    }

/**functioon to change BaseURI */
    function adminUpdateBaseURI(string memory _baseURI) external
    onlyRole(ADMIN_ROLE){
        _BASE_URI = _baseURI;
    }
/**Change Token Price by admin */
    function adminUpdateTokenPrice(uint256 newPrice) external 
    onlyRole(ADMIN_ROLE){
       
        _TOKEN_PRICE = newPrice;
   
    }
/**change Max number of tokens that can be minted only by admin*/
    function adminUpdateMaxNumToken(uint256 newValue) external 
    onlyRole(ADMIN_ROLE){
        _MAX_NUM_TOKENS = newValue;
    }
/**function to change number of tokens to be minted in single transaction only by admin */
    function adminUpdateMaxNumTokenPerMint(uint256 newValue) external 
    onlyRole(ADMIN_ROLE){
        _MAX_NUM_TOKENS_PER_MINT = newValue;
    }

    function getCostOfMinting(uint count) public view returns(uint256){
        
        return _TOKEN_PRICE.mul(count);
    
    }

/**This Function returns the current number of remaining tokens to be minted */
    function remainingNumOfTokens() public view returns(uint256){
        
        return _MAX_NUM_TOKENS.sub(_tokenIDTracker.current());
    
    }

/**function to do minting by users with specific amount of Ethers its a payable function */ 
    function publicMinting(address _to, uint8 _count) external 
    mintingValidation(_count)
    onlyRole(MINTER_ROLE) 
    payable
    {
        require( _PUBLIC_MINTING_ENABLED, "Public Minting is not enabled" );
        require( getCostOfMinting(_count) == msg.value, "Not enough Ether to mint Tokens");
        require( remainingNumOfTokens() >= _count, " Token Mint Limit Reached " );

        for(uint8 i = 0; i < _count; i++){
            _mintSingleToken(address(msg.sender), address(_to));
        }
    }
/**functiont to allow admin to mint tokens */
    function adminMinting( address _to, uint8 _count) external
    mintingValidation(_count)
    onlyRole(ADMIN_ROLE)  {
        
        require( remainingNumOfTokens() >= _count, " Token Mint Limit Reached " );

        for(uint8 i = 0; i < _count; i++){
            _mintSingleToken(address(msg.sender), address(_to));
        }

    }

/**Function to mint a single token  */

    function _mintSingleToken(
        address from,
        address to
    ) private {
        
        _tokenIDTracker.increment();

        _safeMint(to, _tokenIDTracker.current());

       emit tokenMinted(from, to, _tokenIDTracker.current());

    }

/**Function returns baseURI */
    function baseURI() public view returns(string memory) {
        return _BASE_URI;
    }

/**Fucntion returns tokenURI */
    function tokenURI(uint256 _tokenID) public 
    view 
    override(ERC721Upgradeable) 
    returns(string memory){
        
        require(_exists(_tokenID), "Avatar: query for non existent tokenID");

        return( string(abi.encodePacked(_BASE_URI,_tokenID.toString())));
    }
/**Override function from different upgradeable contracts */

    function supportsInterface(bytes4 interfaceId)public view 
        override(ERC721Upgradeable,AccessControlUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}