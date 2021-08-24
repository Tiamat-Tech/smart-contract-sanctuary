// SPDX-License-Identifier: GPL-2.0-only
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

import "./Verifier.sol";

struct StockGrantData {
    // Timestamp at which the grant was issued and at which any vesting begins,
    // as seconds since Unix epoch (as with `block.timestamp`).
    uint64 issuedAtTimestamp;
    // Number of seconds after issuance that must elapse before any shares can
    // be claimed. May be zero, in which case there is naturally no lock.
    uint64 lockDuration;
    // Number of seconds that must elapse after issuance before shares can
    // start vesting. May be zero, in which case there is naturally no cliff.
    uint64 cliffDuration;
    // Number of seconds over which this grant vests, starting from the
    // issuance timestamp. May be zero, in which the grant vests fully as soon
    // as `issuedAtTimestamp` is reached. In any case, the first timestamp at
    // which the grant is fully vested is `issuedAtTimestamp + vestDuration`.
    //
    // In particular, if the current time is `t` seconds after epoch, then the
    // proportion of shares that have vested (ignoring any vesting cliff or
    // cancellation) is:
    //
    //   - `0.0` if `t < issuedAtTimestamp`, else:
    //   - `1.0` if `vestDuration == 0`, else:
    //   - `min((t - issuedAtTimestamp) / vestDuration, 1)`.
    uint64 vestDuration;
    // Timestamp at which vesting ceased, as seconds since Unix epoch, or zero
    // if vesting has not ceased. Past this timestamp, no further vesting
    // occurs, and the remaining stock is reclaimed by the issuer.
    uint64 vestingCancellationTimestamp;
    // The full amount of stock in the grant.
    uint256 amount;
    // The amount that has already been claimed.
    uint256 redeemed;
    // The id of the stock series this grant vests into.
    uint256 seriesId;
}

struct StockSeries {
    string name;
    string symbol;
    uint256 authorized;
    uint256 issued;
    UnrestrictedStock unrestricted;
}

struct SeriesBalance {
    uint256 id;
    uint256 transferRestrictedBalance;
    uint256 unrestrictedBalance;
}

