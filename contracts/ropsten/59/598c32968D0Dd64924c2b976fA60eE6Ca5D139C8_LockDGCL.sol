pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract LockDGCL is Ownable {
    address ERC20Address;

    constructor(address erc20Addr) public {
        ERC20Address = erc20Addr;
    }

    struct LockInfo{
        uint Timestamp;
        address Receiver;
        uint256 Amount;
    }

    uint internal lockCounter = 0;
    uint internal stage = 0;
    uint internal receiverCount = 0;


    mapping(uint => LockInfo) public unlockMapping; //uint is timestamp uin256 is amount


    function unlockToken() onlyOwner public  {
        require(stage <= 2, "3 phase only");
        require(block.timestamp >= unlockMapping[stage].Timestamp , "Too early to call.");
        if(block.timestamp >= unlockMapping[stage].Timestamp) {
            for (uint i=0; i < receiverCount; i++) {
                ERC20 erc20 = ERC20(ERC20Address);
                require(erc20.transfer(unlockMapping[i].Receiver,unlockMapping[i].Amount) , "Can Not Call Transfer");
            }
            stage+=1;
        }
    }
    function setUnlockInfo(uint timestamp, uint256 amount, address receiver) onlyOwner public{
        require(lockCounter <= 2 , 'lockCounter must be lower than 2');
        unlockMapping[lockCounter].Timestamp = timestamp;
        unlockMapping[lockCounter].Receiver = receiver;
        unlockMapping[lockCounter].Amount = amount;
        lockCounter += 1;
    }

    function setERC20Address(address erc20Addr) onlyOwner public {
        ERC20Address = erc20Addr;
    }

}