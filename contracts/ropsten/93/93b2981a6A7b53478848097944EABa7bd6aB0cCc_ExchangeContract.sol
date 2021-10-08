// SPDX-License-Identifier:MIT
pragma solidity >=0.5.0 <0.8.0;

import "./Sale.sol";
import "./interfaces/Nftn721.sol";
import "./interfaces/Nftn1155.sol";

contract ExchangeContract is Sale {
    uint256 public tokenCount;
    using SafeMathCustom for uint256;

    constructor(uint256 _serviceValue) Sale(_serviceValue) { }

    function serviceFunction(uint256 _serviceValue) public onlyOwner{
        setServiceValue(_serviceValue);
    }

    function transferOwnershipForColle(address newOwner, address token721, address token1155) public onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        Nftn721 tok= Nftn721(token721);
        Nftn1155 tok1155= Nftn1155(token1155);
        tok._transferOwnership(newOwner);
        tok1155._transferOwnership(newOwner);
    }

    function mint(address token ,string memory tokenuri, uint256 value, uint256 tokenId, uint256 _type, uint256 supply, address[] memory royaltyaddr, uint256[] memory royaltypercentage) public{
       require(_creator[tokenId] == address(0), "Token Already Minted");
          require(royaltyaddr.length > 0 && royaltypercentage.length > 0 && royaltyaddr.length ==royaltypercentage.length, 'Invalid royalty list'); 
            
        uint256 checkPercentage;
        for(uint c=0;c<royaltypercentage.length;c++){
        uint256 Percentage = royaltypercentage[c];
        checkPercentage +=Percentage;
        }   
        require(((checkPercentage)/10000)==totalroyalty, 'Invalid royalty percentage');   
        Royalty memory royalty; 
        royalty = Royalty({ 
            tokenId: tokenId,   
            royaltypercentage:totalroyalty, 
            royaltyaddress : new address[](0),  
            percentage:new uint256[](0)    
        }); 
        RoyaltyInfo[tokenId] = royalty; 
        for(uint i = 0; i < royaltyaddr.length; i++) {  
            RoyaltyInfo[tokenId].royaltyaddress.push(royaltyaddr[i]);   
            RoyaltyInfo[tokenId].percentage.push(royaltypercentage[i]); 
        }   
       
       if(_type == 721){
           Nftn721 tok= Nftn721(token);
           _creator[tokenId]=msg.sender;
           tok._mint(msg.sender, tokenId, tokenuri);
           balances[tokenId][msg.sender] = supply;
           if(value != 0){
                _orderPlace(msg.sender, tokenId, value);
            }
        }
        else{
            Nftn1155 tok = Nftn1155(token);
            tok.mint(msg.sender, tokenId, supply, tokenuri);
            _creator[tokenId]=msg.sender;
            balances[tokenId][msg.sender] = supply;
            if(value != 0){
                _orderPlace(msg.sender, tokenId, value);
            }
       }
       totalQuantity[tokenId] = supply;
       tokenCount++;
       
    }

    function setApprovalForAll(address token, uint256 _type, bool approved, uint256 tokenId) public {
        _operatorApprovals[tokenId] = true;
        if(_type == 721){
            Nftn721 tok= Nftn721(token);
            tok.setApprovalForAll(msg.sender, address(this),approved,tokenId);
        }
        else{
            Nftn1155 tok = Nftn1155(token);
            tok.setApprovalForAll(msg.sender, address(this), approved);
        }
    }

    function saleToken(address payable from, address payable admin,uint256 tokenId, uint256 amount,uint256 tokenprice, address token, uint256 _type, uint256 NOFToken) public payable{
       _saleToken(from, admin, tokenId, amount, tokenprice);
       if(_type == 721){
           Nftn721 tok= Nftn721(token);
            if(checkOrder[tokenId][from]==true){
                delete order_place[from][tokenId];
                checkOrder[tokenId][from] = false;
            }
           tok.tokenTransfer(from, msg.sender, tokenId);
           balances[tokenId][from] = balances[tokenId][from] - NOFToken;
           balances[tokenId][msg.sender] = NOFToken;
       }
       else{
            Nftn1155 tok= Nftn1155(token);
            tok.safeTransferFrom(from, msg.sender, tokenId, NOFToken);
            balances[tokenId][from] = balances[tokenId][from] - NOFToken;
            balances[tokenId][msg.sender] = balances[tokenId][msg.sender] + NOFToken;
            if(checkOrder[tokenId][from] == true){
                if(balances[tokenId][from] == 0){
                    delete order_place[from][tokenId];
                    checkOrder[tokenId][from] = false;
                }
            }
            
       }
        

    }

    function acceptBId(address bittoken,address from, address admin, uint256 tokenprice, uint256 tokenId, address token, uint256 _type, uint256 NOFToken) public{
        _acceptBId(bittoken, from, admin, tokenprice, tokenId);
        if(_type == 721){
           Nftn721 tok= Nftn721(token);
           if(checkOrder[tokenId][msg.sender]==true){
                delete order_place[msg.sender][tokenId];
                checkOrder[tokenId][msg.sender] = false;
           }
           tok.tokenTransfer(msg.sender, from, tokenId);
           balances[tokenId][msg.sender] = balances[tokenId][msg.sender] - NOFToken;
           balances[tokenId][from] = NOFToken;
        }
        else{
            Nftn1155 tok= Nftn1155(token);
            tok.safeTransferFrom(msg.sender, from, tokenId, NOFToken);
            balances[tokenId][from] = balances[tokenId][from] + NOFToken;
            balances[tokenId][msg.sender] = balances[tokenId][msg.sender] - NOFToken;
            if(checkOrder[tokenId][msg.sender] == true){
                if(balances[tokenId][msg.sender] == 0){   
                    delete order_place[msg.sender][tokenId];
                    checkOrder[tokenId][msg.sender] = false;
                }
            }

        }
    }

    function orderPlace(uint256 tokenId, uint256 _price) public{
        _orderPlace(msg.sender, tokenId, _price);
    }

    function cancelOrder(uint256 tokenId) public{
        _cancelOrder(msg.sender, tokenId);
    }

    function changePrice(uint256 value, uint256 tokenId) public{
        _changePrice(value, tokenId);
    }

    function changeroyaltypercentage(uint256 percentage) external onlyOwner {
        totalroyalty =percentage;   
    }

    function Royaltyaddress(uint tokenId) public view returns(address[5] memory List) { 
         for (uint i = 0; i<RoyaltyInfo[tokenId].royaltyaddress.length; i++) {  
            List[i] =RoyaltyInfo[tokenId].royaltyaddress[i];    
         }  
    }

    function Royaltypercentage(uint tokenId) public view returns(uint[5] memory List) { 
         for (uint i = 0; i<RoyaltyInfo[tokenId].royaltyaddress.length; i++) {  
            List[i] =RoyaltyInfo[tokenId].percentage[i];    
         }  
    }

    function burn(address from, uint256 tokenId, address token, uint256 _type, uint256 NOFToken ) public{
        require( balances[tokenId][msg.sender] >= NOFToken || msg.sender == owner(), "Your Not a Token Owner or insuficient Token Balance");
        require( balances[tokenId][from] >= NOFToken, "Your Not a Token Owner or insuficient Token Balance");
        require( _operatorApprovals[tokenId], "Token Not approved");
        if(_type == 721){
            Nftn721 tok= Nftn721(token);
            tok._burn(tokenId, from);
            balances[tokenId][from] = balances[tokenId][from].sub(NOFToken);
            if(checkOrder[tokenId][from]==true){
                delete order_place[from][tokenId];
                checkOrder[tokenId][from] = false;
            }
        }
        else{
            Nftn1155 tok= Nftn1155(token);
            tok.burn(from, tokenId, NOFToken);
            if(balances[tokenId][from] == NOFToken){
                if(checkOrder[tokenId][from]==true){
                    delete order_place[from][tokenId];
                    checkOrder[tokenId][from] = false;
                }
               
            }
            balances[tokenId][from] = balances[tokenId][from].sub(NOFToken);

        }
        if(totalQuantity[tokenId] == NOFToken){
             _operatorApprovals[tokenId] = false;
             delete _creator[tokenId];
             delete _royal[tokenId];
        }
        totalQuantity[tokenId] = totalQuantity[tokenId].sub(NOFToken);

    }
}