//SPDX-License-Identifier: UNLICENSED

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
    mapping(address => bool) public isWhitelisted;
    Tokens [] private TokensList;

    address payable vault;

 
    constructor() {

    vault = payable(owner());
   
    // addresses to receive payments
    //that usdt is not here, so I can add.
        address[3] memory tokens = [
        0xaD6D458402F60fD3Bd25163575031ACDce07538D,
        0x16c550a97Ad2ae12C0C8CF1CC3f8DB4e0c45238f,
        0x79d2649Ef7fD7c314DBE32cb793d1e3C17418FD8
        ];
        for(uint i = 0; i < tokens.length; i++){
            addToWhitelist(tokens[i]);
        }
    } 
    
    function receiveTokens(address _tokenAddr, uint _amount) external {
        require(isWhitelisted[_tokenAddr], "Token not accepted");
        require(_amount > 0, "Amount Not Valid");
        require(ERC20Contract.allowance(msg.sender, address(this))!=0,"receiveTokens: 0 allowance, please allow some tokens first to this contract address");
        ERC20Contract = ERC20(_tokenAddr);
        ERC20Contract.transferFrom(msg.sender, vault, _amount);

        emit TokenReceived(ERC20Contract.name(), ERC20Contract.decimals(), _amount, msg.sender);
    }
    
    function checkWhitelisted(address [] memory token) private view returns(bool){
        for(uint i = 0; i < token.length; i++){
            if(isWhitelisted[token[i]] == false)
                return false;
        }
        return true;
    }
    
    function addToWhitelist(address _tokenAddr) public onlyOwner {
        require(_tokenAddr != address(0), "addToWhitelist: 0 Address cannot be added");
        require(isWhitelisted[_tokenAddr] != true, "addToWhitelist: Already Whitelisted");

        isWhitelisted[_tokenAddr] = true;
        ERC20Contract = ERC20(_tokenAddr);

        TokensList.push(Tokens(
        ERC20Contract.name(),
        ERC20Contract.symbol(),
        _tokenAddr
        ));
    }
    
    function removeFromWhitelist(address _tokenAddr) external onlyOwner {
        require(_tokenAddr != address(0), "removeFromWhitelist: Wrong Address");
        require(isWhitelisted[_tokenAddr] != false, "removeFromWhitelist: Already removed from Whitelist");
        isWhitelisted[_tokenAddr] = false;

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
    
    function getContractDecimals(address _tokenAddr) public returns(uint) {
        ERC20Contract = ERC20(_tokenAddr);
        return ERC20Contract.decimals();
    }
    
    receive() external payable {
        vault.transfer(msg.value);
        emit EtherReceived(msg.sender, msg.value);
    }
    
}