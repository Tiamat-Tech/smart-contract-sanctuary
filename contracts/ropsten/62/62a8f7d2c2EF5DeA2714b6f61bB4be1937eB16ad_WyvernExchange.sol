pragma solidity 0.4.26;


import "./exchange/Exchange.sol";


contract WyvernExchange is Exchange{

    string public constant name = "Project Wyvern Exchange";
    string public constant version = "2.2";
    string public constant codename = "Lambton Worm";
 

    constructor(
        ProxyRegistry registryAddress,
        TokenTransferProxy tokenTransferProxyAddress,
        ERC20 tokenAddress,
        address protocolFeeAddress
    ) public {
        registry = registryAddress;
        tokenTransferProxy = tokenTransferProxyAddress;
        exchangeToken = tokenAddress;
        protocolFeeRecipient = protocolFeeAddress;
        owner = msg.sender;
    }
 }