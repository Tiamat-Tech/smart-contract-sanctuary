// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract IreContract is ERC20, ERC20Burnable, Pausable, AccessControl {
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    uint32 public constant VERSION = 8;

    uint8 private constant DECIMALS = 18;
    uint256 private constant TOKEN_WEI = 10**uint256(DECIMALS);

    uint256 private constant INITIAL_WHOLE_TOKENS = uint256(1.5 * (10**9));
    uint256 private constant INITIAL_SUPPLY =
        uint256(INITIAL_WHOLE_TOKENS) * uint256(TOKEN_WEI);

    uint32 private constant THOUSAND_YEARS_DAYS = 365243; /* See https://www.timeanddate.com/date/durationresult.html?m1=1&d1=1&y1=2000&m2=1&d2=1&y2=3000 */
    uint32 private constant TEN_YEARS_DAYS = THOUSAND_YEARS_DAYS / 100; /* Includes leap years (though it doesn't really matter) */
    uint32 private constant SECONDS_PER_DAY = 24 * 60 * 60; /* 86400 seconds in a day */
    uint32 private constant JAN_1_2000_SECONDS = 946684800; /* Saturday, January 1, 2000 0:00:00 (GMT) (see https://www.epochconverter.com/) */
    uint32 private constant JAN_1_2050_SECONDS = 2524608000; /* Saturday, January 1, 2000 0:00:00 (GMT) (see https://www.epochconverter.com/) */
    uint32 private constant JAN_1_2000_DAYS =
        JAN_1_2000_SECONDS / SECONDS_PER_DAY;
    uint32 private constant JAN_1_3000_DAYS =
        JAN_1_2000_DAYS + THOUSAND_YEARS_DAYS;
    // Day number = Unix epoch time/SECONDS_PER_DAY
    // Test ex: 11/1/2021 = Day number = 18932

    event VestingTokensGranted(
        address beneficiary,
        uint32 startDay, // Day number for Token release.
        uint256 totalTokens,
        uint256 tokensPerDay,
        bool isActive,
        bool wasRevoked,
        uint256 tokensEntitled,
        uint256 tokensReleased
    );
    event Tokens(
        uint256 tgeTokensEntitled,
        uint256 tgeTokensReleased,
        uint256 tokensEntitled,
        uint256 tokensReleased,
        uint256 totalTokensEntitled,
        uint256 totalTokensRelease
    );

    // Strore TGE - 14 Days vesting details
    struct tgeTokenGrant {
        address beneficiary; /* Address of wallet that is holding the vesting schedule. */
        uint32 startDay; /* Start day of the grant, in days since the UNIX epoch (start of day). */
        uint256 tgeTotalTokens; /* Total number of tokens for 14day TGE. */
        uint256 tgeTokensPerDay; /* Number of tokens entitled per day */
        bool isActive; /* true if this vesting entry is active and in-effect entry. */
        bool wasRevoked; /* true if this vesting schedule was revoked. */
        uint256 tgeTokensEntitled; // Already entitled
        uint256 tgeTokensReleased; // Tokens already release to investor.
    }

    // Strore Normal cliff and vesting details
    struct tokenGrant {
        address beneficiary; /* Address of wallet that is holding the vesting schedule. */
        uint32 startDay; /* Start day of the grant, in days since the UNIX epoch (start of day). */
        uint256 totalTokens; /* Total number of tokens for normal vest. */
        uint256 tokensPerDay; /* Number of tokens can be entitled per day. */
        bool isActive; /* true if this vesting entry is active and in-effect entry. */
        bool wasRevoked; /* true if this vesting schedule was revoked. */
        uint256 tokensEntitled; // Already entitled
        uint256 tokensReleased; // Tokens already release to investor.
    }

    mapping(address => tokenGrant) private _tokenGrants; // Store normal  vesting tokens by address.
    mapping(address => tgeTokenGrant) private _tgeTokenGrants; // TGE vesting tokens by address.
    mapping(address => bool) private _isRegistered;

    constructor() ERC20("5IRE", "5IRE5") {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(PAUSER_ROLE, msg.sender);
        _setupRole(MINTER_ROLE, msg.sender);
        _mint(msg.sender, INITIAL_SUPPLY);
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    // function _beforeTokenTransfer(
    //     address from,
    //     address to,
    //     uint256 amount
    // ) internal override whenNotPaused {
    //     super._beforeTokenTransfer(from, to, amount);
    // }

    // function grantMultipleVestingTokens(){

    // }

    // Add the single investor to struct
    function grantVestingTokens(
        uint8 tgeGrant,
        address beneficiary,
        uint32 startDay,
        uint256 totalTokens,
        uint256 tokensPerDay,
        uint256 tokensEntitled,
        uint256 tokensReleased
    ) public onlyRole(DEFAULT_ADMIN_ROLE) returns (bool ok) {
        // Make sure no prior vesting schedule has been set.
        if (tgeGrant == 1) {
            require(
                !_tgeTokenGrants[beneficiary].isActive,
                "tge grant already exists"
            );
        } else {
            require(
                !_tokenGrants[beneficiary].isActive,
                "grant already exists"
            );
        }

        // Issue grantor tokens to the beneficiary, using beneficiary's own vesting schedule.
        _grantVestingTokens(
            tgeGrant,
            beneficiary,
            startDay,
            totalTokens,
            tokensPerDay,
            tokensEntitled,
            tokensReleased
        );
        return true;
    }

    function _grantVestingTokens(
        uint8 tgeGrant,
        address beneficiary,
        uint32 startDay,
        uint256 totalTokens,
        uint256 tokensPerDay,
        uint256 tokensEntitled,
        uint256 tokensReleased
    ) internal returns (bool ok) {
        // Make sure no prior grant is in effect.
        //require(!_tokenGrants[beneficiary].isActive, "grant already exists");
        // Check for valid vestingTokens
        require(
            tokensPerDay <= totalTokens &&
                totalTokens > 0 &&
                startDay >= JAN_1_2000_DAYS &&
                startDay < JAN_1_3000_DAYS,
            "invalid vesting params"
        );

        // Create and populate a token grant, referencing vesting schedule.
        if (tgeGrant == 0) {
            _tokenGrants[beneficiary] = tokenGrant(
                beneficiary,
                startDay,
                totalTokens,
                tokensPerDay,
                true, /*isActive*/
                false, /*wasRevoked*/
                tokensEntitled,
                tokensReleased
            );
        } else {
            _tgeTokenGrants[beneficiary] = tgeTokenGrant(
                beneficiary,
                startDay,
                totalTokens,
                tokensPerDay,
                true, /*isActive*/
                false, /*wasRevoked*/
                tokensEntitled,
                tokensReleased
            );
        }

        // Emit the event and return success.
        emit VestingTokensGranted(
            beneficiary,
            startDay,
            totalTokens,
            tokensPerDay,
            true, /*isActive*/
            false, /*wasRevoked*/
            tokensEntitled,
            tokensReleased
        );
        return true;
    }

    // Calculate entitled and released tokens.
    function viewEntitledTGETokensAsOf(address beneficiary, uint32 onDayOrToday)
        public
        view
        returns (
            uint32 startDay,
            uint256 totalTokens,
            uint256 tokensPerDay,
            bool isActive,
            bool wasRevoked,
            uint256 tokensEntitled,
            uint256 tokensReleased
        )
    {
        //tokenGrant storage grant = _tokenGrants[beneficiary];
        if (_tgeTokenGrants[beneficiary].beneficiary != address(0x0)) {
            tgeTokenGrant memory grant = _tgeTokenGrants[beneficiary];
            // Compute the exact number of days vested.
            uint32 onDay = _effectiveDay(onDayOrToday);
            uint32 daysVested = onDay - grant.startDay;
            uint256 _tokensEntitled = (daysVested * grant.tgeTokensPerDay);
            uint256 _tokensReleased = grant.tgeTokensReleased;
            return (
                grant.startDay,
                grant.tgeTotalTokens,
                grant.tgeTokensPerDay,
                grant.isActive,
                grant.wasRevoked,
                _tokensEntitled,
                _tokensReleased
            );
        } else {
            uint32 day = 0;
            uint256 tokens = 0;
            return (day, tokens, tokens, false, false, tokens, tokens);
        }
    }

    // Calculate entitled and released tokens.
    function viewEntitledTokensAsOf(address beneficiary, uint32 onDayOrToday)
        public
        view
        returns (
            uint32 startDay,
            uint256 totalTokens,
            uint256 tokensPerDay,
            bool isActive,
            bool wasRevoked,
            uint256 tokensEntitled,
            uint256 tokensReleased
        )
    {
        if (_tokenGrants[beneficiary].beneficiary != address(0x0)) {
            tokenGrant memory grant = _tokenGrants[beneficiary];
            // Compute the exact number of days vested.
            uint32 onDay = _effectiveDay(onDayOrToday);
            uint32 daysVested = onDay - grant.startDay;
            uint256 _tokensEntitled = (daysVested * grant.tokensPerDay);
            uint256 _tokensReleased = grant.tokensReleased;
            return (
                grant.startDay,
                grant.totalTokens,
                grant.tokensPerDay,
                grant.isActive,
                grant.wasRevoked,
                _tokensEntitled,
                _tokensReleased
            );
        } else {
            uint32 day = 0;
            uint256 tokens = 0;
            return (day, tokens, tokens, false, false, tokens, tokens);
        }
    }

    function today() public view returns (uint32 dayNumber) {
        return uint32(block.timestamp / SECONDS_PER_DAY);
    }

    function _effectiveDay(uint32 onDayOrToday)
        internal
        view
        returns (uint32 dayNumber)
    {
        return onDayOrToday == 0 ? today() : onDayOrToday;
    }

    function releaseEntitledTokens(address beneficiary, uint256 tokens)
        public
        returns (string memory)
    {
        uint256 _totalTokensEntitled = 0;
        uint256 _totalTokensRelease = 0;

        uint256 _tgeTokensEntitled = 0;
        uint256 _tgeTokensReleased = 0;

        uint256 _tokensEntitled = 0;
        uint256 _tokensReleased = 0;

        uint32 onDay = today();
        if (_tgeTokenGrants[beneficiary].beneficiary != address(0x0)) {
            tgeTokenGrant memory grant = _tgeTokenGrants[beneficiary];
            // Compute the exact number of days vested.
            uint32 daysVested = onDay - grant.startDay;
            _tgeTokensEntitled = (daysVested * grant.tgeTokensPerDay);
            _tgeTokensReleased = grant.tgeTokensReleased;
        }

        if (_tokenGrants[beneficiary].beneficiary != address(0x0)) {
            tokenGrant memory grant = _tokenGrants[beneficiary];
            uint32 daysVested = onDay - grant.startDay;
            _tokensEntitled = (daysVested * grant.tokensPerDay);
            _tokensReleased = grant.tokensReleased;
        }
        _totalTokensEntitled = _tgeTokensEntitled + _tokensEntitled;
        _totalTokensRelease = _tgeTokensReleased + _tokensReleased;
        if ((_totalTokensEntitled - _totalTokensRelease) >= tokens) {
            emit Tokens(
                _tgeTokensEntitled,
                _tgeTokensReleased,
                _tokensEntitled,
                _tokensReleased,
                _totalTokensEntitled,
                _totalTokensRelease
            );
            bool txnTransfer = transfer(beneficiary, tokens);
            if (txnTransfer) {
                if ((_tgeTokensReleased + tokens) > _tgeTokensEntitled) {
                    _tgeTokenGrants[beneficiary]
                        .tgeTokensReleased = _tgeTokensEntitled;
                    _tokenGrants[beneficiary].tokensReleased =
                        _tokensReleased +
                        tokens -
                        (_tgeTokensEntitled - _tgeTokensReleased);
                } else {
                    _tgeTokenGrants[beneficiary].tgeTokensReleased =
                        _tgeTokensReleased +
                        tokens;
                }
            }
            return "Tokens transfered.";
        } else {
            return "Tokens not transfered.";
        }
    }

    function grantMultipleTgeVestingTokens(tgeTokenGrant[] memory tokenGrantArr)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
        returns (bool ok)
    {
        // Make sure no prior vesting schedule has been set.
        for (uint256 i = 0; i < tokenGrantArr.length; i++) {
            tgeTokenGrant memory grant = tokenGrantArr[i];
            require(
                !_tgeTokenGrants[grant.beneficiary].isActive,
                "tge grant already exists"
            );
            require(
                grant.tgeTokensPerDay <= grant.tgeTotalTokens &&
                    grant.tgeTokensPerDay > 0 &&
                    grant.startDay >= JAN_1_2000_DAYS &&
                    grant.startDay < JAN_1_3000_DAYS,
                "invalid vesting params"
            );
        }
        // Issue grantor tokens to the beneficiary, using beneficiary's own vesting schedule.
        _grantMultipleTgeVestingTokens(tokenGrantArr);
        return true;
    }

    // Make sure no prior grant is in effect.
    //require(!_tokenGrants[beneficiary].isActive, "grant already exists");
    // Check for valid vestingTokens
    function _grantMultipleTgeVestingTokens(
        tgeTokenGrant[] memory tokenGrantArr
    ) internal {
        for (uint256 i = 0; i < tokenGrantArr.length; i++) {
            tgeTokenGrant memory grant = tokenGrantArr[i];
            _tgeTokenGrants[grant.beneficiary] = grant;
        }
    }

    function grantMultipleVestingTokens(tokenGrant[] memory tokenGrantArr)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
        returns (bool ok)
    {
        // Make sure no prior vesting schedule has been set.
        for (uint256 i = 0; i < tokenGrantArr.length; i++) {
            tokenGrant memory grant = tokenGrantArr[i];
            require(
                !_tokenGrants[grant.beneficiary].isActive,
                "tge grant already exists"
            );
            require(
                grant.tokensPerDay <= grant.totalTokens &&
                    grant.tokensPerDay > 0 &&
                    grant.startDay >= JAN_1_2000_DAYS &&
                    grant.startDay < JAN_1_3000_DAYS,
                "invalid vesting params"
            );
        }
        // Issue grantor tokens to the beneficiary, using beneficiary's own vesting schedule.
        _grantMultipleVestingTokens(tokenGrantArr);
        return true;
    }

    // Make sure no prior grant is in effect.
    //require(!_tokenGrants[beneficiary].isActive, "grant already exists");
    // Check for valid vestingTokens
    function _grantMultipleVestingTokens(tokenGrant[] memory tokenGrantArr)
        internal
    {
        for (uint256 i = 0; i < tokenGrantArr.length; i++) {
            tokenGrant memory grant = tokenGrantArr[i];
            _tokenGrants[grant.beneficiary] = grant;
        }
    }
}