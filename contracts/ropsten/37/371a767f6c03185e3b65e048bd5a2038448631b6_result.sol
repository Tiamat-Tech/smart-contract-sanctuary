/**
 *Submitted for verification at Etherscan.io on 2022-01-27
*/

//SPDX-License-Identifier:MIT

pragma solidity >0.6.0;

contract result{

struct students{
       int roll_No;
       string name;
       int marks;
}
       string[] natija; 
       students[] public studRecord;
       uint counter = 0;
   event resultVal(int rn,string nm, string val);

    function getStudInfo(int roll,string memory _name,int _marks) public
    {
       
      studRecord.push(students({roll_No:roll, name:_name, marks:_marks}));

            if( _marks >= 33)
            {
                natija.push("pass");
                
            }
            else
            {
               natija.push("fail");
               
            }

           emit resultVal(roll,_name, natija[counter]);
           counter++;
            
    }
    }