contract Corporation {
    event SuperuserChanged(address indexed superuser, bool indexed empowered);
    event VerifierChanged(
        Verifier indexed newVerifier,
        Verifier indexed oldVerifier
    );
    event SeriesCreated(
        uint256 indexed seriesId,
        string indexed symbol,
        string name,
        UnrestrictedStock unrestricted
    );
    event StockAuthorized(
        uint256 indexed seriesId,
        uint256 additionalAuthorization
    );
    event StockGrantIssued(
        uint256 indexed seriesId, // redundant w/ data, included for indexing
        address indexed owner,
        StockGrantData data,
        uint256 indexed tokenId
    );
    event StockGrantClaimed(
        uint256 indexed seriesId,
        address indexed owner,
        uint256 indexed tokenId,
        uint256 amount
    );
    event NameChanged(string indexed newName, string indexed oldName);
    event SymbolChanged(string indexed newSymbol, string indexed oldSymbol);

    // Superusers are authorized to make unilateral changes, such as
    // reassigning tokens when the original real-world owner has lost their
    // keys.
    mapping(address => bool) public isSuperuser;

    Verifier public verifier;

    uint256 nextSeriesId;
    mapping(uint256 => StockSeries) series;

    StockGrants public stockGrants;

    string public metadataURI;
    string public name;
    string public symbol;

    constructor() {
        isSuperuser[msg.sender] = true;
        stockGrants = new StockGrants();
        stockGrants.initialize(this);
    }

    function setName(string calldata _newName) external {
        require(isSuperuser[msg.sender], "Corporation: unauthorized setName");
        emit NameChanged({newName: _newName, oldName: name});
        name = _newName;
    }

    function setSymbol(string calldata _newSymbol) external {
        require(isSuperuser[msg.sender], "Corporation: unauthorized setSymbol");
        emit SymbolChanged({newSymbol: _newSymbol, oldSymbol: symbol});
        symbol = _newSymbol;
    }

    function setSuperuser(address _operator, bool _empowered) external {
        require(
            isSuperuser[msg.sender],
            "Corporation: unauthorized setSuperuser"
        );
        isSuperuser[_operator] = _empowered;
        emit SuperuserChanged({superuser: _operator, empowered: _empowered});
    }

    function setVerifier(Verifier _verifier) external {
        require(
            isSuperuser[msg.sender],
            "Corporation: unauthorized setVerifier"
        );
        emit VerifierChanged({newVerifier: (_verifier), oldVerifier: verifier});
        verifier = _verifier;
    }

    function setMetadataURI(string calldata _metadataURI) external {
        require(
            isSuperuser[msg.sender],
            "Corporation: unauthorized setMetadataURI"
        );
        metadataURI = _metadataURI;
    }

    function createSeries(string memory _name, string memory _symbol)
        external
        returns (uint256 _seriesId, UnrestrictedStock)
    {
        require(bytes(_name).length > 0, "Corporation: no name");
        require(
            isSuperuser[msg.sender],
            "Corporation: unauthorized createSeries"
        );
        _seriesId = nextSeriesId++;
        UnrestrictedStock _unrestricted = new UnrestrictedStock();
        series[_seriesId] = StockSeries({
            name: _name,
            symbol: _symbol,
            authorized: 0,
            issued: 0,
            unrestricted: _unrestricted
        });
        _unrestricted.initialize(this, _seriesId);
        emit SeriesCreated({
            seriesId: _seriesId,
            name: _name,
            symbol: _symbol,
            unrestricted: _unrestricted
        });
        return (_seriesId, _unrestricted);
    }

    // Checks whether an address is permitted to receive shares of a series of
    // stock. Called by `UnrestrictedStock` on each token transfer.
    function mayReceive(address _who) external view returns (bool) {
        return verifier.mayReceive(_who);
    }

    function authorize(uint256 _seriesId, uint256 _additionalAuthorization)
        external
    {
        require(isSuperuser[msg.sender], "Corporation: unauthorized authorize");
        StockSeries storage _series = series[_seriesId];
        require(bytes(_series.name).length > 0, "Corporation: no such series");
        _series.authorized += _additionalAuthorization;
        emit StockAuthorized({
            seriesId: _seriesId,
            additionalAuthorization: _additionalAuthorization
        });
    }

    function mintStockGrant(address _who, StockGrantData memory _data)
        external
        returns (uint256)
    {
        require(
            verifier.mayReceive(_who),
            "Corporation: unauthorized recipient"
        );
        return uncheckedMintStockGrant(_who, _data);
    }

    function uncheckedMintStockGrant(address _who, StockGrantData memory _data)
        public
        returns (uint256)
    {
        require(isSuperuser[msg.sender], "Corporation: unauthorized mint");
        uint256 _seriesId = _data.seriesId;
        StockSeries storage _series = series[_seriesId];
        uint256 _newIssued = series[_seriesId].issued + _data.amount;
        require(_newIssued <= _series.authorized, "Corporation: overissuance");
        series[_seriesId].issued = _newIssued;
        uint256 _tokenId = stockGrants.mint(_who, _data);
        emit StockGrantIssued({
            seriesId: _seriesId,
            owner: _who,
            data: _data,
            tokenId: _tokenId
        });
        return _tokenId;
    }

    function claimStockGrant(uint256 _tokenId) external {
        (address _owner, uint256 _amount, uint256 _seriesId) = stockGrants
        .claim(msg.sender, _tokenId);
        StockSeries storage _series = series[_seriesId];
        _series.unrestricted.mintFromClaim(_owner, _amount);
        emit StockGrantClaimed({
            seriesId: _seriesId,
            owner: _owner,
            tokenId: _tokenId,
            amount: _amount
        });
    }

    function stockBalancesOf(address _owner)
        external
        view
        returns (SeriesBalance[] memory)
    {
        SeriesBalance[] memory _result = new SeriesBalance[](nextSeriesId);
        uint256 _nextSeriesId = nextSeriesId;
        for (uint256 _i = 0; _i < _nextSeriesId; _i++) {
            StockSeries memory _series = series[_i];
            SeriesBalance memory _next = _result[_i];
            _next.id = _i;
            _next.unrestrictedBalance = _series.unrestricted.balanceOf(_owner);
            _next.transferRestrictedBalance = stockGrants.stockBalancePerSeries(
                _owner,
                _i
            );
        }
        return _result;
    }

    function numSeries() external view returns (uint256) {
        return nextSeriesId;
    }

    function seriesByIndex(uint256 _index)
        external
        view
        returns (StockSeries memory)
    {
        return series[_index];
    }

    function nameForSeries(uint256 _id) external view returns (string memory) {
        return string(abi.encodePacked(name, ": ", series[_id].name));
    }

    function symbolForSeries(uint256 _id)
        external
        view
        returns (string memory)
    {
        return string(abi.encodePacked(symbol, ":", series[_id].symbol));
    }
}

