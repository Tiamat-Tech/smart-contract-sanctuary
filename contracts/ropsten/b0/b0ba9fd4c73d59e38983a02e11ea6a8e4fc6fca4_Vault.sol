//SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0;
import "../interfaces/IVault.sol";
import "../interfaces/IRhoStrategy.sol";
import "../interfaces/ICERC20.sol";
import "../rhoTokens/RhoToken.sol";
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "hardhat/console.sol";

contract Vault is IVault, PausableUpgradeable, AccessControlEnumerableUpgradeable {

    using SafeERC20Upgradeable for IERC20MetadataUpgradeable;
    RhoToken private _rho;
    IERC20MetadataUpgradeable private _underlying;
    struct Strategy {
        string name;
        address at;
        bool enabled;
    }


    uint256 private _rhoOne;
    uint256 private _underlyingOne;

    // 18 decimal
    uint256 private _mFee;
    // 18 decimal
    uint256 private _rFee;
    // 18 decimal
    uint256 private _reserveUpperBound;
    // 18 decimal
    uint256 private _reserveLowerBound;

    Strategy[] public strategies;

    uint256 private _initialBlockNumber;

    bytes32 public constant REBASE_ROLE = keccak256("REBASE_ROLE");
    bytes32 public constant FEE_MNG_ROLE = keccak256("FEE_MNG_ROLE");
    bytes32 public constant THRESHOLD_MNG_ROLE = keccak256("THRESHOLD_MNG_ROLE");
    bytes32 public constant ALLOCATION_MNG_ROLE = keccak256("ALLOCATION_MNG_ROLE");
    bytes32 public constant STRATEGY_MNG_ROLE = keccak256("STRATEGY_MNG_ROLE");
    bytes32 public constant PAUSE_ROLE = keccak256("PAUSE_ROLE");
    bytes32 public constant SWEEPER_ROLE = keccak256("SWEEPER_ROLE");

    uint256 public feeInRho;
    // 18 decimal
    uint256 private _managementFee;


    function initialize(address _rhoAddr, address _underlyingAddr, uint256 _mintingFee, uint256 _redeemFee, uint256 _mngtFee, uint256 _rLowerBound, uint256 _rUpperBound ) public initializer {
        PausableUpgradeable.__Pausable_init();
        AccessControlEnumerableUpgradeable.__AccessControlEnumerable_init();

        _setMintingFee(_mintingFee);
        _setRedeemFee(_redeemFee);
        _setManagementFee(_mngtFee);
        _setReserveBoundary(_rLowerBound, _rUpperBound);
        _setRhoToken(_rhoAddr);
        _setUnderlying(_underlyingAddr);
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _initialBlockNumber = block.number;
    }


    /* minting Fee */
    function mintingFee() external view override returns (uint256) {
        return _mFee;
    }
    function setMintingFee(uint256 _feeInBps) external override onlyRole(FEE_MNG_ROLE) whenNotPaused {
        _setMintingFee(_feeInBps);
    }
    function _setMintingFee(uint256 _feeInBps) internal {
        _mFee = _feeInBps;
    }


    /* redeem Fee */
    function redeemFee() external override view returns (uint256) {
        return _rFee;
    }
    function setRedeemFee(uint256 _feeInBps) external override onlyRole(FEE_MNG_ROLE) whenNotPaused {
        _setRedeemFee(_feeInBps);
    }
    function _setRedeemFee(uint256 _feeInBps) internal {
        _rFee = _feeInBps;
    }
    function setManagementFee(uint256 _feeInBps) external override onlyRole(FEE_MNG_ROLE) whenNotPaused {
        _setManagementFee(_feeInBps);
    }
    function _setManagementFee(uint256 _feeInBps) internal {
        _managementFee = _feeInBps;
    }
    function managementFee() external view override returns (uint256) {
        return _managementFee;
    }

    /* alloc threshold */
    function reserveBoundary() external override view returns (uint256, uint256){
        return (_reserveLowerBound, _reserveUpperBound);
    }
    function setReserveBoundary(uint256 reserveLowerBound_, uint256 reserveUpperBound_) external override onlyRole(THRESHOLD_MNG_ROLE) whenNotPaused {
        _setReserveBoundary(reserveLowerBound_, reserveUpperBound_);
    }
    function _setReserveBoundary(uint256 reserveLowerBound_, uint256 reserveUpperBound_) internal {
        _reserveLowerBound = reserveLowerBound_;
        _reserveUpperBound = reserveUpperBound_;
    }


    /* underlying */
    function _setUnderlying(address _addr) internal {
        _underlying = IERC20MetadataUpgradeable(_addr);
        _underlyingOne = 10**_underlying.decimals();
    }
    function underlyingAsset() external override view returns (address) {
        return address(_underlying);
    }
    function supportsAsset(address _asset) external override view returns (bool) {
        if (_asset == address(_underlying)) { return true; }
        return false;
    }

    /* rho token */
    function rhoToken() external override view returns (address) {
        return address(_rho);
    }
    function _setRhoToken(address _addr) internal {
        _rho = RhoToken(_addr);
        _rhoOne = 10**_rho.decimals();
    }

    /* distribution */
    function mint(uint256 amount) external override whenNotPaused {
        _underlying.safeTransferFrom(_msgSender(), address(this), amount);
        uint256 amountInRho = amount * _rhoOne / _underlyingOne;
        _rho.mint(_msgSender(), amountInRho);
        return;
    }
    function redeem(uint256 amount) external override whenNotPaused {
        uint256 reserveBalance = _underlying.balanceOf(address(this));
        uint256 amountInRho = amount * _rhoOne / _underlyingOne;
        if ( reserveBalance >= amount) {
            _rho.burn(_msgSender(), amountInRho);
            _underlying.safeTransfer(_msgSender(), amount);
            return;
        }
        // reserveBalance hit zero, unallocate to replenish reserveBalance to lower bound
        uint256 totalSupplyToBe = _rho.totalSupply() - amountInRho;
        uint256 diff = amount - reserveBalance + _calcLowerBoundReserve(totalSupplyToBe);  // in underlying
        _unallocate(diff);
        _rho.burn(_msgSender(), amountInRho);
        _underlying.safeTransfer(_msgSender(), amount);
    }
    /* asset management */
    function rebase() external override onlyRole(REBASE_ROLE) whenNotPaused {
        // rebalance fund
        _rebalance();
        uint256 underlyingUninvested = _underlying.balanceOf(address(this));
        uint256 underlyingInvested = IRhoStrategy(strategies[0].at).balanceOfUnderlying();
        uint256 currentTvlInUSDT = underlyingUninvested + underlyingInvested;
        uint256 currentTvlInRho = currentTvlInUSDT * _rhoOne / _underlyingOne;
        uint256 rhoRebasing = _rho.rebasingSupply();
        uint256 rhoNonRebasing = _rho.nonRebasingSupply();
        uint256 originalTvlInRho = _rho.totalSupply();
        if (currentTvlInRho == originalTvlInRho) {
            // no fees charged, multiplier does not change
            return;
        }
        if(currentTvlInRho < originalTvlInRho) {
            // this happens when fund is initially deployed to compound and get balance of underlying right away
            // strategy losing money, no fees will be charged
            uint256 _newM = ( currentTvlInRho - rhoNonRebasing ) * 1e36 / rhoRebasing;
            _rho.setMultiplier(_newM);
            return;
        }

        uint256 fee36 = (currentTvlInRho - originalTvlInRho) * _managementFee;
        uint256 fee18 = fee36 / 1e18;
        if (fee18 > 0) {
            // mint vault's fee18
            _rho.mint(address(this), fee18);
            feeInRho += fee18;
        }
        uint256 newM = ( currentTvlInRho * 1e18  - rhoNonRebasing * 1e18 - fee36 )  * 1e18 / rhoRebasing;
        _rho.setMultiplier(newM);
    }

    function rebalance() external override onlyRole(REBASE_ROLE) whenNotPaused {
        _rebalance();
    }

    function _rebalance() internal {
        uint256 underlyingUninvested = _underlying.balanceOf(address(this));
        uint256 rhoTotalSupply = _rho.totalSupply(); // totalSupply = rhoRebasing * multiplier + rhoNonRebasing
        uint256 uninvestedPerTotal = ( underlyingUninvested * 1e18 / _underlyingOne ) * _rhoOne / (rhoTotalSupply);
        if (uninvestedPerTotal > _reserveUpperBound) {
            // allocate such that reserve would be just at _reserveLowerBound
            uint256 amount = underlyingUninvested - _calcLowerBoundReserve(rhoTotalSupply);
            _allocate(amount);
            return;
        }
        if (uninvestedPerTotal == 0) {
            // unallocate such that reserve would be just at _reserveLowerBound
            uint256 amount = _calcLowerBoundReserve(rhoTotalSupply) - underlyingUninvested;
            _unallocate(amount);
        }

    }

    // calculates underlying reserve at upper bound based on a rho total supply
    function _calcUpperBoundReserve(uint256 rhoTotalSupply) internal view returns (uint256) {
        return (rhoTotalSupply * _reserveUpperBound / 1e18) * _underlyingOne / _rhoOne;
    }

    // calculates underlying reserve at lower bound based on a rho total supply
    function _calcLowerBoundReserve(uint256 rhoTotalSupply) internal view returns (uint256) {
        return (rhoTotalSupply * _reserveLowerBound / 1e18) * _underlyingOne / _rhoOne;
    }

    function _unallocate(uint256 amount) internal {
        // TODO: loop through strategies
        IRhoStrategy(strategies[0].at).withdrawUnderlying(amount);
    }
    function _allocate(uint256 amount) internal {
        // TODO: loop through strategies
        _underlying.safeTransfer(strategies[0].at, amount);
        IRhoStrategy(strategies[0].at).deploy(amount);
    }

    function addStrategy(string memory name, address s, bool enabled) external override onlyRole(STRATEGY_MNG_ROLE) whenNotPaused {
        strategies.push(Strategy(name, s, enabled));
    }
    function disableStrategy(uint256 index) external override onlyRole(STRATEGY_MNG_ROLE) whenNotPaused {
        strategies[index].enabled = false;
    }
    function enableStrategy(uint256 index) external override onlyRole(STRATEGY_MNG_ROLE) whenNotPaused {
        strategies[index].enabled = true;
    }

    /* pause */
    function pause() external onlyRole(PAUSE_ROLE) {
        _pause();
    }
    function unpause() external onlyRole(PAUSE_ROLE) {
        _unpause();
    }

    // withdraw random token transfer into this contract
    function sweepERC20Token(address token ,address to)external override onlyRole(SWEEPER_ROLE) whenNotPaused{
        require(token != address(_underlying), "!safe");
        IERC20Upgradeable tokenToSweep = IERC20Upgradeable(token);
        tokenToSweep.transfer(to, tokenToSweep.balanceOf(address(this)));
    }

    function sweepRhoTokenContractERC20Token(address token, address to) external override onlyRole(SWEEPER_ROLE) whenNotPaused{
        _rho.sweepERC20Token(token,to);
    }
    function getSupplyRate() external view returns (uint256) {
        uint256 rebasingSupply = _rho.rebasingSupply(); // in 18
        if (rebasingSupply == 0) {
            return 0;
        }
        uint256 invested = IRhoStrategy(strategies[0].at).balanceOfUnderlyingStored(); // in 6 + 18
        uint256 APY = IRhoStrategy(strategies[0].at).getSupplyRate(); // in 18
        // uint256 totalInterestPA = invested * APY / 1e18; // in 6
        uint256 result = (invested * APY) / rebasingSupply / _underlyingOne; // in 18
        return result;
    }
}