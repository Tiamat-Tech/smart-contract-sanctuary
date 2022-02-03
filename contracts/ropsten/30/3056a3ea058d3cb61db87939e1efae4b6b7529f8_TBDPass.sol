// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

interface ICalculator {
    function price() external view returns (uint256);
}

contract TBDPass is ERC1155, Ownable, ReentrancyGuard {
    using ECDSA for bytes32;

    // - events
    event BurnerStateChanged(address indexed burner, bool indexed newState);
    event ContractToggled(bool indexed newState);
    event FloatingCapUpdated(uint256 indexed newCap);
    event PriceCalculatorUpdated(address indexed calc);
    event VerifiedSignerSet(address indexed signer);

    // - constants
    uint256 public constant PASS_ID = 0;
    uint256 public constant STAGE1_CAP = 2000;                           // initial floating cap
    uint256 public constant RESERVE_CAP = 2000;                          // global limit on the tokens mintable by owner
    uint256 public constant HARD_CAP = 10000;                            // global limit on the tokens mintable by anyone
    uint256 public constant MAX_MINT = 50;                               // global per-account limit of mintable tokens

    uint256 public constant PRICE = .06 ether;                           // initial token price
    uint256 public constant PRICE_INCREMENT = .05 ether;                 // increment it by this amount
    uint256 public constant PRICE_TIER_SIZE = 500;                       // every ... tokens
    address private constant TIP_RECEIVER =
        0xdF9529E6db8f5e4c5192a9D1A70D415B6D1cc3d7;                      //

    // - storage variables; 
    uint256 public totalSupply;                                          // all tokens minted
    uint256 public reserveSupply;                                        // minted by owner; never exceeds RESERVE_CAP
    uint256 public reserveSupplyThisRound;                               // minted by owner this release round, never exceeds reserveCap
    uint256 public reserveCapThisRound;                                  // current reserve cap; never exceeds RESERVE_CAP - reserveSupply 
    uint256 public floatingCap;                                          // current upper boundary of the floating cap; never exceeds HARD_CAP
    uint256 public releasePeriod;                                        // counter of floating cap updates; changing this invalidates wl signatures
    bool public paused;                                                  // control wl minting and at-cost minting
    address public verifiedSigner;                                       // wl requests must be signed by this account 
    ICalculator public calculator;                                       // external price source
    mapping(address => bool) public burners;                             // accounts allowed to burn tokens
    mapping(uint256 => mapping(address => uint256)) public allowances;   // tracked wl allowances for current release cycle
    mapping(address => uint256) public mints;                            // lifetime accumulators for tokens minted


    // TODO: set to actual "https://ourproject.com/{id}/default.json"
    constructor() ERC1155("https://ourproject.com/{id}/default.json") {
        floatingCap = STAGE1_CAP;
    }

    /**
     * @dev Return the current price per token. For the
     *  initial pricing curve, the price returned is always
     *  valid for the purchase that immediately follows.
     *
     *  While it could also be valid for a number of subseq
     *  purchases, this isn't guaranteed, so {price} should
     *  always be consulted before purchase.
     */
    function price() external view returns (uint256) {
        return _price();
    }

    /*
     * @dev Return the remainder of the caller's whitelist allowance
     *  in the current release period.
     */
    function getAllowance() external view returns (uint256) {
        uint256 allowance = allowances[releasePeriod][msg.sender];
        if (allowance > 1) {
            return allowance - 1;
        } else {
            return 0;
        }
    }

    /**
     * @dev Mint tokens at no cost (tx gas overhead) based on a valid signature.
     *  A successful transaction extends the current floating cap by the quantity 
     *  of tokens minted, unless such extension exceeds the global hard cap and/or 
     *  violates the team reserve. If the latter is the case, tokens minted will 
     *  decrease the number of tokens available for at-cost minting as long as such
     *  decrement does not violate the team reserve.
     *
     * @param qt Number of tokens to mint. If 0, instructs the function to mint the 
     *  entire remaining allowance of tokens under the signature presented. If non-zero,
     *  must be within the initial/remaining allowance of tokens under the signature 
     *  presented.
     *
     * @param initialAllowance The total of tokens mintable under this
     *  signature.
     *   
     * @param signature A valid signature produced by `verifiedSigner`. Must
     *  encode `releasePeriod`, `initialAllowance`, and `msg.sender`. A signature
     *  that comes from a different release period, is intended for a different 
     *  msg.sender, or sets a different initial allowance will cause a revert.
     *
     * Note: will revert when the contract is paused.
     * Note: will revert if it's impossible to mint tokens without violating
     *       the team reserve or the caller's lifetime limit (MAX_MINT).
     * Note: it is up to the signing backend to maintain the global cap 
     *       of whitelist mints.
     */
    function whitelistMint(
        uint256 qt,
        uint256 initialAllowance,
        bytes calldata signature
    ) external {
        _whenNotPaused();

        // Signatures from previous `releasePeriod`s will not check out.
        _validSignature(msg.sender, initialAllowance, signature);

        // Set account's allowance on first use of the signature.
        // The +1 offset allows to distinguish between a) first-time
        // call; and b) fully claimed allowance. If the first use tx 
        // executes successfully, ownce never goes below 1. 
        mapping(address => uint256) storage ownce = allowances[releasePeriod];
        if (ownce[msg.sender] == 0) {
            ownce[msg.sender] = initialAllowance + 1;
        }

        // The actual allowance is always ownce -1;
        // must be above 0 to proceed.
        uint256 allowance = ownce[msg.sender] - 1;
        require(allowance > 0, "OutOfAllowance");

        // If the qt requested is 0, mint up to max allowance:
        uint256 qt_ = (qt == 0)? allowance : qt;
        // qt_ is never 0, since if it's 0, it assumes allowance,
        // and that would revert earlier if 0.
        assert(qt_ > 0);
    
        // It is possible, however, that qt is non-zero and exceeds allowance:
        require(qt_ <= allowance, "MintingExceedsAllowance");

        // Observe lifetime per-account limit:
        require(qt_ + mints[msg.sender] <= MAX_MINT, "MintingExceedsLifetimeLimit");

        // In order to assess whether it's cool to extend the floating cap by qt_, 
        // calculate the extension upper bound. The gist: extend as long as 
        // the team's reserve is guarded.
        uint reserveVault = (RESERVE_CAP - reserveSupply) - (reserveCapThisRound - reserveSupplyThisRound);
        uint256 extensionMintable = HARD_CAP - floatingCap - reserveVault;

        // split between over-the-cap supply and at-cost supply
        uint256 mintableAtCost = _mintableAtCost();
        uint256 wlMintable = extensionMintable + mintableAtCost;
        require(qt_ <= wlMintable, "MintingExceedsAvailableSupply");
        
        // adjust fc
        floatingCap += (qt_ > extensionMintable)? extensionMintable : qt_; 

        // decrease caller's allowance in the current period
        ownce[msg.sender] -= qt_;

        _mintN(msg.sender, qt_);
    }

    /**
     * @dev Mint tokens at cost. 
     *
     * @param qt The number of tokens to mint. Must be greater than 0 and lower
     *  than the number of tokens still available for at-cost minting in the current
     *  release period.
     *
     * Note: will revert when the contract is paused.
     * Note: will revert if it's impossible to mint tokens without violating
     *       the caller lifetime limit (MAX_MINT).
     */
    function mint(uint256 qt) external payable {
        _whenNotPaused();
        require(qt > 0, "ZeroTokensRequested");
        require(qt <= _mintableAtCost(), "MintingExceedsFloatingCap");
        require(
            mints[msg.sender] + qt <= MAX_MINT,
            "MintingExceedsLifetimeLimit"
        );
        require(qt * _price() == msg.value, "InvalidETHAmount");
    
        _mintN(msg.sender, qt);
    }


    //
    // RESTRICTED fns
    //
    function withdraw() external {
        _onlyOwner();
        uint256 tip = address(this).balance * 2 / 100;
        payable(TIP_RECEIVER).transfer(tip);
        payable(owner()).transfer(address(this).balance);
    }

    /**
     * @dev Set the address of the price calculator contract to
     *  be used to determine the price of a token.
     *
     * @param calc Contract address. The contract is expected 
     *  to implement ICalculator and use the primary contract's
     *  exposed storage slots to derive the price. Must not be a 
     *  zero address. Since {_price} will prioritize the external
     *  calculator over the default formula, there's no way to 
     *  switch back after the external calculator is set, but
     *  we can always set it to a different calculator.
     *
     * Note: will emit `PriceCalculatorUpdated` on success.
     */
    function setCalculator(address calc) external {
        _onlyOwner();
        require(calc != address(0), "ZeroCalculatorAddress");
        emit PriceCalculatorUpdated(calc);
        calculator = ICalculator(calc);
    }

    /**
     * @dev Set the account allowed to sign whitelist minting requests.
     *
     * @param signer A non-zero signer account address.
     *
     * Note: will emit `VerifiedSignerSet` on success.
     *
     * Note: switching from a previously set signer will invalidate
     *  outstanding signatures for whitelist minting.
     */
    function setVerifiedSigner(address signer) external {
        _onlyOwner();
        require(signer != address(0), "ZeroSignerAddress");
        emit VerifiedSignerSet(signer);
        verifiedSigner = signer;
    }

    /**
     * @dev Advance the release period, update the floating cap, 
     *  and allocate tokens mintable by the team in the new period.
     *  Invalidate outstanding whitelist signatures (due to the period
     *  increment.)
     *
     * @param cap The new floating cap. Must equal or be greater
     *  than the current floating cap. Cannot exceed the hard cap.
     *
     * @param reserve Team reserve allocation. Together with
     *  `reserveSupply` (the actual number of tokens already minted
     *  by the team) must not exceed `RESERVE_CAP`.
     *
     * Note: will emit `FloatingCapUpdated` on success.
     * Note: `cap` and `reserve` taken together cannot violate the
     *       total of the team reserve.
     */
    function setFloatingCap(uint256 cap, uint256 reserve) external {
        _onlyOwner();
        require(reserveSupply + reserve <= RESERVE_CAP, "OwnerReserveExceeded");
        require(cap >= floatingCap, "CapUnderCurrentFloatingCap");
        require(cap <= HARD_CAP, "HardCapExceeded");
        require((RESERVE_CAP - reserveSupply - reserve) <= (HARD_CAP - cap), 
            "OwnerReserveViolation");
        require(cap - totalSupply >= reserve, "ReserveExceedsTokensAvailable");

        reserveCapThisRound = reserve;
        reserveSupplyThisRound = 0;
        emit FloatingCapUpdated(cap);
        floatingCap = cap;
        _nextPeriod();
    }

    /**
     * @dev Reduce team allocation in the current release round.
     *
     * @param to The new allocation cap. Must equal or be greater than the 
     *  number of tokens actually minted by the team in the current round.
     *  Must also be less than the allocation previously set for the round.
     *  If `to` is equal to the number of tokens actually minted in the release
     *  round, effectively releases the rest of the team's supply this round.
     *
     * Note: guards against making owner reserve available for minting through
     *  {whitelistMint} or {mint}.
     */
    function reduceReserve(uint256 to) external {
        _onlyOwner();
        require(to >= reserveSupplyThisRound, "CannotDecreaseBelowMinted");
        require(to < reserveCapThisRound, "CannotIncreaseReserve");
        
        // supply above floatingCap must be still sufficient to compensate
        // for potentially excessive reduction
        uint256 capExcess = HARD_CAP - floatingCap;
        bool reserveViolated = capExcess < (RESERVE_CAP - reserveSupply) - (to - reserveSupplyThisRound);
        require(!reserveViolated, "OwnerReserveViolation");
        
        reserveCapThisRound = to;
    }

    /**
     * @dev Change to a new whitelisting period, invalidating all 
     *  outstanding signatures. Keeps the rest of the run-time params intact.
     */
    function nextPeriod() external {
        _onlyOwner();
        _nextPeriod();
    }

    /**
     * @dev Enable or disable burning of tokens for an external account.
     *
     * @param burner The address to operate on.
     * @param state Enable if `true`, disable otherwise.
     *
     * Note: will emit `BurnerStateChanged` on success.
     */
    function setBurnerState(address burner, bool state) external {
        _onlyOwner();
        require(burner != address(0), "ZeroBurnerAddress");
        emit BurnerStateChanged(burner, state);
        burners[burner] = state;
    }

    /**
     * @dev Burn an amount of tokens held by an account. Only
     *  callable by burners (see {setBurnerState}).
     *
     * @param holder The account to burn tokens for.
     * @param qt The number of tokens to burn.
     *
     * Note: since change in total supply would affect some of the invariants,
     *       we mint an equal amount of tokens to the dead address and keep
     *       the current value of totalSupply.
     */
    function burn(address holder, uint256 qt) external {
        _onlyBurners();
        _burn(holder, PASS_ID, qt);
        _mint(0x000000000000000000000000000000000000dEaD, PASS_ID, qt, "");
    }

    /**
     * @dev Update token URI.
     * 
     * @param uri_ The new URI.
     */
    function setURI(string memory uri_) external {
        _onlyOwner();
        _setURI(uri_);
    }

    /**
     * @dev Pause/resume the contract (minting operations, except the owner's.)
     *
     * Note: will emit `ContractToggled` with new state on success.
     */
    function toggle() external {
        _onlyOwner();
        emit ContractToggled(!paused);
        paused = !paused;
    }

    /**
     * @dev Mint tokens from the team reserve.
     *
     * @param to The (non-zero) destination account. 
     * @param qt The (non-zero) number of tokens to mint. 
     *
     * Note: will revert in the initial release period.
     * Note: will revert if period's allocation is exceeded.
     */
    function teamdrop(address to, uint256 qt) external {
        _onlyOwner();
        require(to != address(0), "ZeroReceiverAddress");
        require(qt > 0, "ZeroTokensRequested");
        require(releasePeriod > 0, "PrematureMintingByOwner");
        require(reserveSupplyThisRound + qt <= reserveCapThisRound, "MintingExceedsRoundReserve");
        reserveSupply += qt;
        reserveSupplyThisRound += qt;
        _mintN(to, qt);
    }

    // - internals
    function _nextPeriod() internal {
        releasePeriod++;
    }

    function _mintN(address to, uint256 qt) internal nonReentrant {
        totalSupply += qt;
        mints[to] += qt;
        _mint(to, PASS_ID, qt, "");
    }

    function _mintableAtCost() internal view returns (uint256) {
        return floatingCap - totalSupply - 
            (reserveCapThisRound - reserveSupplyThisRound);
    }

    function _onlyOwner() internal view {
        require(msg.sender == owner(), "UnauthorizedAccess");
    }

    function _onlyBurners() internal view {
        require(burners[msg.sender], "UnauthorizedAccess");
    }

    function _whenNotPaused() internal view {
        require(!paused, "ContractPaused");
    }

    function _validSignature(
        address account,
        uint256 allowance,
        bytes calldata signature
    ) internal view {
        bytes32 hash = keccak256(
            abi.encodePacked(
                "\x19Ethereum Signed Message:\n32",
                keccak256(abi.encodePacked(account, releasePeriod, allowance))
            )
        );
        require(
            hash.recover(signature) == verifiedSigner,
            "InvalidSignature."
        );
    }

    function _price() internal view returns (uint256 price_) {
        if (calculator != ICalculator(address(0))) {
            price_ = calculator.price();
        } else {
            price_ = PRICE + PRICE_INCREMENT * (totalSupply / PRICE_TIER_SIZE);
        }
    }
}