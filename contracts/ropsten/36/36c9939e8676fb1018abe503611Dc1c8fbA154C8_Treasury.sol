// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

import "@openzeppelin/contracts/proxy/Initializable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

import "./interference/ERC20.sol";

contract Treasury is Initializable {
    using SafeMath for uint256;

    address public MASTER;
    address public THIRM;

    uint256 public lastTimeExecuted;

    function initialize() public initializer {
        lastTimeExecuted = block.timestamp;
        MASTER = 0x2eC5cCb31b0369a179B813CBFCF9ED335334A978;
        THIRM = 0x21Da60B286BaEfD4725A41Bb50a9237eb836a9Ed;
    }

    function balanceCheck(address _tokenAddress) public view returns (uint256) {
        return ERC20(_tokenAddress).balanceOf(address(this));
    }

    function transfer(address _tokenAddress) public {
        ERC20(_tokenAddress).transfer(
            MASTER,
            ERC20(_tokenAddress).balanceOf(address(this))
        );
    }

    function transferReason(address _tokenAddress, uint256 _amount) public {
        ERC20(_tokenAddress).transfer(MASTER, _amount);
    }

    function toMint() public view returns (uint256) {
        uint256 toMintint = block.timestamp - lastTimeExecuted;
        uint256 minted = toMintint.mul(2000000000000000000);
        return minted;
    }

    function eXpand() public {
        ERC20(THIRM).mint(address(this), toMint());
        lastTimeExecuted = block.timestamp;
    }
}