contract WhitelistVerifier is Verifier {
    address admin;
    mapping(address => bool) public override mayReceive;

    constructor() {
        admin = msg.sender;
    }

    function setMayReceive(address _who, bool _mayReceive) external {
        require(msg.sender == admin, "WhitelistVerifier: unauthorized");
        mayReceive[_who] = _mayReceive;
    }
}

contract UnrestrictedStock is ERC20 {
    bool initialized;
    Corporation corp;

    uint256 seriesId;

    // TODO(@wchargin): Make name and symbol configurable at corporation level.
    constructor() ERC20("", "") {}

    function name() public view override returns (string memory) {
        return corp.nameForSeries(seriesId);
    }

    function symbol() public view override returns (string memory) {
        return corp.symbolForSeries(seriesId);
    }

    function initialize(Corporation _corp, uint256 _seriesId) external {
        require(!initialized, "UnrestrictedStock: already initialized");
        initialized = true;

        corp = _corp;
        seriesId = _seriesId;
    }

    // Mints new shares of unrestricted stock from a stock grant.
    // Can only be called by the `corp` contract.
    function mintFromClaim(address _recipient, uint256 _amount) external {
        require(
            msg.sender == address(corp),
            "UnrestrictedStock: unauthorized mintFromClaim"
        );
        _mint(_recipient, _amount);
    }

    function _beforeTokenTransfer(
        address _from,
        address _to,
        uint256 _amount
    ) internal virtual override {
        _amount;
        if (_from == address(0)) {
            // Minting entails conversion of restricted stock to unrestricted
            // stock, so is not actually a transfer of any asset, and is
            // therefore always permitted.
            return;
        }
        require(
            corp.mayReceive(_to),
            "UnrestrictedStock: unaccredited recipient"
        );
    }
}

