pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
 import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "./BlackholePrevention.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

 contract MirandusVOX is ERC721,ERC1155Holder,Ownable ,BlackholePrevention,ReentrancyGuard{
    using Address for address payable;
    uint256 public tokenId; 
    address public erc1155Token;
    uint256 public timePhase1;
   
    uint256 public balance;
    uint256 public erc1155TokenId;
    mapping(address => uint256) buyLimit;
    uint256 public limitNumber = 2; 
    uint256 public tokenPrice = 0.1888 ether;

   constructor( address _erc1155Token, uint256 _periodTimePhase1,uint256 _erc1155TokenId)   ERC721("Token", "tok") {
       erc1155Token = _erc1155Token;
       timePhase1 = block.timestamp + _periodTimePhase1;
       erc1155TokenId = _erc1155TokenId;
   }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721,ERC1155Receiver) returns (bool) {
        return interfaceId ==type(IERC1155Receiver).interfaceId ||
         interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC721Metadata).interfaceId ||
            super.supportsInterface(interfaceId);
    }
        
    function setLimitNumber(uint256 _limitNumber) public onlyOwner {
        require(_limitNumber>0, "");
            limitNumber = _limitNumber;
    }
    function setTimePhase1(uint256 _periodTimePhase1) public onlyOwner {
            timePhase1 = block.timestamp + _periodTimePhase1;    
        }
    //   function setTokenPrice(uint256 _tokenPrice) public onlyOwner {
    //         tokenPrice =   _tokenPrice ether;
    //     }
     function onERC1155Received(  
        address operator,
        address from,
        uint256 id,
        uint256 value,
        bytes calldata data
        ) public virtual override   returns (bytes4)  {
            require(block.timestamp < timePhase1,"time expired for buying with ERC1155");
            uint256 balanceAter= IERC1155(erc1155Token).balanceOf(address(this),erc1155TokenId);
            if(balance+value == balanceAter ) {
                 for (uint256 i = 0; i <value; i++) {
                    _safeMint(from, tokenId);
                    tokenId++;
                 }
            }
          balance =  IERC1155(erc1155Token).balanceOf(address(this),erc1155TokenId);
          return this.onERC1155Received.selector;
    }
     function onERC1155BatchReceived(  
        address operator,
        address from,
        uint256 [] memory id,
        uint256 [] memory value,
        bytes calldata data
        ) public virtual override   returns (bytes4)  {
            require(block.timestamp < timePhase1,"time expired for buying with ERC1155");
            uint256 totalValue;
            uint256 balanceAter= IERC1155(erc1155Token).balanceOf(address(this),erc1155TokenId);
            for(uint256 i = 0 ; i< id.length ; i++) {
                if(id[i] ==erc1155TokenId){
                    totalValue+= value[i];
                }  
            }
             if( balance+ totalValue == balanceAter){
                 for (uint256 i = 0; i <totalValue; i++) {
                    _safeMint(from, tokenId);
                    tokenId++;
                 }
                }
          balance =  IERC1155(erc1155Token).balanceOf(address(this),erc1155TokenId);
          return this.onERC1155BatchReceived.selector;
    }
    function buyTokenWithETH(uint256 amountToken) public nonReentrant payable{
        require(block.timestamp >=timePhase1,"not time for buying with ETH");
        require(buyLimit[msg.sender]<=limitNumber-1,"buying over limit");
        require(amountToken<= limitNumber- buyLimit[msg.sender], "!amountToken");
   
        uint256 EthAmount = tokenPrice * amountToken;
        require(msg.value >= EthAmount, "insufficient balance");
        uint256 left = msg.value - EthAmount;
        if(left>0){
        address payable receiver = payable(msg.sender);
        receiver.sendValue(left);
        }
       
        for( uint256 i = 0; i< amountToken; i++){
            _safeMint(msg.sender, tokenId);
            tokenId++;
            buyLimit[msg.sender]++;
        }
       
        
    }
   
    
    function withdrawEther(address payable receiver, uint256 amount)
        external
        virtual
        onlyOwner
    {
        _withdrawEther(receiver, amount);
    }

    function withdrawERC20(
        address payable receiver,
        address tokenAddress,
        uint256 amount
    ) external virtual onlyOwner {
        _withdrawERC20(receiver, tokenAddress, amount);
    }

    function withdrawERC721(
        address payable receiver,
        address tokenAddress,
        uint256 _tokenId
    ) external virtual onlyOwner {
        _withdrawERC721(receiver, tokenAddress, _tokenId);
    }
    function withdrawERC1155(
        address token,
        address _to,
        uint256 _erc1155TokenId,
        uint256 _amount,
        bytes memory data
    ) external virtual onlyOwner {
        _withdrawERC1155(token, _to, _erc1155TokenId,_amount,data);
    }

}