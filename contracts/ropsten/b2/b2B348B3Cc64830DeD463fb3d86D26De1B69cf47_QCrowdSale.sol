// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import "../interface/IQSettings.sol";

/**
 * @author fantasy
 */
contract QCrowdSale is ReentrancyGuardUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    IQSettings public settings;
    uint256 public qstkPrice; // qstk price
    bool public started;

    modifier onlyManager() {
        require(
            settings.getManager() == msg.sender,
            "QCrowdSale: caller is not the manager"
        );
        _;
    }

    receive() external payable {}

    fallback() external payable {}

    function initialize(address _settings, uint256 _qstkPrice)
        external
        initializer
    {
        __ReentrancyGuard_init();

        settings = IQSettings(_settings);
        qstkPrice = _qstkPrice;
    }

    function start() external onlyManager {
        started = true;
    }

    function end() external onlyManager {
        started = false;
    }

    function setQStkPrice(uint256 _qstkPrice) external onlyManager {
        qstkPrice = _qstkPrice;
    }

    function setSettings(IQSettings _settings) external onlyManager {
        settings = _settings;
    }

    function depositQstk(uint256 _amount) external onlyManager nonReentrant {
        IERC20Upgradeable(settings.getQStk()).safeTransferFrom(
            msg.sender,
            address(this),
            _amount
        );
    }

    function withdrawQstk(uint256 _amount) external onlyManager nonReentrant {
        address qstk = settings.getQStk();
        require(
            IERC20Upgradeable(qstk).balanceOf(address(this)) >= _amount,
            "QCrowdSale: not enough balance"
        );
        IERC20Upgradeable(qstk).safeTransfer(msg.sender, _amount);
    }

    function withdrawETH(address payable treasury)
        external
        nonReentrant
        onlyManager
    {
        (bool sent, ) = treasury.call{value: address(this).balance}("");
        require(sent, "QCrowdSale: withdraw failed");
    }

    function buyQStk(uint256 _amount) external payable nonReentrant {
        require(started, "QCrowdSale: crowdsale not started");

        address qstk = settings.getQStk();
        uint256 decimal = IERC20MetadataUpgradeable(qstk).decimals();
        uint256 totalPrice = (_amount * qstkPrice) / (10**decimal);

        require(msg.value >= totalPrice, "QCrowdSale: insufficient eth");

        (bool sent, ) =
            payable(msg.sender).call{value: msg.value - totalPrice}("");

        require(sent, "QCrowdSale: failed to transfer remaining eth");

        IERC20Upgradeable(qstk).safeTransfer(msg.sender, _amount);
    }
}