// Records all Transfer-Restricted stock grants. These are stock grants (of
// a particular series) which are owned by the owner, but cannot be unlocked
// and freely transferred until the specified unlock timestamp.
contract StockGrants is ERC721Enumerable {
    bool initialized;
    Corporation corp;
    // If this flag is set, the next token transfer will be unconditionally
    // permitted, and this flag will be cleared. Used to permit superusers to
    // correct stock records.
    bool nextTransferOverride;

    uint256 nextTokenId;
    // Mapping from token ID to RSU data.
    mapping(uint256 => StockGrantData) public tokenInfo;

    // Map from address to series ID to the number of unredeemed shares owned
    // by the address in all grants for this series.
    //
    // ```
    // stockBalancePerSeries[_who][_series] = sum(
    //     grant.amount - grant.redeemed
    //     for (tokenId, grant) in tokenInfo
    //     if ownerOf(tokenId) == _who and grant.seriesId == _series
    // )
    // ```
    mapping(address => mapping(uint256 => uint256))
        public stockBalancePerSeries;

    constructor() ERC721("", "") {}

    function name() public view override returns (string memory) {
        return string(abi.encodePacked(corp.name(), ": StockGrants"));
    }

    function symbol() public view override returns (string memory) {
        return string(abi.encodePacked(corp.symbol(), "[GRANT]"));
    }

    function initialize(Corporation _corp) external {
        require(!initialized, "StockGrant: already initialized");
        initialized = true;

        corp = _corp;
    }

    // Issues new restricted stock. Can only be called by the superuser.
    function mint(address _who, StockGrantData memory _data)
        external
        returns (uint256)
    {
        require(msg.sender == address(corp), "StockGrant: unauthorized mint");
        uint256 _tokenId = nextTokenId++;
        require(_data.redeemed == 0, "StockGrant: pre-redeemed grant");
        tokenInfo[_tokenId] = _data;
        _safeMint(_who, _tokenId);
        return _tokenId;
    }

    // Claims stock from a grant.
    // Can only be called by the `corp` contract.
    function claim(address _operator, uint256 _tokenId)
        external
        returns (
            address _owner,
            uint256 _amount,
            uint256 _seriesId
        )
    {
        require(msg.sender == address(corp), "StockGrant: unauthorized claim");
        require(
            _isApprovedOrOwner(_operator, _tokenId) ||
                corp.isSuperuser(_operator),
            "StockGrant: unauthorized claim"
        );
        _owner = ownerOf(_tokenId);
        StockGrantData memory _grant = tokenInfo[_tokenId];

        uint256 _unlocked = computeUnlockAmount(
            uint64(block.timestamp),
            _grant
        );
        uint256 _toTransfer = _unlocked - _grant.redeemed;
        stockBalancePerSeries[_owner][_grant.seriesId] -= _toTransfer;

        if (_unlocked == _grant.amount) {
            delete tokenInfo[_tokenId];
            _burn(_tokenId);
        } else {
            tokenInfo[_tokenId].redeemed = _unlocked;
        }

        return (_owner, _toTransfer, _grant.seriesId);
    }

    function computeUnlockAmount(
        uint64 _currentTime,
        StockGrantData memory _data
    ) internal pure returns (uint256) {
        // Nothing can be claimed before the grant is issued.
        if (_currentTime < _data.issuedAtTimestamp) return 0;
        uint64 _elapsed = _currentTime - _data.issuedAtTimestamp;

        // Nothing can be claimed before the grant is unlocked.
        if (_elapsed < _data.lockDuration) return 0;

        // For vesting purposes, time ceases to progress after any
        // cancellation. Note that this happens *after* the
        // `_data.lockDuration` check, which is not affected by cancellation.
        if (_data.vestingCancellationTimestamp != 0) {
            require(
                _data.vestingCancellationTimestamp > _data.issuedAtTimestamp,
                "Corporation: grant cancelled before issued"
            );
            uint64 _cancellationDuration = _data.vestingCancellationTimestamp -
                _data.issuedAtTimestamp;
            if (_elapsed > _cancellationDuration)
                _elapsed = _cancellationDuration;
        }

        // Nothing can be claimed until the effective time passes the cliff.
        if (_elapsed < _data.cliffDuration) return 0;

        // Nothing more happens after the grant is fully vested.
        if (_elapsed > _data.vestDuration) _elapsed = _data.vestDuration;

        if (_data.vestDuration == 0) {
            // This grant immediately fully vested at the issuance date, and
            // we've checked that that already occurred.
            return _data.amount;
        } else {
            // This grant vests linearly over its duration.
            return (_elapsed * _data.amount) / _data.vestDuration;
        }
    }

    function _beforeTokenTransfer(
        address _from,
        address _to,
        uint256 _tokenId
    ) internal virtual override {
        super._beforeTokenTransfer(_from, _to, _tokenId);

        uint256 _amount = tokenInfo[_tokenId].amount;
        uint256 _seriesId = tokenInfo[_tokenId].seriesId;
        if (_from != address(0)) {
            stockBalancePerSeries[_from][_seriesId] -= _amount;
        }
        if (_to != address(0)) {
            stockBalancePerSeries[_to][_seriesId] += _amount;
        }
        if (nextTransferOverride) {
            // TODO(@wchargin): Add tests to demonstrate that you can't execute
            // arbitrary trades in the ERC-721 receive hook.
            nextTransferOverride = false;
            return;
        }
        if (_from == address(0)) {
            // Minting is a superuser action and is always permitted.
            return;
        }
        if (_to == address(0)) {
            // Burning occurs as part of unlocking and is always permitted.
            return;
        }
        revert("StockGrant: cannot transfer restricted stock");
    }

    // Unilaterally reassign a unit of restricted stock to a new owner. Can
    // only be called by a superuser.
    function reassign(uint256 _tokenId, address _newOwner) external {
        require(corp.isSuperuser(msg.sender), "StockGrant: unauthorized");
        nextTransferOverride = true;
        _safeTransfer(ownerOf(_tokenId), _newOwner, _tokenId, bytes(""));
        require(
            !nextTransferOverride,
            "StockGrant: invariant violation: nextTransferOverride not cleared"
        );
    }
}