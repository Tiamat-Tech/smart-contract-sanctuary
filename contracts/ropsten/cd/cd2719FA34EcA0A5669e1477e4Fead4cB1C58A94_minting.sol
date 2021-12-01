// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "mockDai.sol";
import "MintToken.sol";

contract minting {
    address public owner;
    address public contr = address(this);

    //Foo public foo = new Foo();

    mockDai public Dai = new mockDai();
    MintToken public mint = new MintToken();

    // inizializziamo la funzione dei contratti importati
    //Foo public foo = new Foo();

    constructor() {
        owner = msg.sender;
    }

    modifier OnlyOwner() {
        require(msg.sender == owner, "non hai i diritti di minting");
        _;
    }

    // set proprietario
    function setOwner(address _addr) public OnlyOwner {
        owner = _addr;
    }

    // 1 verifichaimo che abia i soldi
    // 2 ci facciamo mandare i soldi
    // 3 mintiamo il token
    // 4 gli e lo diamo

    function mintingToken(uint256 _value) public {
        Dai.transfer(contr, _value);
        address addr = msg.sender;
        mint.minting(addr, _value);
    }

    //burning
    // 1- prendiamo il mint token
    // 2- lo bruciamo
    // 3- gli ridiamo i soldi
    function burningToken(uint256 _value) public {
        address addr = msg.sender;
        mint.burning(addr, _value);

        Dai.transferFrom(contr, addr, _value);
    }
}