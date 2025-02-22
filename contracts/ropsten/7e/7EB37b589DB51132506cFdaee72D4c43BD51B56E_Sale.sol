// SPDX-License-Identifier:MIT
pragma solidity >=0.5.0 <0.8.0;

import "./libs/SafeMathCustom.sol";
import "./libs/Ownable.sol";

interface Nftn721 {
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);
    function balanceOf(address owner) external view returns (uint256 balance);    
    function tokenTransfer(address from, address to, uint256 tokenId) external;
    function _mint(address to, uint256 tokenId, string memory uri) external;
    function setApprovalForAll(address from, address to, bool approved, uint256 tokenId) external ;
    function _burn(uint256 tokenId, address from) external;
    function _transferOwnership(address newOwner) external;
}

interface Nftn1155{
   
    event TransferSingle(address indexed _operator, address indexed _from, address indexed _to, uint256 _id, uint256 _value);
    event ApprovalForAll(address indexed _owner, address indexed _operator, bool _approved);
    event URI(string _value, uint256 indexed _id);

    function safeTransferFrom(address _from, address _to, uint256 _id, uint256 _value) external;

    function balanceOf(address _owner, uint256 _id) external view returns (uint256);

    function setApprovalForAll(address from, address _operator, bool _approved) external;
    function isApprovedForAll(address _owner, address _operator) external view returns (bool);
    function mint(address from, uint256 _id, uint256 _supply, string memory _uri) external;
    function burn(address from, uint256 _id, uint256 _value) external ;
    function _transferOwnership(address newOwner) external;
}

interface BEP20 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

contract Sale is Ownable{
    event CancelOrder(address indexed from, uint256 indexed tokenId);
    event ChangePrice(address indexed from, uint256 indexed tokenId, uint256 indexed value);
    event OrderPlace(address indexed from, uint256 indexed tokenId, uint256 indexed value);
    event FeeDetails(uint256 indexed owner, uint256 indexed admin, uint256 indexed admin2);
    event Calcu(uint256 indexed owner, uint256 indexed admin, uint256 indexed admin2);
    event FeeDiv(uint256 indexed owner, uint256 indexed admin, uint256 indexed admin2);
    using SafeMathCustom for uint256;
    
    struct Order{
        uint256 tokenId;
        uint256 price;
    }
     struct Royalty{    
        uint256 tokenId;    
        address[] royaltyaddress;   
        uint[] percentage;  
        uint royaltypercentage; 
    }   
    uint public totalroyalty = 0;   
    address public ownerWallet; 
    uint256 public serviceValue;  
    mapping (uint256 => uint256) public totalQuantity;
    mapping (uint256 => Royalty) public RoyaltyInfo;
    // From address => tokenId => Order;
    mapping (address => mapping (uint256 => Order)) public order_place;
    // From tokenId => address => Order;
    mapping (uint256 => mapping (address => bool)) public checkOrder;
    mapping (uint256 =>  bool) public _operatorApprovals;
    mapping (uint256 => address) public _creator;
    mapping (uint256 => uint256) public _royal; 
    mapping (uint256 => mapping(address => uint256)) public balances;
    constructor(uint256 _serviceValue) {
        serviceValue = _serviceValue;
    }
    function _orderPlace(address from, uint256 tokenId, uint256 _price) internal{
        require( balances[tokenId][from] > 0, "Is Not a Owner");
        Order memory order;
        order.tokenId = tokenId;
        order.price = _price;
        order_place[from][tokenId] = order;
        checkOrder[tokenId][from] = true;
        emit OrderPlace(from, tokenId, _price);
    }
    function _cancelOrder(address from, uint256 tokenId) internal{
        require(balances[tokenId][msg.sender] > 0, "Is Not a Owner");
        delete order_place[msg.sender][tokenId];
        checkOrder[tokenId][from] = false;
        emit CancelOrder(msg.sender, tokenId);
    }
    function _changePrice(uint256 value, uint256 tokenId) internal{
        require( balances[tokenId][msg.sender] > 0, "Is Not a Owner");
        require( value < order_place[msg.sender][tokenId].price);
        order_place[msg.sender][tokenId].price = value;
        emit ChangePrice(msg.sender, tokenId, value);
    }
    function _acceptBId(address token,address from, address admin,  uint tokenprice, uint256 tokenId) internal{
        require(_operatorApprovals[tokenId], "Token Not approved");
        require(balances[tokenId][msg.sender] > 0, "Is Not a Owner");
        (uint256 _adminfee, uint256 netamount) = calc(tokenprice, totalroyalty, serviceValue);
        BEP20 t = BEP20(token);
         uint256 totalFee = _adminfee.mul(2);
        t.transferFrom(from,admin,totalFee);
       // uint256 totalPrice = tokenprice.sub(_adminfee);
        payforRoyaltyToken(tokenprice, tokenId,from, token);
        t.transferFrom(from,msg.sender,netamount);
    }
    function checkTokenApproval(uint256 tokenId, address from) internal view returns (bool result){
        require(checkOrder[tokenId][from], "This Token Not for Sale");
        require(_operatorApprovals[tokenId], "Token Not approved");
        return true;
    }
    function _saleToken(address payable from, address payable admin,uint256 tokenId, uint256 amount , uint256 tokenprice) internal{
        require(amount> order_place[from][tokenId].price , "Insufficent found");
        require(checkTokenApproval(tokenId, from));
       // address payable create = address(uint160(_creator[tokenId]));
       (uint256 _adminfee, uint256 netamount) = calc(tokenprice, totalroyalty, serviceValue);
       uint256 totalFee = _adminfee.mul(2);
        admin.transfer(totalFee);
        //uint256 totalPrice = tokenprice.sub(_adminfee);
        payforRoyalty(tokenprice, tokenId);
        from.transfer(netamount);
    }
     function payforRoyalty(uint originalamount, uint tokenId) internal {   
            
        for(uint i=0;i<RoyaltyInfo[tokenId].royaltyaddress.length;i++){ 
             address payable payAddress = address(uint160(RoyaltyInfo[tokenId].royaltyaddress[i])); 
             uint256 roy = originalamount.mul(RoyaltyInfo[tokenId].percentage[i]).div(1000000); 
             payAddress.transfer(roy);  
        }   
            
    }
     function payforRoyaltyToken(uint originalamount, uint tokenId, address from, address token) internal {   
        
        BEP20 trnasferToken = BEP20(token);

        for(uint i=0;i<RoyaltyInfo[tokenId].royaltyaddress.length;i++){ 
             address payable payAddress = address(uint160(RoyaltyInfo[tokenId].royaltyaddress[i])); 
             uint256 roy = originalamount.mul(RoyaltyInfo[tokenId].percentage[i]).div(1000000); 
             trnasferToken.transferFrom(from,payAddress,roy);
        }   
            
    }
    function calc(uint256 tokenprice, uint256 royal, uint256 _serviceValue) internal pure returns(uint256, uint256){
        uint256 fee = percent(tokenprice, _serviceValue.div(10));
        uint256 roy = percent(tokenprice, royal);
        uint256 netamount = tokenprice.sub(roy);
        uint256 netamountlast = netamount.sub(fee);
        return (fee, netamountlast);
    }

    function percent(uint256 value1, uint256 value2) internal pure returns(uint256){
        uint256 result = value1.mul(value2).div(100);
        return(result);
    }
    function setServiceValue(uint256 _serviceValue) internal{
        serviceValue = _serviceValue;
    }


}

contract ExchangeContract is Sale{
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