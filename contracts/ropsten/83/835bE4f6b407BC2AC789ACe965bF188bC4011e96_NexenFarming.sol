// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


interface CErc20 {
    function balanceOf(address owner) external view returns (uint256);

    function mint(uint256) external returns (uint256);

    function exchangeRateCurrent() external returns (uint256);

    function supplyRatePerBlock() external returns (uint256);

    function redeem(uint) external returns (uint);

    function redeemUnderlying(uint) external returns (uint);

    function transfer(address recipient, uint256 amount) external returns (bool);

    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}


interface CEth {
    function balanceOf(address owner) external view returns (uint256);
    
    function mint() external payable;

    function exchangeRateCurrent() external returns (uint256);

    function supplyRatePerBlock() external returns (uint256);

    function redeem(uint) external returns (uint);

    function redeemUnderlying(uint) external returns (uint);

    function transfer(address recipient, uint256 amount) external returns (bool);
}


contract NexenFarming is Ownable {
    ERC20 daiToken = ERC20(0x31F42841c2db5173425b5223809CF3A38FEde360);
    ERC20 usdtToken = ERC20(0x110a13FC3efE6A245B50102D2d79B3E76125Ae83);

    address cDAI = 0xbc689667C13FB2a04f09272753760E38a95B998C;
    address cUSDT = 0xF6958Cf3127e62d3EB26c79F4f45d3F3b2CcdeD4;
    address payable cETH = payable(0x859e9d8a4edadfEDb5A2fF311243af80F85A91b8);
    
    ERC20 NexenToken = ERC20(0x80a35F3E05a5511725c7042cD9D8b5dCcE1919ad);
    
    uint256 public daiFees;
    uint256 public usdtFees;
    uint256 public ethFees;
    
    struct Supply {
        uint256 totalCTokens;
        uint256 totalTokens;
    }

    mapping(address => Supply) public DAISupplies;
    mapping(address => Supply) public USDTSupplies;
    mapping(address => Supply) public ETHSupplies;

    function supplyDAI(uint256 _numTokensToSupply) public payable {
        daiToken.transferFrom(msg.sender, address(this), _numTokensToSupply);
        
        uint mintResult = supplyErc20ToCompound(daiToken, cDAI, _numTokensToSupply);
        
        DAISupplies[msg.sender].totalTokens += _numTokensToSupply;
        DAISupplies[msg.sender].totalCTokens += mintResult;
    }
    
    function supplyUSDT(uint256 _numTokensToSupply) public payable {
        SafeERC20.safeTransferFrom(usdtToken, msg.sender, address(this), _numTokensToSupply);

        uint mintResult = supplyErc20ToCompound(usdtToken, cUSDT, _numTokensToSupply);
        
        USDTSupplies[msg.sender].totalTokens += _numTokensToSupply;
        USDTSupplies[msg.sender].totalCTokens += mintResult;
    }
    
    function supplyETH() public payable {
        uint mintResult = supplyEthToCompound(cETH);
        
        ETHSupplies[msg.sender].totalTokens += msg.value;
        ETHSupplies[msg.sender].totalCTokens += mintResult;
    }
    
    function redeemETH() public {
        uint256 totalUser = ETHSupplies[msg.sender].totalCTokens;
        require(totalUser > 0, 'Nothing to redeem');
        ETHSupplies[msg.sender].totalCTokens = 0;
        
        uint256 totalTokens = ETHSupplies[msg.sender].totalTokens;
        ETHSupplies[msg.sender].totalTokens = 0;
        
        uint256 balance = address(this).balance;
        
        uint256 redeemResult = redeemCEth(totalUser, true, cETH);
        require(redeemResult == 0, "An error occurred");
        
        uint256 newBalance = address(this).balance;
        uint256 interests = newBalance - balance - totalTokens;
        uint256 halfInterests = interests / 2;
        uint256 keep = interests - halfInterests;
        ethFees += keep;
        
        //1 WEI = 20000 NXN
        uint256 nexenTokensToReturn = interests * 20000;
        
        payable(msg.sender).transfer(halfInterests + totalTokens);
        NexenToken.transferFrom(address(this), msg.sender, nexenTokensToReturn);
    }
    
    function redeemDAI() public {
        uint256 totalUser = DAISupplies[msg.sender].totalCTokens;
        require(totalUser > 0, 'Nothing to redeem');
        DAISupplies[msg.sender].totalCTokens = 0;
        
        uint256 totalTokens = DAISupplies[msg.sender].totalTokens;
        DAISupplies[msg.sender].totalTokens = 0;
        
        uint256 balance = daiToken.balanceOf(address(this));

        uint256 redeemResult = redeemCErc20Tokens(totalUser, true, cDAI);
        require(redeemResult == 0, "An error occurred");
        
        uint256 newBalance = daiToken.balanceOf(address(this));
        uint256 interests = newBalance - balance - totalTokens;
        uint256 halfInterests = interests / 2;
        uint256 keep = interests - halfInterests;
        daiFees += keep;
        
        //14 DAI = 100 NXN
        uint256 nexenTokensToReturn = interests * 100 / 14;

        daiToken.transferFrom(address(this), msg.sender, halfInterests + totalTokens);
        NexenToken.transferFrom(address(this), msg.sender, nexenTokensToReturn);
    }
    
    function redeemUSDT() public {
        uint256 totalUser = USDTSupplies[msg.sender].totalCTokens;
        require(totalUser > 0, 'Nothing to redeem');
        USDTSupplies[msg.sender].totalCTokens = 0;
        
        uint256 totalTokens = USDTSupplies[msg.sender].totalTokens;
        USDTSupplies[msg.sender].totalTokens = 0;
        
        uint256 balance = usdtToken.balanceOf(address(this));

        uint256 redeemResult = redeemCErc20Tokens(totalUser, true, cUSDT);
        require(redeemResult == 0, "An error occurred");
        
        uint256 newBalance = usdtToken.balanceOf(address(this));
        uint256 interests = newBalance - balance - totalTokens;
        uint256 halfInterests = interests / 2;
        uint256 keep = interests - halfInterests;
        usdtFees += keep;
        
        //140000 USDT = 1e18 NXN
        uint256 nexenTokensToReturn = interests * 1e14 / 14;

        SafeERC20.safeTransfer(usdtToken, msg.sender, halfInterests + totalTokens);
        NexenToken.transferFrom(address(this), msg.sender, nexenTokensToReturn);
    }
    
    function _withdrawFees() public onlyOwner {
        uint256 totalETHFees = ethFees;
        if (totalETHFees > 0) {
            ethFees = 0;
            payable(msg.sender).transfer(totalETHFees);
        }

        uint256 totalDaiFees = daiFees;
        if (totalDaiFees > 0) {
        daiFees = 0;
            daiToken.transfer(msg.sender, totalDaiFees);
        }

        uint256 totalUsdtFees = usdtFees;
        if ( totalUsdtFees> 0) {
            usdtFees = 0;
            SafeERC20.safeTransfer(usdtToken, msg.sender, totalUsdtFees);
        }
    }
    
    function _recoverNexenTokens(uint256 _amount) public onlyOwner {
        require(NexenToken.transfer(msg.sender, _amount), 'Could not transfer tokens');
    }
    
    function supplyEthToCompound(address payable _cEtherContract)
        internal
        returns (uint256)
    {
        // Create a reference to the corresponding cToken contract
        CEth cToken = CEth(_cEtherContract);

        uint256 balance = cToken.balanceOf(address(this));

        cToken.mint{value:msg.value, gas: 250000}();
        return cToken.balanceOf(address(this)) - balance;
    }
    
    function supplyErc20ToCompound(
        ERC20 _erc20Contract,
        address _cErc20Contract,
        uint256 _numTokensToSupply
    ) internal returns (uint) {
        // Create a reference to the corresponding cToken contract, like cDAI
        CErc20 cToken = CErc20(_cErc20Contract);

        uint256 balance = cToken.balanceOf(address(this));

        // Approve transfer on the ERC20 contract
        SafeERC20.safeApprove(_erc20Contract, _cErc20Contract, _numTokensToSupply);

        // Mint cTokens
        cToken.mint(_numTokensToSupply);
        
        uint256 newBalance = cToken.balanceOf(address(this));

        return newBalance - balance;
    }
    
    function redeemCErc20Tokens(
        uint256 amount,
        bool redeemType,
        address _cErc20Contract
    ) internal returns (uint256) {
        // Create a reference to the corresponding cToken contract, like cDAI
        CErc20 cToken = CErc20(_cErc20Contract);

        // `amount` is scaled up, see decimal table here:
        // https://compound.finance/docs#protocol-math

        uint256 redeemResult;

        if (redeemType == true) {
            // Retrieve your asset based on a cToken amount
            redeemResult = cToken.redeem(amount);
        } else {
            // Retrieve your asset based on an amount of the asset
            redeemResult = cToken.redeemUnderlying(amount);
        }

        return redeemResult;
    }

    function redeemCEth(
        uint256 amount,
        bool redeemType,
        address _cEtherContract
    ) internal returns (uint256) {
        // Create a reference to the corresponding cToken contract
        CEth cToken = CEth(_cEtherContract);

        // `amount` is scaled up by 1e18 to avoid decimals

        uint256 redeemResult;

        if (redeemType == true) {
            // Retrieve your asset based on a cToken amount
            redeemResult = cToken.redeem(amount);
        } else {
            // Retrieve your asset based on an amount of the asset
            redeemResult = cToken.redeemUnderlying(amount);
        }

        // Error codes are listed here:
        // https://compound.finance/docs/ctokens#ctoken-error-codes
        return redeemResult;
    }

    // This is needed to receive ETH when calling `redeemCEth`
    receive() external payable {}
}