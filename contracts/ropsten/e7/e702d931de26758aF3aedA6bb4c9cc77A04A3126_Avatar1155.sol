//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.11;

import '@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol';
import '@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155BurnableUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';

import '@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol';
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";

import '@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155SupplyUpgradeable.sol';


contract Avatar1155 is
Initializable, 
ERC1155Upgradeable,
ERC1155BurnableUpgradeable,
ERC1155SupplyUpgradeable,
AccessControlUpgradeable,
OwnableUpgradeable,
UUPSUpgradeable
{
    using StringsUpgradeable for string;
    using StringsUpgradeable for uint256;
    using SafeMathUpgradeable for uint256;
    using SafeMathUpgradeable for uint8;

    using CountersUpgradeable for CountersUpgradeable.Counter;

    // mapping(string => uint256) public _collectionIDs;

    // CountersUpgradeable.Counter public collectionIDTracker;
    
    // mapping(uint256 => CountersUpgradeable.Counter) public collectionTokenIDTracker;

    CountersUpgradeable.Counter public _tokenIDTracker;

    
     
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    uint256 public _MAX_NUM_TOKENS;
    uint256 public _TOKEN_PRICE;
    uint256 public _MAX_NUM_TOKENS_PER_MINT;

    string public _BASE_URI;

    bool public _PUBLIC_MINTING_ENABLED;
    
    uint256 public constant AVATAR_NFT = 1;

    function initialize(string memory _baseURI) public initializer{
        _BASE_URI = _baseURI;
        ERC1155Upgradeable.__ERC1155_init(_BASE_URI);
        __ERC1155Supply_init();
        __AccessControl_init();
        __ERC1155Burnable_init();
        __UUPSUpgradeable_init();
        __Ownable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE,msg.sender);
        _grantRole(MINTER_ROLE,msg.sender);


        _MAX_NUM_TOKENS = 10000;
        _MAX_NUM_TOKENS_PER_MINT = 10;

        _TOKEN_PRICE = 5e16; //0.05 ETH
        
        _PUBLIC_MINTING_ENABLED = false;

    }
/**Event to be emited every time tokens are minted  */
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

/**UUPSUpgradeable function */
function _authorizeUpgrade(address newImplementation) internal 
override(UUPSUpgradeable)
onlyOwner()
{

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
    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal override(ERC1155Upgradeable,ERC1155SupplyUpgradeable) {
        ERC1155SupplyUpgradeable._beforeTokenTransfer(operator,from, to, ids, amounts, data);
    }

/**Function to mint a single token  */

    function _mintSingleToken(
        address from,
        address to
    ) private {
        
        _tokenIDTracker.increment();

        uint256 currentTokenID = _tokenIDTracker.current();
        uint256[] memory ids = new uint256[](1);
        uint256[] memory amount= new uint256[](1);
        ids[0] = currentTokenID;
        amount[0] = 1;
        _beforeTokenTransfer(from, address(0), to, ids, amount, "");
        _mint(to, currentTokenID, 1, "");
        

       emit tokenMinted(from, to, currentTokenID);

    }

/**Function returns baseURI */
    function baseURI() public view returns(string memory) {
        return _BASE_URI;
    }

/**Fucntion returns tokenURI */
    function tokenURI(uint256 _tokenID) public 
    view 
    returns(string memory){
        
        require(exists(_tokenID), "Avatar: query for non existent tokenID");

        return( string(abi.encodePacked(_BASE_URI,_tokenID.toString())));
    }
    /**Function override from ERC1155Upgradeable and AccessControlUpgradeable */
    function supportsInterface(bytes4 interfaceId)public view 
        override(ERC1155Upgradeable,AccessControlUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}