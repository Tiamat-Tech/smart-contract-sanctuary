pragma solidity ^0.6.2;

import "@openzeppelin/contracts/proxy/Initializable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

import "./interference/ERC20.sol";

contract Mapping is Initializable {
    using SafeMath for uint256;

    address public constant THIRM = 0x21Da60B286BaEfD4725A41Bb50a9237eb836a9Ed;

    mapping(string => address) private addressMap;

    function initialize() public initializer {}

    function getBurnAmount() public view returns (uint256) {
        uint256 tSupply = ERC20(THIRM).totalSupply();
        uint256 burnAmount = tSupply.div(1000000).mul(2);
        return burnAmount;
    }

    function setAddressMap(string memory _coinaddress) public {
        require(
            addressMap[_coinaddress] == address(0),
            "Address already mapped"
        );
        require(
            getBurnAmount() <= ERC20(THIRM).balanceOf(msg.sender),
            "No balance"
        );
        require(
            getBurnAmount() <=
                ERC20(THIRM).allowance(msg.sender, address(this)),
            "No allowance"
        );

        ERC20(THIRM).burnFrom(msg.sender, getBurnAmount());
        addressMap[_coinaddress] = msg.sender;
    }

    function getAddressMap(string memory _coinAddress)
        public
        view
        returns (address)
    {
        return addressMap[_coinAddress];
    }
}