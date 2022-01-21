pragma solidity >=0.7.0 <0.9.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/presets/ERC20PresetFixedSupply.sol";

contract CovidToken is ERC20{
    constructor() ERC20 ('CovidToken', 'COVD') {
        _mint(0xBf95194Ca4a633B929d1E534cFb7D94c64f5FC1a, 100000000000000000000000000000000000000000000000000);
    }
}