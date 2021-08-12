// SPDX-License-Identifier: GPL-2.0-only
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

import "./Verifier.sol";

struct StockSeries {
    string name;
    string symbol;
    UnrestrictedStockSeries unrestricted;
    RestrictedStockSeries restricted;
    uint256 authorized;
    uint256 issued;
}

struct SeriesBalance {
    uint256 id;
    uint256 restrictedBalance;
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
        string indexed name,
        UnrestrictedStockSeries unrestricted,
        RestrictedStockSeries restricted
    );
    event StockAuthorized(
        uint256 indexed seriesId,
        uint256 additionalAuthorization
    );
    event StockIssued(
        uint256 indexed seriesId,
        address indexed who,
        RestrictedStockUnit data,
        uint256 tokenId
    );
    event StockUnlocked(
        uint256 indexed seriesId,
        address indexed owner,
        uint256 tokenId,
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

    string public metadataURI;
    string public name;
    string public symbol;

    constructor() {
        isSuperuser[msg.sender] = true;
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

    // Creates a new series of stock with unrestricted and restricted
    // components.
    function createSeries(string memory _name, string memory _symbol)
        external
        returns (
            uint256 _seriesId,
            UnrestrictedStockSeries,
            RestrictedStockSeries
        )
    {
        require(bytes(_name).length > 0, "Corporation: no name");
        require(
            isSuperuser[msg.sender],
            "Corporation: unauthorized createSeries"
        );
        _seriesId = nextSeriesId++;
        UnrestrictedStockSeries _unrestricted = new UnrestrictedStockSeries();
        RestrictedStockSeries _restricted = new RestrictedStockSeries();
        series[_seriesId] = StockSeries({
            name: _name,
            symbol: _symbol,
            unrestricted: _unrestricted,
            restricted: _restricted,
            authorized: 0,
            issued: 0
        });
        _unrestricted.initialize(this, _seriesId);
        _restricted.initialize(this, _seriesId);
        emit SeriesCreated({
            seriesId: _seriesId,
            name: _name,
            unrestricted: _unrestricted,
            restricted: _restricted
        });
        return (_seriesId, _unrestricted, _restricted);
    }

    // Checks whether an address is permitted to receive shares of a series of
    // stock. Called by `UnrestrictedStockSeries` on each token transfer.
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

    function mint(
        uint256 _seriesId,
        address _who,
        RestrictedStockUnit memory _data
    ) external returns (uint256) {
        require(
            verifier.mayReceive(_who),
            "Corporation: unauthorized recipient"
        );
        return uncheckedMint(_seriesId, _who, _data);
    }

    function uncheckedMint(
        uint256 _seriesId,
        address _who,
        RestrictedStockUnit memory _data
    ) public returns (uint256) {
        require(isSuperuser[msg.sender], "Corporation: unauthorized mint");
        StockSeries storage _series = series[_seriesId];
        uint256 _newIssued = series[_seriesId].issued + _data.amount;
        require(_newIssued <= _series.authorized, "Corporation: overissuance");
        series[_seriesId].issued = _newIssued;
        uint256 _tokenId = _series.restricted.mint(_who, _data);
        emit StockIssued({
            seriesId: _seriesId,
            who: _who,
            data: _data,
            tokenId: _tokenId
        });
        return _tokenId;
    }

    function unlock(uint256 _seriesId, uint256 _tokenId) external {
        StockSeries storage _series = series[_seriesId];
        (address _owner, uint256 _amount) = _series.restricted.burnForUnlock(
            msg.sender,
            _tokenId
        );
        _series.unrestricted.mintForUnlock(_owner, _amount);
        emit StockUnlocked({
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
            _next.restrictedBalance = _series.restricted.stockBalanceOf(_owner);
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
        StockSeries storage _series = series[_id];
        return
            string(
                abi.encodePacked(bytes(name), bytes2(": "), bytes(_series.name))
            );
    }

    function symbolForSeries(uint256 _id)
        external
        view
        returns (string memory)
    {
        StockSeries storage _series = series[_id];
        return
            string(
                abi.encodePacked(
                    bytes(symbol),
                    bytes1(":"),
                    bytes(_series.symbol)
                )
            );
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

// A single series of unrestricted stock units for a corporation.
contract UnrestrictedStockSeries is ERC20 {
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
        require(!initialized, "UnrestrictedStockSeries: already initialized");
        initialized = true;

        corp = _corp;
        seriesId = _seriesId;
    }

    // Mints new shares of unrestricted stock after burning shares of
    // restricted stock. Can only be called by the `corp` contract.
    function mintForUnlock(address _recipient, uint256 _amount) external {
        require(
            msg.sender == address(corp),
            "UnrestrictedStockSeries: unauthorized mintForUnlock"
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
            "UnrestrictedStockSeries: unaccredited recipient"
        );
    }
}

struct RestrictedStockUnit {
    uint256 issuedAtTimestamp;
    uint256 unlocksAtTimestamp;
    uint256 amount;
}

// A single series of restricted stock. A token of this series represents a
// fixed number of shares that will unlock at a future date, after which point
// they may be converted into the same number of unrestricted shares.
//
// Restricted stock units may not be transferred (except as an explicit
// superuser override).
contract RestrictedStockSeries is ERC721Enumerable {
    bool initialized;
    Corporation corp;
    uint256 seriesId;
    // If this flag is set, the next token transfer will be unconditionally
    // permitted, and this flag will be cleared. Used to permit superusers to
    // correct stock records.
    bool nextTransferOverride;

    uint256 nextTokenId;
    // Mapping from token ID to RSU data.
    mapping(uint256 => RestrictedStockUnit) public tokenInfo;

    mapping(address => uint256) public stockBalanceOf;

    constructor() ERC721("", "") {}

    function name() public view override returns (string memory) {
        return corp.nameForSeries(seriesId);
    }

    function symbol() public view override returns (string memory) {
        return corp.symbolForSeries(seriesId);
    }

    function initialize(Corporation _corp, uint256 _seriesId) external {
        require(!initialized, "UnrestrictedStockSeries: already initialized");
        initialized = true;

        corp = _corp;
        seriesId = _seriesId;
    }

    // Issues new restricted stock. Can only be called by the superuser.
    function mint(address _who, RestrictedStockUnit memory _data)
        external
        returns (uint256)
    {
        require(
            msg.sender == address(corp),
            "RestrictedStockSeries: unauthorized mint"
        );
        uint256 _tokenId = nextTokenId++;
        tokenInfo[_tokenId] = _data;
        _safeMint(_who, _tokenId);
        return _tokenId;
    }

    // Burns a set of restricted shares after they've become transferable. Can
    // only be called by the `corp` contract.
    function burnForUnlock(address _operator, uint256 _tokenId)
        external
        returns (address _owner, uint256 _amount)
    {
        require(
            msg.sender == address(corp),
            "RestrictedStockSeries: unauthorized burnForUnlock"
        );
        require(
            _isApprovedOrOwner(_operator, _tokenId) ||
                corp.isSuperuser(_operator),
            "RestrictedStockSeries: unauthorized burnForUnlock"
        );
        _owner = ownerOf(_tokenId);
        RestrictedStockUnit memory _rsu = tokenInfo[_tokenId];
        require(
            _rsu.unlocksAtTimestamp <= block.timestamp,
            "RestrictedStockSeries: too early"
        );
        // Burning (which transfers to address(0)) before deleting the RSU from
        // memory so we can lookup the right amount of stock that's getting
        // burned in  the beforeTokenTransfer hook; should be safe as it's
        // impossible that the zero address will invoke any code on receipt
        _burn(_tokenId);
        delete tokenInfo[_tokenId];
        return (_owner, _rsu.amount);
    }

    function _beforeTokenTransfer(
        address _from,
        address _to,
        uint256 _tokenId
    ) internal virtual override {
        super._beforeTokenTransfer(_from, _to, _tokenId);

        _tokenId;
        uint256 _amount = tokenInfo[_tokenId].amount;
        if (_from != address(0)) {
            stockBalanceOf[_from] -= _amount;
        }
        if (_to != address(0)) {
            stockBalanceOf[_to] += _amount;
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
        revert("RestrictedStockSeries: cannot transfer restricted stock");
    }

    // Unilaterally reassign a unit of restricted stock to a new owner. Can
    // only be called by a superuser.
    function reassign(uint256 _tokenId, address _newOwner) external {
        require(
            corp.isSuperuser(msg.sender),
            "RestrictedStockSeries: unauthorized"
        );
        nextTransferOverride = true;
        _safeTransfer(ownerOf(_tokenId), _newOwner, _tokenId, bytes(""));
        require(
            !nextTransferOverride,
            "RestrictedStockSeries: invariant violation: nextTransferOverride not cleared"
        );
    }
}