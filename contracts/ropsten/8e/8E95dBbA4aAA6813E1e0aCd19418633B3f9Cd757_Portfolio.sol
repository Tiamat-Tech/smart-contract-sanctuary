// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./interfaces/IPortfolio.sol";
import "./interfaces/ITradePairs.sol";
import "./interfaces/IDexManager2.sol";
/**
*   @title "Portfolio: a contract to implement portfolio functionality for all traders."
*   @dev "The main data structure, assets, is implemented as a nested map from an address and symbol to an AssetEntry struct."
*   @dev "Assets keeps track of all assets on DEXPOOL per user address per symbol."
*/

contract Portfolio is ReentrancyGuard, Ownable, IPortfolio {
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.Bytes32Set;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    // bytes32 array of all ERC20 tokens traded on DEXPOOL
    EnumerableSetUpgradeable.Bytes32Set private tokenList;

    // bytes32 variable to hold native token of DEXPOOL
    bytes32 constant public native = bytes32('AVAX');

    // structure to track an asset
    struct AssetEntry {
        uint total;
        uint available;
    }

    // boolean to control deposit functionality
    bool private allowDeposit;
    // denominator for rate calculations
    uint constant private TENK = 10000;
    // numerator for rate % to be used with a denominator of 10000
    uint public depositFeeRate;
    uint public withdrawFeeRate;

    enum AssetType {NATIVE, ERC20, NONE}

    // bytes32 symbols to ERC20 token map
    mapping (bytes32 => IERC20Upgradeable) private tokenMap;
    // account address to assets map
    mapping (address => mapping (bytes32 => AssetEntry)) public assets;
    // contract address to trust status
    mapping (address => bool) public trustedContracts;
    // contract address to integrator organization name
    mapping (address => string) public trustedContractToIntegrator;

    IDexManager2 private dexManager;

    event ParameterUpdated(bytes32 indexed pair, string _param, uint _oldValue, uint _newValue);

    event ContractTrustStatusChanged(address indexed _contract, string indexed _organization, bool _status);
    event PortfolioInit(address dexManagerAddress);

    constructor() {
        allowDeposit = true;
        depositFeeRate = 0;    // depositFeeRate=0 (0% = 0/10000)
        withdrawFeeRate = 0;   // withdrawFeeRate=0 (0% = 0/10000)
    }

    function initialize(address _manager) public onlyOwner {
        dexManager = IDexManager2(_manager);
        emit PortfolioInit(_manager);
    }


    function pauseDeposit(bool _paused) public onlyOwner override {
        allowDeposit = !_paused;
    }

    function addTrustedContract(address _contract, string calldata _organization) external onlyOwner {
        trustedContracts[_contract] = true;
        trustedContractToIntegrator[_contract] = _organization;
        emit ContractTrustStatusChanged(_contract, _organization, true);
    }


    function removeTrustedContract(address _contract) external onlyOwner {
        trustedContracts[_contract] = false;
        emit ContractTrustStatusChanged(_contract, trustedContractToIntegrator[_contract], false);
    }

    function updateTransferFeeRate(uint _rate, Tx _rateType) public override onlyOwner {
        if (_rateType == Tx.WITHDRAW) {
            emit ParameterUpdated(bytes32("Portfolio"), "P-DEPFEE", depositFeeRate, _rate);
            depositFeeRate = _rate; // (_rate/100)% = _rate/10000: _rate=10 => 0.10%
        } else if (_rateType == Tx.DEPOSIT) {
            emit ParameterUpdated(bytes32("Portfolio"), "P-WITFEE", withdrawFeeRate, _rate);
            withdrawFeeRate = _rate; // (_rate/100)% = _rate/10000: _rate=20 => 0.20%
        } // Ignore the rest for now
    }

    function getDepositFeeRate() public view returns(uint) {
        return depositFeeRate;
    }

    function getWithdrawFeeRate() public view returns(uint) {
        return withdrawFeeRate;
    }

    // function to add an ERC20 token
    function addToken(bytes32 _symbol, IERC20Upgradeable _token) public override {
        require(address(dexManager) == msg.sender, "msg sender should be dexManager");
        if (!tokenList.contains(_symbol)) {
            tokenList.add(_symbol);
            tokenMap[_symbol] = _token;
        }
    }

    // FRONTEND FUNCTION TO GET ERC20 TOKEN LIST
    function getTokenList() public view returns(bytes32[] memory) {
        bytes32[] memory tokens = new bytes32[](tokenList.length());
        for (uint i=0; i<tokenList.length(); i++) {
            tokens[i] = tokenList.at(i);
        }
        return tokens;
    }

    // FRONTEND FUNCTION TO GET AN ERC20 TOKEN
    function getToken(bytes32 _symbol) public view returns(IERC20Upgradeable) {
        return tokenMap[_symbol];
    }

    // FRONTEND FUNCTION TO GET PORTFOLIO BALANCE FOR AN ACCOUNT AND TOKEN SYMBOL
    function getBalance(address _owner, bytes32 _symbol) public view
    returns(uint total, uint available, AssetType assetType) {
        assetType = AssetType.NONE;
        if (native == _symbol) {
            assetType = AssetType.NATIVE;
        }
        if (tokenList.contains(_symbol)) {
            assetType = AssetType.ERC20;
        }
        total = assets[_owner][_symbol].total;
        available = assets[_owner][_symbol].available;
        return (total, available, assetType);
    }

    // we revert transaction if a non-existing function is called
    fallback() external {
        revert();
    }

    // FRONTEND FUNCTION TO DEPOSIT NATIVE TOKEN WITH WEB3 SENDTRANSACTION
    receive() external payable nonReentrant {
        require(allowDeposit, "P-NTDP-01");
        uint _quantityLessFee = msg.value;
        uint feeCharged;
        if (depositFeeRate>0) {
            feeCharged = (msg.value * depositFeeRate) / TENK;
            safeTransferFee(native, feeCharged);
            _quantityLessFee -= feeCharged;
        }
        safeIncrease(msg.sender, native, _quantityLessFee, 0, Tx.DEPOSIT);
        emitPortfolioEvent(msg.sender, native, msg.value, feeCharged, Tx.DEPOSIT);
    }

    // FRONTEND FUNCTION TO WITHDRAW A QUANTITY FROM PORTFOLIO BALANCE FOR AN ACCOUNT AND NATIVE SYMBOL
    function withdrawNative(address payable _to, uint _quantity) public nonReentrant {
        require(_to == msg.sender, "P-OOWN-01");
        safeDecrease(_to, native, _quantity, Tx.WITHDRAW); // does not decrease if transfer fails
        uint _quantityLessFee = _quantity;
        uint feeCharged;
        if (withdrawFeeRate>0) {
            feeCharged = (_quantity * withdrawFeeRate) / TENK;
            safeTransferFee(native, feeCharged);
            _quantityLessFee -= feeCharged;
        }
        (bool success, ) = _to.call{value: _quantityLessFee}('');
        require(success, "P-WNF-01");
        emitPortfolioEvent(msg.sender, native, _quantity, feeCharged, Tx.WITHDRAW);
    }

    // handle ERC20 token deposit and withdrawal
    // FRONTEND FUNCTION TO DEPOSIT A QUANTITY TO PORTFOLIO BALANCE FOR AN ACCOUNT AND TOKEN SYMBOL
    function depositToken(address _from, bytes32 _symbol, uint _quantity) public nonReentrant {
        require(_from == msg.sender, "P-OODT-01");
        require(allowDeposit, "P-ETDP-01");
        require(_quantity > 0, "P-ZETD-01");
        require(tokenList.contains(_symbol), "P-ETNS-01");
        uint feeCharged;
        if (depositFeeRate>0) {
            feeCharged = (_quantity * depositFeeRate) / TENK;
        }
        uint _quantityLessFee = _quantity - feeCharged;
        safeIncrease(_from, _symbol, _quantityLessFee, 0, Tx.DEPOSIT); // reverts if transfer fails
        require(_quantity <= tokenMap[_symbol].balanceOf(_from), "P-NETD-01");
        tokenMap[_symbol].safeTransferFrom(_from, address(this), _quantity);
        if (depositFeeRate>0) {
            safeTransferFee(_symbol, feeCharged);
        }
        emitPortfolioEvent(_from, _symbol, _quantity, feeCharged, Tx.DEPOSIT);
    }

    function depositTokenFromContract(address _from, bytes32 _symbol, uint _quantity) public nonReentrant {
        require(trustedContracts[msg.sender], "P-AOTC-01");
        require(allowDeposit, "P-ETDP-02");
        require(_quantity > 0, "P-ZETD-02");
        require(tokenList.contains(_symbol), "P-ETNS-02");
        safeIncrease(_from, _symbol, _quantity, 0, Tx.DEPOSIT); // reverts if transfer fails
        require(_quantity <= tokenMap[_symbol].balanceOf(_from), "P-NETD-02");
        tokenMap[_symbol].safeTransferFrom(_from, address(this), _quantity);
        emitPortfolioEvent(_from, _symbol, _quantity, 0, Tx.DEPOSIT);
    }

    // FRONTEND FUNCTION TO WITHDRAW A QUANTITY FROM PORTFOLIO BALANCE FOR AN ACCOUNT AND TOKEN SYMBOL
    function withdrawToken(address _to, bytes32 _symbol, uint _quantity) public nonReentrant {
        require(_to == msg.sender, "P-OOWT-01");
        require(_quantity > 0, "P-ZTQW-01");
        require(tokenList.contains(_symbol), "P-ETNS-02");
        safeDecrease(_to, _symbol, _quantity, Tx.WITHDRAW); // does not decrease if transfer fails
        uint _quantityLessFee = _quantity;
        uint feeCharged;
        if (withdrawFeeRate>0) {
            feeCharged = (_quantity * withdrawFeeRate) / TENK;
            safeTransferFee(_symbol, feeCharged);
            _quantityLessFee -= feeCharged;
        }
        tokenMap[_symbol].safeTransfer(_to, _quantityLessFee);
        emitPortfolioEvent(_to, _symbol, _quantity, feeCharged, Tx.WITHDRAW);
    }

    function emitPortfolioEvent(address _trader, bytes32 _symbol, uint _quantity, uint _feeCharged,  Tx transaction) private {
        emit PortfolioUpdated(transaction, _trader, _symbol, _quantity, _feeCharged, assets[_trader][_symbol].total, assets[_trader][_symbol].available);
    }

    // WHEN Increasing in addExectuion the amount is applied to both Total & Available(so SafeIncrease can be used) as opposed to
    // WHEN Decreasing in addExectuion the amount is only applied to Total.(SafeDecrease can NOT be used, so we have safeDecreaseTotal instead)
    // i.e. (USDT 100 Total, 50 Available after we send a BUY order of 10 avax @5$. Partial Exec [email protected] Total goes down to 75. Available stays at 50 )
    function addExecution(
        ITradePairs.Order memory _maker,
        address _takerAddr,
        bytes32 _baseSymbol,
        bytes32 _quoteSymbol,
        uint _baseAmount,
        uint _quoteAmount,
        uint _makerfeeCharged,
        uint _takerfeeCharged)
    public override {
        // TRADEPAIRS SHOULD HAVE ADMIN ROLE TO INITIATE PORTFOLIO addExecution
        // if _maker.side = BUY then _taker.side = SELL
        if (_maker.side == ITradePairs.Side.BUY) {
            // decrease maker quote and incrase taker quote
            safeDecreaseTotal(_maker.traderAddress, _quoteSymbol, _quoteAmount, Tx.EXECUTION);
            // console.log(_takerAddr, bytes32ToString(_quoteSymbol), "BUY Increase quoteAmount =", _quoteAmount );
            safeIncrease(_takerAddr, _quoteSymbol, _quoteAmount, _takerfeeCharged, Tx.EXECUTION);
            // increase maker base and decrase taker base
            safeIncrease(_maker.traderAddress, _baseSymbol, _baseAmount, _makerfeeCharged, Tx.EXECUTION);
            safeDecrease(_takerAddr,_baseSymbol, _baseAmount, Tx.EXECUTION);
        } else {
            // increase maker quote & decrease taker quote
            safeIncrease(_maker.traderAddress, _quoteSymbol, _quoteAmount, _makerfeeCharged, Tx.EXECUTION);
            // console.log(_takerAddr, bytes32ToString(_quoteSymbol), "SELL Decrease quoteAmount =", _quoteAmount );
            safeDecrease(_takerAddr, _quoteSymbol, _quoteAmount, Tx.EXECUTION);
            // decrease maker base and incrase taker base
            safeDecreaseTotal(_maker.traderAddress, _baseSymbol, _baseAmount, Tx.EXECUTION);
            safeIncrease(_takerAddr, _baseSymbol, _baseAmount, _takerfeeCharged, Tx.EXECUTION);
        }
    }

    function adjustAvailable(Tx _transaction, address _trader, bytes32 _symbol, uint _amount) public override {
        // TRADEPAIRS SHOULD HAVE ADMIN ROLE TO INITIATE PORTFOLIO adjustAvailable
        // console.log("adjustAvailable = ", _amount);
        if (_transaction == Tx.INCREASEAVAIL) {
            // console.log(_trader, bytes32ToString(_symbol), "AdjAvailable Increase =", _amount );
            assets[_trader][_symbol].available += _amount;
        } else if (_transaction == Tx.DECREASEAVAIL)  {
            require(_amount <= assets[_trader][_symbol].available, "P-AFNE-01");
            // console.log(_trader, bytes32ToString(_symbol), "AdjAvailable Decrease =", _amount );
            assets[_trader][_symbol].available -= _amount;
        } // IGNORE OTHER types of _transactions
        emitPortfolioEvent(_trader, _symbol, _amount, 0, _transaction);
    }

    function safeTransferFee(bytes32 _symbol, uint _feeCharged) private {
        // console.log (bytes32ToString(_symbol), "safeTransferFee = Fee ", _feeCharged );
        bool feesuccess = true;
        if (native == _symbol) {
            (feesuccess, ) = payable(dexManager.commissionAddress()).call{value: _feeCharged}('');
            require(feesuccess, "P-STFF-01");
        } else {
            tokenMap[_symbol].safeTransfer(payable(dexManager.commissionAddress()), _feeCharged);
        }
    }

    // Only called from addExecution
    function safeDecreaseTotal(address _trader, bytes32 _symbol, uint _amount, Tx transaction) private {
        require(_amount <= assets[_trader][_symbol].total, "P-TFNE-01");
        assets[_trader][_symbol].total -= _amount;
        if (transaction ==  Tx.EXECUTION) { // The methods that call safeDecrease are already emmiting this event anyways
            emitPortfolioEvent(_trader, _symbol,_amount, 0, transaction);
        }
    }

    // Only called from DEPOSIT/WITHDRAW
    function safeDecrease(address _trader, bytes32 _symbol, uint _amount, Tx transaction) private {
        require(_amount <= assets[_trader][_symbol].available, "P-AFNE-02");
        assets[_trader][_symbol].available -= _amount;
        safeDecreaseTotal(_trader, _symbol, _amount, transaction);
    }

    // Called from DEPOSIT/ WITHDRAW AND ALL OTHER TX
    // WHEN called from DEPOSIT/ WITHDRAW emitEvent = false because for some reason the event has to be raised at the end of the
    // corresponding Deposit/ Withdraw functions to be able to capture the state change in the chain value.
    function safeIncrease(address _trader, bytes32 _symbol, uint _amount, uint _feeCharged, Tx transaction) private {
        require(_amount > 0 && _amount >= _feeCharged, "P-TNEF-01");
        // console.log (bytes32ToString(_symbol), "safeIncrease = Amnt/Fee ", _amount, _feeCharged );
        // console.log (bytes32ToString(_symbol), "safeIncrease Before Total/Avail= ", assets[_trader][_symbol].total, assets[_trader][_symbol].available );
        assets[_trader][_symbol].total += _amount - _feeCharged;
        assets[_trader][_symbol].available += _amount - _feeCharged;
        // console.log (bytes32ToString(_symbol), "safeIncrease After Total/Avail= ", assets[_trader][_symbol].total, assets[_trader][_symbol].available );

        if (_feeCharged > 0 ) {
            safeTransferFee(_symbol, _feeCharged);
        }
        if (transaction != Tx.DEPOSIT && transaction != Tx.WITHDRAW) {
            emitPortfolioEvent(_trader, _symbol, _amount, _feeCharged, transaction);
        }
    }
}