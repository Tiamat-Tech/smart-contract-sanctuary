/**
 *Submitted for verification at Etherscan.io on 2021-04-11
*/

pragma solidity 0.8.3;

contract VerifiedCompanies{
    address owner;
    constructor(){
      owner=msg.sender;
    }

    modifier onlyOwner(){ 
           require(msg.sender == owner);  
           _; 
    } 
  
    mapping (address=>bool) verifiedSellers;

    function addVerifiedCompany(address ofCompany) public onlyOwner{
      verifiedSellers[ofCompany]=true;
    }
    
    function deleteVerifiedCompany(address ofCompany) public onlyOwner{
      verifiedSellers[ofCompany]=false;
    }

    function IsCompanyVerified(address ofCompany) external view returns(bool isV){
     return(verifiedSellers[ofCompany]);
    }

}

contract Factory is VerifiedCompanies{

    uint256 public Companies;
    event CompanyCreated(address indexed owner, string name);

    modifier onlyVerified(){ 
            require(verifiedSellers[msg.sender]==true);  
            _; 
    } 
  
    function create_Company(string memory name) public onlyVerified returns(Company newContract)
      {
        Company c = new Company(name, msg.sender, address(this));
        emit CompanyCreated(msg.sender, name); 
        Companies+=1;
        return c;
     }

}

contract Company {

    address owner;
    address factory;
    string public company_name;
    
    event NewOrder(address indexed buyer, uint256 deadline);
    
    constructor(string memory name, address _owner, address _factory) public{
      owner=_owner;
      company_name=name;
      factory=_factory;
    }

    modifier onlyOwner(){ 
        require(msg.sender == owner);        
        _; 
    } 
  
    function create_Order(address payable buyer, uint256 stamp) public onlyOwner returns(Order newContract)
  { 
    VerifiedCompanies ver=VerifiedCompanies(factory);
    require((ver.IsCompanyVerified(msg.sender)==true),"Your company isn't verified");
    uint256 deadline=block.timestamp + stamp*1 minutes;
    emit NewOrder(buyer, deadline);
    Order c = new Order(buyer,deadline, msg.sender);
    return c;       
    }

}
  

contract Order {
    
address payable public seller; 
address payable public buyer; 

uint256 public allSum;                          
uint256 public time;
uint256 public changeTime;

bool buyerOK;

constructor(address payable _buyer, uint256 deadline, address _seller) public{ 
        buyer = _buyer; 
        seller = payable(seller);
        time=deadline;        
    } 
    
//////////////Модификаторы//////////////
    modifier onlyBuyer(){ 
        require(msg.sender == buyer);  
        _; 
    } 
  

    modifier onlySeller(){ 
        require(msg.sender == seller); 
        _; 
    } 
    
    modifier onlyBS(){ 
        require((msg.sender == seller)||(msg.sender == buyer)); 
        _; 
    } 
     

//////////////Основные функции//////////////

function setOK(bool bOk) private onlyBuyer {               // для соглашений - переправки селлеру и изменения временной метки
        buyerOK=bOk;
    }
    
function pay_to_Contract() onlyBuyer public payable{ 
        require(msg.value < (msg.sender).balance,
            "Not enough Ether provided."
        ); 
        allSum+=msg.value;
    } 
    

function deliver_from_Contract_to_Seller_All() onlyBS private{   
          require(address(this).balance>0,                                                 
            "Not enough ether provided."
        );
        if(msg.sender==buyer){
           seller.transfer(address(this).balance); 
        }
        
        else{

          if (block.timestamp>(time + 5 minutes)){
              seller.transfer(address(this).balance); 
          }

          else if ((buyerOK)==true){
          seller.transfer(address(this).balance); 
          buyerOK=false;
          }

          else {
          revert("No permission to transfer ether from contract.");
          }  

        }
          
    } 

function deliver_from_Contract_to_Seller_NotAll(uint256 percent) onlyBuyer private{   
          require(address(this).balance>0,                                                 
            "Not enough Ether provided."
        );
          uint summ=(address(this).balance)*percent/100;
          seller.transfer(summ); 

    } 
    

function return_payment() private { 
   uint bal=address(this).balance;

       require(bal>0,
            "Not enough Ether provided."
        );

          if (msg.sender==seller){
              buyer.transfer(bal);
              allSum-=bal;
        }
          else if (block.timestamp>(time+14 days)){
              buyer.transfer(bal);
              allSum-=bal;
          }
    }  
    
//////////////Дополнительные//////////////

function change(uint256 extraDays) private onlyBuyer {               // для изменения переменной
        changeTime=extraDays;
    }   

function changeStamp(uint256 extraDays) onlySeller private {    //изменение временного штампа - необходимо согласие 2 сторон 
        if ((changeTime==extraDays)&&(buyerOK==true)&&(changeTime!=0)){
            time+=changeTime*1 days;
            changeTime=0;
            buyerOK=false;
        }
    }
    
function kill() onlySeller private {                                            
            if ((address(this).balance)==0){
                selfdestruct(seller);
            }
    }

}