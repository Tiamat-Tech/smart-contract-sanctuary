pragma solidity 0.8.4;

import "./ERC721Minter.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
// import "@openzeppelin/contracts/access/Ownable.sol";

contract Treasury {
    //using SafeERC20 for IERC20;
    address public owner;
    address public erc721MinterAddress;
    address public erc20BetrustAddress;
    error NFTOwnersOnly(string message);
    error OwnerOnly(string message);
    error NotEnoughBalance(string message, uint256 balance, uint256 amount);
    event ThisHappend(string message);

    constructor(address _erc721MinterAddress) public {
        owner = msg.sender;
        erc721MinterAddress = _erc721MinterAddress;
    }
    function setERC20BetrustAddress(address _erc20BetrustAddress) public returns (address){
        if(_erc20BetrustAddress == address(0)){
            revert OwnerOnly({message: '0address'});
        }
        if(msg.sender != owner){
            revert OwnerOnly({message: '!owner'});
        }
        erc20BetrustAddress = _erc20BetrustAddress;
        return erc20BetrustAddress;
    }
    function claim(address recipient) public returns (uint256){
        ERC721Minter erc721Minter = ERC721Minter(erc721MinterAddress);
        IERC20 erc20Betrust = IERC20(erc20BetrustAddress);
        uint256 amount = erc721Minter.calculateERC20Value(recipient);
        if(amount < 1){
            revert NFTOwnersOnly({message: '0NFTsOwned'});
        }
        if(erc20Betrust.balanceOf(address(this)) < amount){
            revert NotEnoughBalance({message:'balance<amount', balance: erc20Betrust.balanceOf(address(this)), amount: amount});
        }
        emit ThisHappend("this happend1");
        erc20Betrust.transfer(recipient, amount);
        emit ThisHappend("this happend2");
        // IERC20(erc20BetrustAddress).safeIncreaseAllowance(address(this), amount);
        // IERC20(erc20BetrustAddress).safeTransferFrom(address(this), recipient, amount); 
        return amount;
    }
}