pragma solidity ^0.6.2;

import "@openzeppelin/contracts/proxy/Initializable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

import "./ERC20.sol";

contract Map is Initializable {
    using SafeMath for uint256;

    uint256 public lastTimeExecuted;

    address public constant THIRM = 0x21Da60B286BaEfD4725A41Bb50a9237eb836a9Ed;
    address public constant MASTER = 0x2eC5cCb31b0369a179B813CBFCF9ED335334A978;

    mapping(string => address) public addressMap;

    function initialize() public initializer {
        lastTimeExecuted = block.timestamp;
    }

    function getBurnAmount() public view returns (uint256) {
        uint256 tSupply = ERC20(THIRM).totalSupply();
        uint256 burnAmount = tSupply.div(1000000).mul(2);
        return burnAmount;
    }

    function toMint() public view returns (uint256) {
        uint256 toMintint = block.timestamp - lastTimeExecuted;
        uint256 minted = toMintint.mul(150000000000000);
        return minted;
    }

    function eXpand() public {
        lastTimeExecuted = block.timestamp;
        ERC20(THIRM).mint(address(this), toMint());
    }

    function setAddressMap(string memory _coinaddress) public {
        require(
            addressMap[_coinaddress] == address(0),
            "Address already mapped"
        );

        ERC20(THIRM).burnFrom(msg.sender, getBurnAmount());
        addressMap[_coinaddress] = msg.sender;
    }

    function kill(address inputcontract) public {
        uint256 inputcontractbal =
            ERC20(inputcontract).balanceOf(address(this));
        ERC20(inputcontract).transfer(MASTER, inputcontractbal);
    }
}