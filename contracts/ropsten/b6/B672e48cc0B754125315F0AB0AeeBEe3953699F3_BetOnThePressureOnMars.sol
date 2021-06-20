/** This example code is designed to quickly deploy an example contract using Remix.
 *  If you have never used Remix, try our example walkthrough: https://docs.chain.link/docs/example-walkthrough
 *  You will need testnet ETH and LINK.
 *     - Kovan ETH faucet: https://faucet.kovan.network/
 *     - Kovan LINK faucet: https://kovan.chain.link/
 */
// deploy this to address: xxx

pragma solidity ^0.6.6;
//SPDX-License-Identifier: MIT

//import "https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/v3.3.0/contracts/access/Ownable.sol";
//import "https://raw.githubusercontent.com/smartcontractkit/chainlink/develop/evm-contracts/src/v0.6/ChainlinkClient.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.6/ChainlinkClient.sol";

contract BetOnThePressureOnMars is ChainlinkClient, Ownable {
    using SafeMath for uint256;
    uint256 public showCurrentPressureOnMars;
    mapping (address => uint256) private _balances;

    struct Bet {
      address player;
      uint wager;
    }
    
    Bet[] private _large;
    Bet[] private _small;
    
    address private oracle;
    bytes32 private jobId;
    uint256 private fee;
    
    uint256 public old_pressure;
    
    /**
     * Network: Kovan
     * Oracle: Chainlink -  0x53912D3EE483Ac1549E1d47f154867aDf06DBa42
     * Job ID: Chainlink - 3d3cd67120344fdda95c239bbf272e51
     * Sample request Contract: xxx
     * Fee: 1 LINK
     */
    constructor() public {
        setPublicChainlinkToken();
        oracle =  0x53912D3EE483Ac1549E1d47f154867aDf06DBa42;
        jobId = "3d3cd67120344fdda95c239bbf272e51";
        fee = 1 * 10 ** 18; // 1 LINK
    }
    
    function howManyBetOnLarge() external view returns (uint) {
        return _large.length;
    }
    
    function howManyBetOnSmall() external view returns (uint) {
        return _small.length;
    }
    
     function forceToChangePressure(uint256 pa) public onlyOwner {
        showCurrentPressureOnMars = pa;
    }
    
    /**
     * Create a Chainlink request to retrieve API response, find the target price
     * data, then multiply by 100 (to remove decimal places from price).
     */
    function requestMarsReport() public onlyOwner returns (bytes32 requestId) 
    {
        old_pressure = showCurrentPressureOnMars;
        Chainlink.Request memory request = buildChainlinkRequest(jobId, address(this), this.fulfill.selector);
        
        // Set the URL to perform the GET request on
        request.add("get", "http://mars.muzamint.com:3000");
        
        string[] memory path = new string[](3);
        
        path[0] = "Data";
        path[1] = "PRE";
        path[2] = "av";
        
        request.addStringArray("path", path);
        
        // Multiply the result by 10000 to remove decimals
        int timesAmount = 10**4;
        request.addInt("times", timesAmount);
        
        // Sends the request
        return sendChainlinkRequestTo(oracle, request, fee);
    }
    
    function getFreeBonus () external {
        require(_balances[msg.sender]  <= 0);
        _balances[msg.sender] = _balances[msg.sender] + 100;
    }
    
    function betOnLargerPressureNextSol(uint256 wager) external {
        require(_balances[msg.sender]  >= wager,"not enough tokens");
        _balances[msg.sender] = _balances[msg.sender].sub(wager);
        _large.push(
            Bet(
              {
                player: msg.sender,
                wager: wager
              }
            )
        );
    }
    
    function betOnSmallerPressureNextSol(uint256 wager) external {
        require(_balances[msg.sender]  >= wager,"not enough tokens");
        _balances[msg.sender] = _balances[msg.sender].sub(wager);
        _small.push(
            Bet(
              {
                player: msg.sender,
                wager: wager
              }
            )
        );
    }
    
    function settlement() onlyOwner external {
        if(old_pressure == showCurrentPressureOnMars) {
        }        
        else if(old_pressure > showCurrentPressureOnMars) {
            for (uint i=0; i<_small.length; i++) {
             address player = _small[uint(i)].player;
             uint256 wager = _small[uint(i)].wager * 2;
             _balances[player] = _balances[player].add(wager);
            }
        } else {
            for (uint i=0; i<_large.length; i++) {
             address player = _large[uint(i)].player;
             uint256 wager = _large[uint(i)].wager * 2;
             _balances[player] = _balances[player].add(wager);
            }
        }
        delete _small;
        delete _large;
    }
    
    /**
     * Receive the response in the form of uint256
     */ 
    function fulfill(bytes32 _requestId, uint256 _result) public recordChainlinkFulfillment(_requestId)
    {
        showCurrentPressureOnMars = _result;
    }
        /**
     * Withdraw LINK from this contract
     * 
     * NOTE: DO NOT USE THIS IN PRODUCTION AS IT CAN BE CALLED BY ANY ADDRESS.
     * THIS IS PURELY FOR EXAMPLE PURPOSES ONLY.
     */
    function withdrawAllLink() onlyOwner external {
        LinkTokenInterface linkToken = LinkTokenInterface(chainlinkTokenAddress());
        require(linkToken.transfer(msg.sender, linkToken.balanceOf(address(this))), "Unable to transfer");
    }
    
    function showBalanceOf(address account) public view virtual returns (uint256) {
        return _balances[account];
    }
    
        function showYourBalance() public view virtual returns (uint256) {
        return _balances[msg.sender];
    }
}

library SafeMath {
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
      assert(b <= a);
      return a - b;
    }

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
      uint256 c = a + b;
      assert(c >= a);
      return c;
    }
}