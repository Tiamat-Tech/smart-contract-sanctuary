// SPDX-License-Identifier: GPL-2.0-only
pragma solidity ^0.8.0;

import "./Corporation.sol";
import "./Verifier.sol";

contract CorporationFactory {
    event DefaultVerifierChanged(
        Verifier indexed newVerifier,
        Verifier indexed oldVerifier
    );
    event SuperuserChanged(address indexed superuser, bool indexed empowered);
    event CorporationCreated(Corporation indexed corporation);

    Verifier defaultVerifier;
    mapping(address => bool) public isSuperuser;

    constructor() {
        isSuperuser[msg.sender] = true;
    }

    function setDefaultVerifier(Verifier _defaultVerifier) external {
        require(
            isSuperuser[msg.sender],
            "CorporationFactory: unauthorized setDefaultVerifier"
        );
        emit DefaultVerifierChanged({
            newVerifier: _defaultVerifier,
            oldVerifier: defaultVerifier
        });
        defaultVerifier = _defaultVerifier;
    }

    function setSuperuser(address _operator, bool _empowered) external {
        require(
            isSuperuser[msg.sender],
            "Corporation: unauthorized setSuperuser"
        );
        isSuperuser[_operator] = _empowered;
        emit SuperuserChanged({superuser: _operator, empowered: _empowered});
    }

    function newCorporation(string calldata name, string calldata symbol)
        external
        returns (Corporation)
    {
        Corporation corporation = new Corporation();
        emit CorporationCreated({corporation: corporation});
        corporation.setVerifier(defaultVerifier);
        corporation.setName(name);
        corporation.setSymbol(symbol);
        corporation.setSuperuser(msg.sender, true);
        corporation.setSuperuser(address(this), false);
        return corporation;
    }
}