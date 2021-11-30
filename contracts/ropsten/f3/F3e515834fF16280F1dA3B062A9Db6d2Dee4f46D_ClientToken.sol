// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ClientToken is ERC20{
    address public admin;
    uint maxSupply;
    uint circularSupply;
    uint privateSupply;
    uint teamSupply;
    uint trustSupply;
    uint advisorSupply;
    uint bountySupply;
    uint bonusSupply;
    uint contributerSupply;
    uint currentDate;
    uint june1;
    uint june15;
    uint june16;
    uint june30;
    uint july1;
    uint july15;
    uint july16;
    uint july31;
    uint august1;
    uint gold;
    uint silver;
    uint bronze;
    uint copper;
    uint mainSale;
    uint tier1;
    uint tier2;
    uint tier3;
    uint tier4;
    uint tier5;


    constructor() ERC20('task', 'token'){

        currentDate = block.timestamp;
        june1 = 1622487600;
        june15= 1623697200;
        june16 = 1623783600;
        june30 = 1625079599;
        july1 = 1625079600;
        july15= 1626375599;
        july16 = 1626375600;
        july31 = 1627757999;
        august1 = 1627758000;
        maxSupply = 2000000000;
        circularSupply= (maxSupply  * 60) / 100;
        privateSupply= (maxSupply  * 40) / 100;
        contributerSupply = circularSupply;
        teamSupply= (maxSupply * 12) / 100;
        trustSupply= (maxSupply * 15) / 100;
        advisorSupply= (maxSupply * 5) / 100;
        bountySupply= (maxSupply * 3) / 100;
        bonusSupply= (maxSupply * 5) / 100;
        gold = (bonusSupply * 50) / 100;
        silver = (bonusSupply * 25) / 100;
        bronze = (bonusSupply * 8) / 100;
        copper = (bonusSupply * 5) / 100;
        mainSale = 0;
        tier1 = (contributerSupply * 12) / 100;
        tier2 = (contributerSupply * 10) / 100;
        tier3 = (contributerSupply * 8) / 100;
        tier4 = (contributerSupply * 5) / 100;
        tier5 = (contributerSupply * 65) / 100;
        _mint(msg.sender, maxSupply);
        admin = msg.sender;
    }

    function mint(address to, uint amount) external {
        require(msg.sender == admin, 'only admin');
        _mint(to, amount);
    }
    
    function burn(uint amount) external{
        _burn(msg.sender, amount);
    }

    function transferContributer( address recipient) public {
        require(msg.sender == admin, 'only admin');
        if(currentDate >= june1 && currentDate <= june15){
            tier1 = tier1 + gold;
            _transfer(msg.sender, recipient, tier1);
        }
        else if(currentDate >= june16 && currentDate <= june30){
            tier2 = tier2 + silver;
            _transfer(msg.sender, recipient, tier2);
        }
        else if(currentDate >= july1 && currentDate <= july15){
            tier3 = tier3 + bronze;
            _transfer(msg.sender, recipient, tier3);
        }
        else if(currentDate >= july16 && currentDate <= july31){
            tier4 = tier4 + copper;
            _transfer(msg.sender, recipient, tier4);
        }
        else{
            tier5 = tier5 + mainSale;
            _transfer(msg.sender, recipient, tier5);
        }               
    }

    function transferfounder( address recipient) public {
        require(msg.sender == admin, 'only admin');
        _transfer(msg.sender, recipient, teamSupply);
    }

    function transferTrust(address recipient) public {
        require(msg.sender == admin, 'only admin');
        _transfer(msg.sender, recipient, trustSupply);
    }

    function transferAdvisor( address recipient) public {
        require(msg.sender == admin, 'only admin');
        _transfer(msg.sender, recipient, advisorSupply);
    }

    function transferBounty( address recipient) public {
        require(msg.sender == admin, 'only admin');
        _transfer(msg.sender, recipient, bountySupply);
    }
}