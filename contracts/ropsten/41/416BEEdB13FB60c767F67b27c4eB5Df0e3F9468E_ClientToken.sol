// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ClientToken is ERC20{
    address public admin;
    uint maxSupply;
    uint circularSupply;
    uint privateSupply;
    uint founderSupply;
    uint trustSupply;
    uint advisorSupply;
    uint bountySupply;
    uint bonusSupply;
    uint contributerSupply;
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
        founderSupply= (maxSupply * 12) / 100;
        trustSupply= (maxSupply * 15) / 100;
        advisorSupply= (maxSupply * 5) / 100;
        bountySupply= (maxSupply * 3) / 100;
        bonusSupply= (maxSupply * 5) / 100;
        gold = 50;
        silver = 25;
        bronze = 8;
        copper = 5;
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

    function transferContributer(uint amount, address recipient) public {
        require(msg.sender == admin, 'only admin');
            if(block.timestamp >= june1 && block.timestamp <= june15){
            tier1 = tier1 - amount;
            gold = (amount * gold) / 100;
            amount = amount + gold;
            bonusSupply = bonusSupply - gold;
            _transfer(msg.sender, recipient, amount);
        }
        else if(block.timestamp >= june16 && block.timestamp <= june30){
            tier2 = tier2 - amount;
            silver = (amount * silver) / 100;
            amount = amount + silver;
            bonusSupply = bonusSupply - silver;
            _transfer(msg.sender, recipient, amount);
        }
        else if(block.timestamp >= july1 && block.timestamp <= july15){
            tier3 = tier3 - amount;
            bronze = (amount * bronze) / 100;
            amount = amount + bronze;
            bonusSupply = bonusSupply - bronze;
            _transfer(msg.sender, recipient, amount);
        }
        else if(block.timestamp >= july16 && block.timestamp <= july31){
            tier4 = tier4 - amount;
            copper = (amount * copper) / 100;
            amount = amount + copper;
            bonusSupply = bonusSupply - copper;
            _transfer(msg.sender, recipient, amount);
        }
        else{
            tier5 = tier5 - amount;
            amount = amount + mainSale;
            bonusSupply = bonusSupply - mainSale;
            _transfer(msg.sender, recipient, amount);
        }               
    }
    function transferfounder(uint amount, address recipient) public {
        require(msg.sender == admin, 'only admin');
        require(amount > founderSupply, 'amount exceeded');
        founderSupply = founderSupply - amount;
        _transfer(msg.sender, recipient, amount);
    }
    function transferTrust(uint amount, address recipient) public {
        require(msg.sender == admin, 'only admin');
        require(amount > founderSupply, 'amount exceeded');
        trustSupply = trustSupply - amount;
        _transfer(msg.sender, recipient, amount);
    }
    function transferAdvisor(uint amount, address recipient) public {
        require(msg.sender == admin, 'only admin');
        require(amount > founderSupply, 'amount exceeded');
        advisorSupply = advisorSupply - amount;
        _transfer(msg.sender, recipient, amount);
    }
    function transferBounty(uint amount, address recipient) public {
        require(msg.sender == admin, 'only admin');
        require(amount > founderSupply, 'amount exceeded');
        bountySupply = bountySupply - amount;
        _transfer(msg.sender, recipient, amount);
    }
    
}