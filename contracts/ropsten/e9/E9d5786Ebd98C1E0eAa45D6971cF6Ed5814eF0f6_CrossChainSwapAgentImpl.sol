// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.11;

import "./interfaces/ISwap.sol";
import "./interfaces/IProxyInitialize.sol";
import "./gen20/GEN20UpgradeableProxy.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Context.sol";

// File: contracts/CrossChainSwapAgentImpl.sol

contract CrossChainSwapAgentImpl is Context {
    using SafeERC20 for IERC20;

    mapping(address => address) public swapMapping2BSC;
    mapping(address => address) public swapMappingFrmBSC;
    mapping(bytes32 => bool) public filledBSCTx;

    address payable public owner;
    address public gen20ProxyAdmin;
    address public gen20Implementation;
    uint256 public swapFee;

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );
    event SwapPairCreated(
        bytes32 indexed bscRegisterTxHash,
        address indexed gen20Addr,
        address indexed bep20Addr,
        string symbol,
        string name,
        uint8 decimals
    );
    event SwapStarted(
        address indexed gen20Addr,
        address indexed bep20Addr,
        address indexed fromAddr,
        uint256 amount,
        uint256 feeAmount,
        string chain
    );
    event SwapFilled(
        address indexed bep20Addr,
        bytes32 indexed bscTxHash,
        address indexed toAddress,
        uint256 amount,
        string chain
    );

    constructor(
        address gen20Impl,
        uint256 fee,
        address gen20ProxyAdminAddr
    ) {
        gen20Implementation = gen20Impl;
        swapFee = fee;
        owner = payable(msg.sender);
        gen20ProxyAdmin = gen20ProxyAdminAddr;
    }

    /**
     * Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    modifier notContract() {
        require(!isContract(msg.sender), "contract is not allowed to swap");
        _;
    }

    modifier noProxy() {
        require(msg.sender == tx.origin, "no proxy is allowed");
        _;
    }

    function isContract(address addr) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(addr)
        }
        return size > 0;
    }

    /**
     * Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public onlyOwner {
        emit OwnershipTransferred(owner, address(0));
        owner = payable(0);
    }

    /**
     * Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address payable newOwner) public onlyOwner {
        require(
            newOwner != address(0),
            "Ownable: new owner is the zero address"
        );
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    /**
     * Returns set minimum swap fee
     */
    function setSwapFee(uint256 fee) external onlyOwner {
        swapFee = fee;
    }

    /**
     * createSwapPair
     */
    function createSwapPair(
        bytes32 bscTxHash,
        address bep20Addr,
        string calldata name,
        string calldata symbol,
        uint8 decimals
    ) external onlyOwner returns (address) {
        require(
            swapMapping2BSC[bep20Addr] == address(0x0),
            "duplicated swap pair"
        );

        BEP20UpgradeableProxy proxyToken = new BEP20UpgradeableProxy(
            gen20Implementation,
            gen20ProxyAdmin,
            ""
        );
        IProxyInitialize token = IProxyInitialize(address(proxyToken));
        token.initialize(name, symbol, decimals, 0, true, address(this));

        swapMapping2BSC[bep20Addr] = address(token);
        swapMappingFrmBSC[address(token)] = bep20Addr;

        emit SwapPairCreated(
            bscTxHash,
            address(token),
            bep20Addr,
            symbol,
            name,
            decimals
        );
        return address(token);
    }

    /**
     * fill Swap between 2 chains
     */
    function fillSwap(
        bytes32 requestSwapTxHash,
        address bep20Addr,
        address toAddress,
        uint256 amount,
        string calldata chain
    ) external onlyOwner returns (bool) {
        require(!filledBSCTx[requestSwapTxHash], "bsc tx filled already");
        address genTokenAddr = swapMapping2BSC[bep20Addr];
        require(genTokenAddr != address(0x0), "no swap pair for this token");

        ISwap(genTokenAddr).mintTo(amount, toAddress);
        filledBSCTx[requestSwapTxHash] = true;
        emit SwapFilled(
            genTokenAddr,
            requestSwapTxHash,
            toAddress,
            amount,
            chain
        );

        return true;
    }

    /**
     * swap token to other chain
     */
    function swapToken(
        address gen20Addr,
        uint256 amount,
        string calldata chain
    ) external payable notContract noProxy returns (bool) {
        address bep20Addr = swapMappingFrmBSC[gen20Addr];
        require(bep20Addr != address(0x0), "no swap pair for this token");
        require(msg.value >= swapFee, "swap fee is not enough");

        IERC20(gen20Addr).safeTransferFrom(msg.sender, address(this), amount);
        ISwap(gen20Addr).burn(amount);
        if (msg.value != 0) {
            owner.transfer(msg.value);
        }

        emit SwapStarted(
            gen20Addr,
            bep20Addr,
            msg.sender,
            amount,
            msg.value,
            chain
        );
        return true;
    }
}