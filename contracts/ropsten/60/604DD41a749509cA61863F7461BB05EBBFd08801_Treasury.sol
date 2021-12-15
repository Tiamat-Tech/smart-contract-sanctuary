pragma solidity 0.8.4;

import "./ERC721Minter.sol";
import "./ERC20Betrust.sol";

contract Treasury {
    address owner;
    address erc721MinterAddress;
    address erc20BetrustAddress;
    error NFTOwnersOnly(string message);
    error OwnerOnly(string message);
    error NotEnoughBalance(string message);

    constructor(address _erc721MinterAddress) public {
        owner = msg.sender;
        erc721MinterAddress = _erc721MinterAddress;
    }
    function setERC20BetrustAddress(address _erc20BetrustAddress) public returns (address){
        if(msg.sender == address(0)){
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
        ERC20Betrust erc20Betrust = ERC20Betrust(erc20BetrustAddress);
        uint256 amount = erc721Minter.calculateERC20Value(recipient);
        if(amount < 1){
            revert NFTOwnersOnly({message: '0NFTsOwned'});
        }
        if(erc20Betrust.balanceOf(address(this)) < amount){
            revert NotEnoughBalance({message:'balance<amount'});
        }
        erc20Betrust.transferFrom(address(this), recipient, amount);
        return amount;
    }
}