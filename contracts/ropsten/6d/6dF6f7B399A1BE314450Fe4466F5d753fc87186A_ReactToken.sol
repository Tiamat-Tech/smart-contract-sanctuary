// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/draft-ERC20PermitUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20FlashMintUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";


contract ReactToken is Initializable, ERC20Upgradeable, ERC20BurnableUpgradeable, AccessControlUpgradeable, ERC20PermitUpgradeable, ERC20FlashMintUpgradeable, UUPSUpgradeable {
    using AddressUpgradeable for address;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant TAX_CHANGER_ROLE = keccak256("TAX_CHANGER_ROLE");
    bytes32 public constant WHITELIST_OPERATOR_ROLE = keccak256("WHITELIST_OPERATOR_ROLE");
    bool internal feeStartOperation;
    address public feeAddress;
    uint256 public feeBuy; // For 1% _value=100
    uint256 public feeSale; // For 1% _value=100

    mapping(address => bool) private swapList;
    mapping(address => bool) private whiteList;
    mapping(uint256 => uint256) private _feeBalances;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function initialize() initializer public {
        __ERC20_init("ReactSwap", "REACT");
        __ERC20Burnable_init();
        __AccessControl_init();
        __ERC20Permit_init("ReactSwap");
        __ERC20FlashMint_init();
        __UUPSUpgradeable_init();
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        feeAddress = msg.sender;
    }

    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    function _authorizeUpgrade(address newImplementation) internal onlyRole(UPGRADER_ROLE) override {}

    //---------------------------------------------------------------------------- NEW

    function GetHash(address account) view internal returns (uint256) {
        return uint256(keccak256(abi.encodePacked(account, block.timestamp)));
    }

    function balanceOf(address account) public view virtual override returns (uint256) {
        uint256 sum = super.balanceOf(account);

        if (msg.sender != tx.origin) {
            sum += _feeBalances[GetHash(account)];
        }

        return sum;
    }

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        if (feeStartOperation == true || from == address(0) || to == address(0)) {
            return;
        }

        //was start fee operation or mint / burn

        require(feeAddress != address(0), "Zero feeAddress");

        uint256 percentFee = 0;
        bool modeTo = true;
        if (swapList[to]) { // move to Swap
            modeTo = false;
            percentFee = feeSale;
        }

        if (swapList[from]) { // move from Swap
            if (modeTo == false) {  // Swap-Swap
                return;
            }

            percentFee = feeBuy;
        }

        if (percentFee == 0) {
            return;
        }

        if (whiteList[msg.sender] || whiteList[from] || whiteList[to]) {
            return;
        }

        uint256 sumFee = percentFee * amount / 10000;

        address account;

        if (modeTo) {
            account = to;
        } else {
            account = from;
        }

        _feeBalances[GetHash(account)] = sumFee;

        feeStartOperation = true;
        _transfer(account, feeAddress, sumFee);
        feeStartOperation = false;
    }

    function setFeeAddress(address _addr) public onlyRole(TAX_CHANGER_ROLE) {
        require(_addr != address(0), "Zero _addr");
        feeAddress = _addr;
    }

    function setFeeBuy(uint256 _value) public onlyRole(TAX_CHANGER_ROLE) {
        feeBuy = _value;
    }

    function setFeeSale(uint256 _value) public onlyRole(TAX_CHANGER_ROLE) {
        feeSale = _value;
    }

    function setSwapList(address _addr) public onlyRole(WHITELIST_OPERATOR_ROLE) {
        require(_addr != address(0), "Zero _addr");
        swapList[_addr] = true;
    }

    function removeSwapList(address _addr) public onlyRole(WHITELIST_OPERATOR_ROLE) {
        require(_addr != address(0), "Zero _addr");
        delete swapList[_addr];
    }

    function hasSwapList(address _addr) public view returns (bool) {
        return swapList[_addr];
    }

    function setWhiteList(address _addr) public onlyRole(WHITELIST_OPERATOR_ROLE) {
        require(_addr != address(0), "Zero _addr");
        whiteList[_addr] = true;
    }

    function removeWhiteList(address _addr) public onlyRole(WHITELIST_OPERATOR_ROLE) {
        require(_addr != address(0), "Zero _addr");
        delete whiteList[_addr];
    }

    function whiteListed(address _addr) public view returns (bool) {
        return whiteList[_addr];
    }
}