//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./IACPI.sol";
import "./ACPI1.sol";
import "./ACPI2.sol";
import "./ACPI3.sol";
import "./ACPI4.sol";

contract RealT is ERC20, Ownable, IACPI {
    /**
     * @dev currentACPI is 0 before ACPI start
     * @dev currentACPI is 1 on phase 1
     * @dev currentACPI is 2 on phase 2
     * @dev currentACPI is 3 on phase 3
     * @dev currentACPI is 4 on phase 4
     * @dev currentACPI is 5 when ACPI ends, Realt price will then be calculated
     */
    uint8 private _currentACPI;

    mapping(address => uint256) private _acpiBalance;

    ACPIOne public acpiOne;
    ACPITwo public acpiTwo;
    ACPIThree public acpiThree;
    ACPIFour public acpiFour;

    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        _currentACPI = 0;
        acpiOne = new ACPIOne(address(this));
        acpiTwo = new ACPITwo(address(this));
        acpiThree = new ACPIThree(address(this));
        acpiFour = new ACPIFour(address(this));
    }

    modifier onlyACPI() {
        require(
            msg.sender == address(acpiOne) ||
                msg.sender == address(acpiTwo) ||
                msg.sender == address(acpiThree) ||
                msg.sender == address(acpiFour)
        );
        _;
    }

    function acpiBalanceOf(address account) public view returns (uint256) {
        return
            acpiOne.investOf(account) +
            acpiTwo.investOf(account) +
            acpiThree.investOf(account) +
            acpiFour.investOf(account);
    }

    function getACPI() public view returns (uint8) {
        return _currentACPI;
    }

    function setACPI(uint8 currentACPI) external onlyACPI onlyOwner returns (uint8) {
        require(getACPI() < 5, "ACPI phase is over!");

        return _currentACPI = currentACPI;
    }

    /**
     * @dev Returns the amount of rounds per ACPI.
     */
    function totalRound() external view override returns (uint256 rounds) {
        require(getACPI() > 0, "ACPI phase has not yet started!");
        require(getACPI() < 5, "ACPI phase is over!");

        if (getACPI() == 1) return acpiOne.totalRound();
        else if (getACPI() == 2) return acpiTwo.totalRound();
        else if (getACPI() == 3) return acpiThree.totalRound();
        else if (getACPI() == 4) return acpiFour.totalRound();
    }

    /**
     * @dev Returns the amount of blocks per ACPI.
     */
    function roundTime() external view override returns (uint256 time) {
        require(getACPI() > 0, "ACPI phase has not yet started!");
        require(getACPI() < 5, "ACPI phase is over!");

        if (getACPI() == 1) return acpiOne.roundTime();
        else if (getACPI() == 2) return acpiTwo.roundTime();
        else if (getACPI() == 3) return acpiThree.roundTime();
        else if (getACPI() == 4) return acpiFour.roundTime();
    }

    /**
     * @dev Returns the amount of tokens invested by `account`.
     */
    function investOf(address account) public view override returns (uint256 amount) {
        require(getACPI() > 0, "ACPI phase has not yet started!");
        require(getACPI() < 5, "ACPI phase is over!");

        if (getACPI() == 1) return acpiOne.investOf(account);
        else if (getACPI() == 2) return acpiTwo.investOf(account);
        else if (getACPI() == 3) return acpiThree.investOf(account);
        else if (getACPI() == 4) return acpiFour.investOf(account);
    }

    /**
     * @dev Returns the amount of tokens invested by `account`.
     */
    function startRound() public override onlyOwner returns (bool success) {
        require(getACPI() > 0, "ACPI phase has not yet started!");
        require(getACPI() < 5, "ACPI phase is over!");

        if (getACPI() == 1) return acpiOne.startRound();
        else if (getACPI() == 2) return acpiTwo.startRound();
        else if (getACPI() == 3) return acpiThree.startRound();
        else if (getACPI() == 4) return acpiFour.startRound();
    }

    function acpiPrice() public view override returns (uint256) {
        require(getACPI() > 4, "ACPI phase is not yet finished!");

        return
            acpiOne.acpiPrice() +
            acpiTwo.acpiPrice() +
            acpiThree.acpiPrice() +
            acpiFour.acpiPrice();
    }

    function mint(address account, uint256 amount) public onlyACPI {
        return _mint(account, amount);
    }
}