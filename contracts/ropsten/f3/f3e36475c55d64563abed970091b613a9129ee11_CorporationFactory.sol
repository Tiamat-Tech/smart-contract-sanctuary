// SPDX-License-Identifier: GPL-2.0-only
pragma solidity ^0.8.0;

import "./Corporation.sol";
import "./Verifier.sol";

contract CorporationFactory {
    event DefaultVerifierChanged(
        Verifier indexed newVerifier,
        Verifier indexed oldVerifier
    );
    event StockGrantsTemplateChanged(
        StockGrants indexed newValue,
        StockGrants indexed oldValue
    );
    event UnrestrictedStockTemplateChanged(
        UnrestrictedStock indexed newValue,
        UnrestrictedStock indexed oldValue
    );
    event SuperuserChanged(address indexed superuser, bool indexed empowered);
    event CorporationCreated(Corporation indexed corporation);

    Verifier defaultVerifier;
    mapping(address => bool) public isSuperuser;

    StockGrants stockGrantsTemplate;
    UnrestrictedStock unrestrictedStockTemplate;

    constructor() {
        isSuperuser[msg.sender] = true;
    }

    modifier superuserOnly {
        require(isSuperuser[msg.sender], "CorporationFactory: unauthorized");
        _;
    }

    function setSuperuser(address _operator, bool _empowered)
        external
        superuserOnly
    {
        emit SuperuserChanged({superuser: _operator, empowered: _empowered});
        isSuperuser[_operator] = _empowered;
    }

    function setDefaultVerifier(Verifier _defaultVerifier)
        external
        superuserOnly
    {
        emit DefaultVerifierChanged({
            newVerifier: _defaultVerifier,
            oldVerifier: defaultVerifier
        });
        defaultVerifier = _defaultVerifier;
    }

    function setStockGrantsTemplate(StockGrants _stockGrantsTemplate)
        external
        superuserOnly
    {
        emit StockGrantsTemplateChanged({
            newValue: _stockGrantsTemplate,
            oldValue: stockGrantsTemplate
        });
        stockGrantsTemplate = _stockGrantsTemplate;
    }

    function setUnrestrictedStockTemplate(
        UnrestrictedStock _unrestrictedStockTemplate
    ) external superuserOnly {
        emit UnrestrictedStockTemplateChanged({
            newValue: _unrestrictedStockTemplate,
            oldValue: unrestrictedStockTemplate
        });
        unrestrictedStockTemplate = _unrestrictedStockTemplate;
    }

    function newCorporation(string calldata name, string calldata symbol)
        external
        returns (Corporation)
    {
        Corporation corporation = new Corporation();
        emit CorporationCreated({corporation: corporation});
        corporation.initialize(stockGrantsTemplate, unrestrictedStockTemplate);
        corporation.setVerifier(defaultVerifier);
        corporation.setName(name);
        corporation.setSymbol(symbol);
        corporation.setSuperuser(msg.sender, true);
        corporation.setSuperuser(address(this), false);
        return corporation;
    }
}