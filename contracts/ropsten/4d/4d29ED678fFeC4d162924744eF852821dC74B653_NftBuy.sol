//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
interface IERC20 {
    function totalsupply() external view returns (uint256);


    event transfers(address indexed from, address indexed to, uint256 value);
}
contract OurToken is IERC20{
  //  event Transfer(address indexed from, address indexed to, uint256 value);
  
   mapping(address => uint256)public balances;
   address public owner;
    uint256 public totalSupply = 1000;
    
   constructor(){
   balances[msg.sender] = totalSupply; 
   
   }
   function totalsupply() public view override returns (uint256) {
        return  totalSupply;
    }
     function balanceoof(address tokenowner)
        public
        view
        returns (uint256)
    {
        return balances[tokenowner];
    }
     function transferable(address reciver, uint256 numOfToken,address sender)
        public
        
        returns (bool)
    {
        // sender should have transferable amount of token
        //require(numOfToken <= balances[msg.sender],"you not have enough token"); 
        balances[sender] -= numOfToken;
        balances[reciver] += numOfToken;
        emit transfers(sender, reciver, numOfToken);
        return true;
    }

}
contract NftBuy is ERC721{
 using Counters for Counters.Counter;
 Counters.Counter public _tokenIds;
 address  public seller;
 address  public buyer;
 mapping(address=> bool) public  allowed;
 mapping(uint256 => string) _tokenURIs;
 mapping(uint=>address) assosciate;
 mapping (uint256=>uint256) price ;
 address public tokenAddress;
 address public own;
   constructor(address _contract)  ERC721("Selling", "OurToken") {
        own=msg.sender;
       tokenAddress =_contract;
    
    }
    function mint(string memory uri,uint256 _price ) public returns(uint256)
   {
   //  require(allowed[msg.sender]==true,"you are not allowed for mint");
        uint256 newId = _tokenIds.current();
        _mint(msg.sender,newId);
        _setTokenURI(newId,uri);
        _tokenIds.increment;
        price[newId]=_price ;
        assosciate[newId]=msg.sender;
        return newId;
   }
    function _setTokenURI(uint256 tokenId, string memory _tokenURI) internal {
        _tokenURIs[tokenId] = _tokenURI;
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        require(_exists(tokenId),"token id not exist");
        string memory _tokenURI = _tokenURIs[tokenId];
        return _tokenURI;
    }
    function buy(uint256 _tokenid)payable  public  returns(bool){
         OurToken tok=OurToken(tokenAddress); 
        require(price[_tokenid]!=0,"item not exist");
         uint256 paytoken=tok.balanceoof(msg.sender);
        require(paytoken>price[_tokenid],"you not have enoug tokens");
         _transfer(assosciate[_tokenid], msg.sender, _tokenid);
        tok.transferable(assosciate[_tokenid],price[_tokenid] ,msg.sender );
          assosciate[_tokenid]=msg.sender;
          return true;
    }

}