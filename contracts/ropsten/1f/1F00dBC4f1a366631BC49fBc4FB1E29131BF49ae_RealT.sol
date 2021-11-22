//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./ACPI1.sol";
import "./ACPI2.sol";
import "./ACPI3.sol";
import "./ACPI4.sol";

// @ made by github.com/@chichke

contract RealT is ERC20, Ownable {
    /**
     * @dev currentACPI is 0 before ACPI start
     * @dev currentACPI is 1 on phase 1
     * @dev currentACPI is 2 on phase 2
     * @dev currentACPI is 3 on phase 3
     * @dev currentACPI is 4 on phase 4
     * @dev currentACPI is 5 when ACPI ends, Realt price will then be calculated
     */
    uint8 private _currentACPI;

    ACPIOne public acpiOne;
    ACPITwo public acpiTwo;
    ACPIThree public acpiThree;
    ACPIFour public acpiFour;

    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        acpiOne = new ACPIOne(msg.sender);
        acpiTwo = new ACPITwo(msg.sender);
        acpiThree = new ACPIThree(msg.sender);
        acpiFour = new ACPIFour(msg.sender);
    }

    modifier onlyACPI() {
        require(
            msg.sender == address(acpiOne) ||
                msg.sender == address(acpiTwo) ||
                msg.sender == address(acpiThree) ||
                msg.sender == address(acpiFour) ||
                msg.sender == owner(),
            "only ACPI contract and owner are allowed to call this method"
        );
        _;
    }

    function getACPI() public view returns (uint8) {
        return _currentACPI;
    }

    function setACPI(uint8 currentACPI) external onlyACPI {
        require(currentACPI < 6, "Allowed value is 0-5");
        _currentACPI = currentACPI;
    }

    function mint(address account, uint256 amount) public onlyACPI {
        _mint(account, amount);
    }

    function batchMint(address[] calldata account, uint256[] calldata amount)
        public
        onlyACPI
    {
        require(
            account.length == amount.length,
            "Account & amount length mismatch"
        );

        require(account.length > 0, "Can't process empty array");

        for (uint256 index = 0; index < account.length; index++) {
            mint(account[index], amount[index]);
        }
    }

    function burn(address account, uint256 amount) public onlyACPI {
        return _burn(account, amount);
    }

    function batchBurn(address[] calldata account, uint256[] calldata amount)
        public
        onlyACPI
    {
        require(
            account.length == amount.length,
            "Account & amount length mismatch"
        );
        require(account.length > 0, "Can't process empty array");

        for (uint256 index = 0; index < account.length; index++) {
            burn(account[index], amount[index]);
        }
    }
}