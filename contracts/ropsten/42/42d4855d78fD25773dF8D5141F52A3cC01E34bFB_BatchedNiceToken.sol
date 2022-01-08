pragma solidity >=0.6.2 <0.8.0;

import "./ERC2309.sol";

contract BatchedNiceToken is ERC2309 {
    constructor () ERC2309("MyNFT", "MNFT") public {
        
    }

    function myMint(uint num) external {
        require(num > 0, "NFT number is greater than 0");
        _init(msg.sender, num);
    }
}