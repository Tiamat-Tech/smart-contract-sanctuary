pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract payment is Ownable{
    
    event EtherReceived(address from, uint value);
    event vaultChanged(address new_address);
    event TokenReceived(string _name, uint _decimals, uint _amount, address _from);
    
    struct Tokens{
        string Name;
        string Symbol;
        address Address;
    }

    ERC20 ERC20Contract;
    mapping(address => bool) public whitelist;
    Tokens [] public TokensList;

    address payable vault;
    
    constructor() {
        vault = payable(owner());
    } 
    
    function receiveTokens(address _tokenAddr, uint _amount) external {
        require(whitelist[_tokenAddr], "Token not accepted");
        require(_amount > 0, "Amount Not Valid");
        ERC20Contract = ERC20(_tokenAddr);
        ERC20Contract.transferFrom(msg.sender, vault, _amount);

        emit TokenReceived(ERC20Contract.name(), ERC20Contract.decimals(), _amount, msg.sender);
    }
    
    function checkWhitelisted(address [] memory tokens) private view returns(bool){
        for(uint i = 0; i < tokens.length; i++){
            if(whitelist[tokens[i]] == false)
                return false;
        }
        return true;
    }
    
    function addToWhitelist(address _tokenAddr) external onlyOwner {
        require(_tokenAddr != address(0), "addToWhitelist: 0 Address cannot be added");
        require(whitelist[_tokenAddr] != true, "addToWhitelist: Already Whitelisted");

        whitelist[_tokenAddr] = true;
        ERC20Contract = ERC20(_tokenAddr);

        TokensList.push(Tokens(
        ERC20Contract.name(),
        ERC20Contract.symbol(),
        _tokenAddr
        ));
    }
    
    function removeFromWhitelist(address _tokenAddr) external onlyOwner {
        require(_tokenAddr != address(0), "removeFromWhitelist: Wrong Address");
        require(whitelist[_tokenAddr] != false, "removeFromWhitelist: Already removed from Whitelist");
        whitelist[_tokenAddr] = false;

        for (uint i = 0; i < TokensList.length; i++){
            if(TokensList[i].Address == _tokenAddr){
                TokensList[i] = TokensList[TokensList.length - 1];
                TokensList.pop();
            }
        }
    }
 
    function changeWalletAddress(address payable _newWallet) external onlyOwner {
        vault = _newWallet;
        emit vaultChanged(_newWallet);
    }

    function ListTokens() public view returns(Tokens [] memory){
        return TokensList;
    } 
    
    function decimals(address _tokenAddr) public returns(uint) {
        ERC20Contract = ERC20(_tokenAddr);
        return ERC20Contract.decimals();
    }
    
    receive() external payable {
        vault.transfer(msg.value);
        emit EtherReceived(msg.sender, msg.value);
    }
    
}