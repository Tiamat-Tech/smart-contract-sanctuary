// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;
pragma experimental ABIEncoderV2;
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/payment/PaymentSplitter.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

contract Token is ERC721, Ownable, PaymentSplitter, Pausable {
    
    using SafeMath for uint256;
    using Counters for Counters.Counter;

    string private _baseApi;

    uint256 private constant _tokenPrice = 25000000000000000; // 0.025 ETH

    uint256 private constant _maxTokenPurchase = 20;

    uint256 public constant MAX_TOKENS = 8888;

    bool public saleIsActive = false;
    
    mapping(uint256 => uint256) public _totalSupply;
    Counters.Counter private _IdCounter;
    
    // Reserve 125 Tokens for team - Giveaways/Prizes etc
    uint public tokenReserve = 125;

    address[] private _team = [
	0xe20637FC210397C5742cBEF523E530F10086AE30, // 20
	0x2eeae9Fc6B7D805637c76F7489CE8CE9c8Fd10F2, // 15
	0xa7EEABD32775eE917F62aF113BA54D997CA7bAf2, // 15
	0xe754ae30F35Fd2193D0Bc04E2236129B066C1075, // 15
	0x31b5a9d4C73a55450625C7ee28E77EFef419406e, // 15
	0xac6881eaD6b4b11b07DeD96f07b1a2FFed6b9Fe6, // 10
	0xf49F0F3B364d3512A967Da5B1Cc41563cd60771d  // 10
    ];

    uint256[] private _team_shares = [20,15,15,15,15,10,10];
    
  //  event tokenNameChange(address _by, uint _tokenId, string _name);
    

    constructor() 
       ERC721("Token", "TKN") 
       PaymentSplitter(_team, _team_shares)
    { 

    }


    
    function reserveTokens(address _to, uint256 _reserveAmount) public onlyOwner {        
        uint supply = totalSupply();
        require(_reserveAmount > 0 && _reserveAmount <= tokenReserve, "Not enough reserve left for team");
        for (uint i = 0; i < _reserveAmount; i++) {
            _safeMint(_to, supply + i);
        }
        tokenReserve = tokenReserve.sub(_reserveAmount);
    }


    // function setProvenanceHash(string memory provenanceHash) public onlyOwner {
    //     TOKEN_PROVENANCE = provenanceHash;
    // }

    function setBaseURI(string memory _baseUri) public onlyOwner {
        _baseApi = _baseUri;
    }


    function flipSaleState() public onlyOwner {
        saleIsActive = !saleIsActive;
    }
    
    
    function tokensOfOwner(address _owner) external view returns(uint256[] memory ) {
        uint256 tokenCount = balanceOf(_owner);
        if (tokenCount == 0) {
            // Return an empty array
            return new uint256[](0);
        } else {
            uint256[] memory result = new uint256[](tokenCount);
            uint256 index;
            for (index = 0; index < tokenCount; index++) {
                result[index] = tokenOfOwnerByIndex(_owner, index);
            }
            return result;
        }
    }
    
    
    
    function mintToken(uint numberOfTokens) public payable {
        require(saleIsActive, "Sale must be active to mint Token");
        require(numberOfTokens > 0 && numberOfTokens <= _maxTokenPurchase, "Can only mint 20 tokens at a time");
        require(_IdCounter.current().add(numberOfTokens) <= MAX_TOKENS, "Purchase would exceed max supply of Tokens");
        require(msg.value >= _tokenPrice.mul(numberOfTokens), "Ether value sent is not correct");
        
        for(uint256 i = 0; i < numberOfTokens; i++) {
           mint();
        }

    }

    function mint() private {
        _safeMint(msg.sender, _IdCounter.current() + 1);
        _IdCounter.increment();
    }

    function getTotalSupply() public view virtual returns (uint256) {
        return _IdCounter.current();
    }

    function getTotalSupplyId(uint256 id) public view virtual returns (uint256) {
        return _totalSupply[id];
    }
     
    // function changeTokenName(uint _tokenId, string memory _name) public {
    //     require(ownerOf(_tokenId) == msg.sender, "Hey, your wallet doesn't own this token!");
    //     require(sha256(bytes(_name)) != sha256(bytes(tokenNames[_tokenId])), "New name is same as the current one");
    //     tokenNames[_tokenId] = _name;
        
    //     emit tokenNameChange(msg.sender, _tokenId, _name);
        
    // }
    
    // function viewTokenName(uint _tokenId) public view returns( string memory ){
    //     require( _tokenId < totalSupply(), "Choose a token within range" );
    //     return tokenNames[_tokenId];
    // }
    
    
    // // GET ALL TOKENS OF A WALLET AS AN ARRAY OF STRINGS. WOULD BE BETTER MAYBE IF IT RETURNED A STRUCT WITH ID-NAME MATCH
    // function tokenNamesOfOwner(address _owner) external view returns(string[] memory ) {
    //     uint256 tokenCount = balanceOf(_owner);
    //     if (tokenCount == 0) {
    //         // Return an empty array
    //         return new string[](0);
    //     } else {
    //         string[] memory result = new string[](tokenCount);
    //         uint256 index;
    //         for (index = 0; index < tokenCount; index++) {
    //             result[index] = tokenNames[ tokenOfOwnerByIndex(_owner, index) ] ;
    //         }
    //         return result;
    //     }
    // }
    
}