/**
 *Submitted for verification at Etherscan.io on 2021-12-07
*/

pragma solidity ^0.8.1;

interface PriceFeed{
    function setPrice(uint _price) external;
    function latestAnswer() external view returns (uint);
}

pragma solidity ^0.8.1;

interface ERC20{
    function mint(address to, uint amount) external;
}

pragma solidity ^0.8.1;

contract TesterHub {

    mapping(string => address) public tokens;
    mapping(string => address) public priceFeeds;

    constructor(string[] memory _tokenNames,address[] memory _tokenAddresses, address[] memory _priceFeedAddresses){
        require(_tokenNames.length == _tokenAddresses.length);

        for (uint8 i = 0; i < _tokenNames.length; i++) {
            tokens[_tokenNames[i]] = _tokenAddresses[i];
            priceFeeds[_tokenNames[i]] = _priceFeedAddresses[i];
        }
    }

    function changePrice(uint _newPrice, string memory _tokenName) external {
        require(_newPrice>0);
        require(priceFeeds[_tokenName] != address(0));

        PriceFeed(priceFeeds[_tokenName]).setPrice(_newPrice);        
    }

    function mintToken(string memory _tokenName, address _receiverAddress, uint _amount) external {
        require(_amount>0);
        require(_receiverAddress != address(0));
        require(tokens[_tokenName] != address(0));

        ERC20(tokens[_tokenName]).mint(_receiverAddress, _amount);
    }

    function addToken(string[] memory _tokenNames, address[] memory _tokenAddresses) external {
        require(_tokenNames.length == _tokenAddresses.length);
        require(_tokenNames.length > 0);

        for (uint256 i = 0; i < _tokenNames.length; i++) {
            tokens[_tokenNames[i]] = _tokenAddresses[i];
        }
    }
}