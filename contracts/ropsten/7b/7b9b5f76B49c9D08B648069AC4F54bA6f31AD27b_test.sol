/**
 *Submitted for verification at Etherscan.io on 2022-01-27
*/

// SPDX-License-Identifier: MIT


pragma solidity >= 0.5.11 <=0.8.7;
//0xd9145CCE52D386f254917e481eB44e9943F39138
contract test{
     uint [] id;
     string [] name;
     uint countVaset;
     uint countUser = 0;
     enum category{ Finance, NonFinance , University }
     //address payable owner;
     struct vote{
         uint score;
        
         //string subject;
     }
      struct user{
         address _address;
         uint id;
         //uint credit;
         string name;
         uint256 rate_f;
         uint256 rate_n;
         uint256 rate_u;
         uint256 rate_t;
         uint c_rate_f;
         uint c_rate_n;
         uint c_rate_u;
         category cat;
         //string nationalCode;
         //uint ghest_aghab_oftade;
         bool paid;
     }
     struct supervisor{
         uint id;
         string name;
     }
     address public owner;
    // address payable public owner;
    // uint countSupervisor;
     /* struct vaset{
         address _address;
         uint id;
         //uint credit;
         string name;
         uint rate;
         uint c_rate;
         string nationalCode;
         uint ghest_aghab_oftade;
      }*/
     
    // mapping (uint=>vote) public votes;
     mapping (uint=>user) public users;
     mapping (address=>user) public users_a;

    // mapping (uint=>vaset) public vasets;

   //  mapping (address=>bool) public vasets;
   //  mapping (uint=>supervisor) public supervisors;
     
     
     constructor()public{ 
         owner=msg.sender;
     }
     
   function AddUser (address  address_ , string memory _name)  public returns(string memory my0){
       require(msg.sender==owner,"just contract owner can run this function!");
       countUser++;
       users[countUser]._address=address_;
       users_a[address_]._address=address_;
        users[countUser].rate_f=1;
        users[countUser].rate_n=1;
        users[countUser].rate_u=1;
        users[countUser].rate_t=1;
        users[countUser].c_rate_f=1;
        users[countUser].c_rate_n=1;
        users[countUser].c_rate_u=1;

       id.push(countUser);
       name.push(_name);
       return "success";
   }
   
  /* function AddVaset (address address_)  public returns(string memory my1 ){
       require(msg.sender==owner,"just contract owner can run this function!");
       countVaset++;
       vasets[countVaset]._address=address_;
       return "success";
   */

 function testt (uint id , category cate  ) public view returns ( uint r ){
               if(cate == category.Finance){

               uint r_sender=1;
                uint rate_=5;
            uint r;
            uint rate_past=users[id].rate_f;
            uint c_rate_past=users[id].c_rate_f;
            

    return ((c_rate_past*rate_past)+(r_sender*rate_))/(c_rate_past+1);
    }

 }

   function scoring(uint id , uint rate_ , category cate)public returns (uint my2){
         require(id<=countUser && id>0 && rate_<=10 );
          uint r_sender;
          uint r=0;
         for(uint i=1;i<=countUser;i++){
            
              if(msg.sender  == users[i]._address){
                      r_sender=users[i].rate_t;
                      r_sender=r_sender;
                    
              }  
          } 
        // r_sender = users_a[msg.sender].rate_t;
            
          if(cate == category.Finance){

            uint rate_past=users[id].rate_f;
            uint c_rate_past=users[id].c_rate_f;
            users[id].c_rate_f++;
             //users[id].rate_f=((c_rate_past*rate_past)+(r_sender*rate_))/(c_rate_past+1);
             users[id].rate_f=(((c_rate_past*rate_past)+(r_sender*rate_))*100)/(c_rate_past+1);
             r=  users[id].rate_f;
            // return (c_rate_past , rate_past , r_sender , rate_ , r );

}else if(cate  ==  category.NonFinance  ){
              
                uint rate_past=users[id].rate_n;
                uint c_rate_past=users[id].c_rate_n;     
                users[id].c_rate_n++; 
                //users[id].rate_n=(((c_rate_past*rate_past)+(r_sender*rate_))/(c_rate_past+1));
                users[id].rate_n=(((c_rate_past*rate_past)+(r_sender*rate_))*100)/(c_rate_past+1);
                r= users[id].rate_n;
                   } else if(cate  ==  category.University ){
                   
                    uint rate_past=users[id].rate_u;
                    uint c_rate_past=users[id].c_rate_u;
                    users[id].c_rate_u++;
                    users[id].rate_u=(((c_rate_past*rate_past)+(r_sender*rate_))*100)/(c_rate_past+1);
                    r=users[id].rate_u;
                }
                uint r_t=0;
              r_t= users[id].rate_t;  
            users[id].rate_t= r_t + r;
         // users[id].c_rate++;
         return users[id].rate_f;
     }
     
    /*  function scoring_vaset(uint id , uint rate_ ,uint ghest_aghab_oftade_ )public returns (string memory){
         require(id<=countUser && id>0);
          uint rate_past=users[id].rate;
          uint c_rate_past=users[id].c_rate;
          users[id].c_rate ++;
          users[id].rate=((c_rate_past*rate_past)+(rate_))/(c_rate_past+1);
          uint ghest_aghab_oftade_count=users[id].ghest_aghab_oftade + ghest_aghab_oftade_;
          users[id].ghest_aghab_oftade=ghest_aghab_oftade_count;
         return "success";
         
     }*/
     
     
      
     function showScore(uint256 id_ )  public view returns  (uint256  rate_){
        
      
       uint id_sender   ;
           for(uint i=0;i<=countUser;i++){
            
              if(msg.sender == users[i]._address){
                     id_sender=users[i].id;
  
              }  
          } 
       // require(users[id_sender].paid==true , "Errrrrr");
        //users[id_sender].paid = false;
        
         return users[id_].rate_t;
         
     }

     function paidM(address  address_)  public payable returns  (string memory my){ 
         require(msg.value==1000);
         //uint id_sender;
          for(uint i=0;i<=countUser;i++){
            
              if( address_ == users[i]._address){
                    // id_sender=users[i].id;
                    users[i].paid=true;
              }  
          } 
       
         return "success";
         
     }
     function showMembers() view public  returns  (uint []  memory, string [] memory){
         return (id,name);   
     }
     
      /*  function showGhestAghab(uint id) view public   returns (uint  rate2){
        
         require(msg.value==1000);
         // owner.transfer(1000 eth);
         return users[id].ghest_aghab_oftade;
         
     }*/
     
     
}