pragma solidity >=0.8.9;

import "@openzeppelin/contracts/utils/Strings.sol";

contract Calculator {

   event CalculationPerformed(string operationName, string lhs, string rhs, string result);

   constructor() { }

   function add(uint lhs, uint rhs) public returns (uint)
   {
       uint result = lhs + rhs;
       require (result >= lhs);
       
       emit CalculationPerformed("Addition", Strings.toString(lhs), Strings.toString(rhs), Strings.toString(result));
       return result;
   }

   function subtract(uint lhs, uint rhs) public returns (uint)
   {
       uint result = lhs - rhs;
       require (result <= lhs);
       
       emit CalculationPerformed("Subtraction", Strings.toString(lhs), Strings.toString(rhs), Strings.toString(result));
       return result; 
   }

    //Divide, rounding any remainder towards zero
   function divideAndRound(uint dividend, uint divisor) public returns (uint)
   {
       require(divisor != 0);
       uint result = dividend / divisor; 
       require (result <= dividend);
       
       emit CalculationPerformed("Division", Strings.toString(dividend), Strings.toString(divisor), Strings.toString(result));
       return result; 
   }

    //Divide, returning the quotient and the remainder (in this order)
   function divide(uint dividend, uint divisor) public returns (uint, uint)
   {
       require(divisor != 0);
       uint quotient = dividend / divisor; 
       require (quotient <= dividend);
       uint remainder = dividend % divisor; 
       
       string memory eventMsg = string(abi.encodePacked("(", quotient, ",", remainder, ")"));
       emit CalculationPerformed("Division", Strings.toString(dividend), Strings.toString(divisor), eventMsg);
       return (quotient, remainder); 
   }

   function multiply(uint lhs, uint rhs) public returns (uint)
   {
       uint result = lhs * rhs;
       require(result / rhs == lhs || lhs == 0 || rhs == 0);
       
       emit CalculationPerformed("Multiplication", Strings.toString(lhs), Strings.toString(rhs), Strings.toString(result));
       return result; 
   }
}