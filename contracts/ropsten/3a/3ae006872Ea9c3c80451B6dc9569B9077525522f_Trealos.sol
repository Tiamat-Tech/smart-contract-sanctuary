// contracts/GLDToken.sol
// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract Trealos is ERC20 {
    uint256 private maxSupply;
    mapping (address => uint) public whitelist;
    mapping (address => uint) amountSentUsers;
    address[] public users;
    address public admin;
    uint randNonce = 0; 
    uint public tokenDistributed=0;

    constructor() ERC20("Trealos", "TRL") {
        _setupDecimals(2);
        maxSupply=1001002093092000000000000000000000090000;
        admin = msg.sender;
    }

    modifier isWhiteListed() {
        require(whitelist[msg.sender] > 0, "address is not whitelisted");
        _;
    }

    fallback()
    external
    payable isWhiteListed{ 
        getToken(msg.value,msg.sender);
    }

    function getToken(uint value, address sender) internal {
        value/=1000000000000000;
        require(
            value!=0,
            "Value is 0"
        );

        uint tiers = checkTiers(value, sender);
        require(
            totalSupply()+value*100*tiers<maxSupply,    //msg.value is in wei
            string(abi.encodePacked("Amount is too high there are only ", uint2str(maxSupply-totalSupply())," TRL remaining"))
        ); 
        tokenDistributed+=value*100*tiers;
        
        _mint(sender, value*100*tiers);
    }

    function adminAddUser(address newUser) public {
        require(
            msg.sender == admin,
            "Sender is not admin"
        );
        whitelist[newUser] = 1;
        amountSentUsers[newUser] = 0;
        users.push(newUser);
    }

    function changeTiers(uint tiers, address user) internal {
        require(
            tiers > 0,
            "Tier is negative"
        );
        require(
            tiers < 4,
            "Tier is too high"
        );
        whitelist[user] = tiers;
    }

    function checkTiers(uint amountSend, address user) internal returns (uint tiers) {
        uint totalAmountSent = amountSend + amountSentUsers[user];
        if (totalAmountSent > 400 && whitelist[user] < 3) {
            changeTiers(3, user);
        } else if (totalAmountSent > 200 && whitelist[user] < 2) {
            changeTiers(2, user);
        }
        return whitelist[user];
    }

    function airDrop() public {
        require(
            msg.sender == admin,
            "Sender is not admin"
        );
        address luckyOne = users[randMod(users.length)];
        _mint(luckyOne, 100);
    }
     
    function randMod(uint max) internal returns(uint)  
    { 
       // increase nonce 
       randNonce++;   
       return uint(keccak256(abi.encodePacked(block.timestamp,  
                                              msg.sender,  
                                              randNonce))) % max; 
    } 

    function uint2str(uint _i) internal pure returns (string memory _uintAsString) {
    if (_i == 0) {
        return "0";
    }
    uint j = _i;
    uint len;
    while (j != 0) {
        len++;
        j /= 10;
    }
    bytes memory bstr = new bytes(len);
    uint k = len - 1;
    while (_i != 0) {
        bstr[k--] = byte(uint8(48 + _i % 10));
        _i /= 10;
    }
    return string(bstr);
    }
}