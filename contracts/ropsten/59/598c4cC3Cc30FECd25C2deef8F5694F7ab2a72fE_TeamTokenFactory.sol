pragma solidity 0.6.12;


import "@openzeppelin/contracts/token/ERC20/ERC20.sol";


contract TeamToken is ERC20 {
    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        uint256 _supply,
        address _owner,
        address _feeWallet
    ) public ERC20(_name, _symbol) {
        _setupDecimals(_decimals);
        _mint(_owner, _supply * 99/100);
        _mint(_feeWallet, _supply * 1/100);       
    }
}