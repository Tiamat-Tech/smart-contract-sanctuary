// SPDX-License-Identifier: GPL-v2-only
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import "./ITokenUriOracle.sol";

struct Batch {
    uint16 size; // `1 <= size <= 256`
    address minter;
}

struct MintRequest {
    uint248 batch;
    uint8 sizeMinusOne;
}

contract Spectrum is IERC165, IERC721, IERC721Metadata {
    event BatchMinted(
        address indexed minter,
        uint248 indexed batch,
        uint16 size
    );
    event AdminChanged(address newAdmin);
    event TokenUriOracleChanged(
        ITokenUriOracle indexed oldOracle,
        ITokenUriOracle indexed newOracle
    );
    event BatchFeeChanged(uint256 oldFeeWei, uint256 newFeeWei);
    event FeesCollected(address indexed _beneficiary, uint256 _amount);

    address public admin;
    ITokenUriOracle public tokenUriOracle;
    uint256 public batchFeeWei;

    mapping(uint248 => Batch) public batch;
    /// Owners for tokens that have been explicitly transferred. If a token
    /// exists but does not have an owner in this map, then its owner is
    /// `_batchData(_tokenId).minter`.
    mapping(uint256 => address) explicitOwner;
    mapping(uint256 => address) operator;
    mapping(address => mapping(address => bool)) approvedForAll;
    mapping(address => uint256) balance;

    string private constant ERR_NOT_FOUND = "Spectrum: NOT_FOUND";
    string private constant ERR_UNAUTHORIZED = "Spectrum: UNAUTHORIZED";
    string private constant ERR_ALREADY_EXISTS = "Spectrum: ALREADY_EXISTS";
    string private constant ERR_INCORRECT_OWNER = "Spectrum: INCORRECT_OWNER";
    string private constant ERR_INCORRECT_FEE = "Spectrum: INCORRECT_FEE";
    string private constant ERR_UNSAFE_TRANSFER = "Spectrum: UNSAFE_TRANSFER";

    constructor() {
        admin = msg.sender;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, ERR_UNAUTHORIZED);
        _;
    }

    function setAdmin(address _admin) external onlyAdmin {
        emit AdminChanged(_admin);
        admin = _admin;
    }

    function setTokenUriOracle(ITokenUriOracle _oracle) external onlyAdmin {
        emit TokenUriOracleChanged(tokenUriOracle, _oracle);
        tokenUriOracle = _oracle;
    }

    function setBatchFee(uint256 _batchFeeWei) external onlyAdmin {
        emit BatchFeeChanged(batchFeeWei, _batchFeeWei);
        batchFeeWei = _batchFeeWei;
    }

    function name() external pure override returns (string memory) {
        return "Spectrum";
    }

    function symbol() external pure override returns (string memory) {
        return "SPEC";
    }

    function tokenURI(uint256 _tokenId)
        external
        view
        override
        returns (string memory)
    {
        _batchData(_tokenId); // ensure exists
        return tokenUriOracle.tokenURI(address(this), _tokenId);
    }

    function mint(MintRequest[] memory _requests) external payable {
        uint256 _totalFee = batchFeeWei * _requests.length;
        require(msg.value == _totalFee, ERR_INCORRECT_FEE);
        uint256 _totalSize = 0;
        for (uint256 _i = 0; _i < _requests.length; _i++) {
            uint248 _batch = _requests[_i].batch;
            uint16 _size = uint16(_requests[_i].sizeMinusOne) + 1;
            _totalSize += _size;
            require(batch[_batch].minter == address(0), ERR_ALREADY_EXISTS);
            batch[_batch] = Batch({size: _size, minter: msg.sender});
            emit BatchMinted(msg.sender, _batch, _size);
            uint256 _tokenId = _batch << 8;
            for (uint256 _j = 0; _j < _size; _j++) {
                _tokenId = (_tokenId & ~uint256(0xff)) | _j;
                emit Transfer(address(0), msg.sender, _tokenId);
            }
        }
        balance[msg.sender] += _totalSize;
    }

    function collectFees(address payable _beneficiary) external onlyAdmin {
        uint256 _balance = address(this).balance;
        _beneficiary.transfer(_balance);
        emit FeesCollected(_beneficiary, _balance);
    }

    /// Parses a token ID into batch and index within batch. This only extracts
    /// the data encoded in the ID itself, and does not read contract state;
    /// the batch may or may not exist, and the index may or may not be valid
    /// for that batch.
    function _splitTokenId(uint256 _tokenId)
        internal
        pure
        returns (uint248 _batch, uint8 _index)
    {
        _batch = uint248(_tokenId >> 8);
        _index = uint8(_tokenId);
    }

    /// Reads the batch data for the given token. Reverts if the token does not
    /// exist.
    function _batchData(uint256 _tokenId) internal view returns (Batch memory) {
        (uint248 _batchId, uint8 _index) = _splitTokenId(_tokenId);
        Batch memory _batch = batch[_batchId];
        require(_index < _batch.size, ERR_NOT_FOUND);
        return _batch;
    }

    function balanceOf(address _owner)
        external
        view
        override
        returns (uint256)
    {
        return balance[_owner];
    }

    function ownerOf(uint256 _tokenId) public view override returns (address) {
        address _owner = explicitOwner[_tokenId];
        if (_owner != address(0)) return _owner;
        Batch memory _batch = _batchData(_tokenId);
        _owner = _batch.minter;
        if (_owner != address(0)) return _owner;
        revert(ERR_NOT_FOUND);
    }

    function _isApprovedOrOwner(address _who, uint256 _tokenId)
        internal
        view
        returns (bool)
    {
        if (operator[_tokenId] == _who) return true;
        address _owner = ownerOf(_tokenId);
        return _owner == _who || approvedForAll[_owner][_who];
    }

    function safeTransferFrom(
        address _from,
        address _to,
        uint256 _tokenId,
        bytes memory _data
    ) public override {
        transferFrom(_from, _to, _tokenId);
        _checkOnERC721Received(_from, _to, _tokenId, _data);
    }

    function safeTransferFrom(
        address _from,
        address _to,
        uint256 _tokenId
    ) external override {
        safeTransferFrom(_from, _to, _tokenId, bytes(""));
    }

    function transferFrom(
        address _from,
        address _to,
        uint256 _tokenId
    ) public override {
        address _owner = ownerOf(_tokenId);
        require(_owner == _from, ERR_INCORRECT_OWNER);
        require(
            _owner == msg.sender ||
                operator[_tokenId] == msg.sender ||
                approvedForAll[_owner][msg.sender],
            ERR_UNAUTHORIZED
        );
        explicitOwner[_tokenId] = _to;
        operator[_tokenId] = address(0);
        balance[_from]--;
        balance[_to]++;
        emit Transfer(_from, _to, _tokenId);
    }

    function approve(address _approved, uint256 _tokenId) external override {
        require(_isApprovedOrOwner(msg.sender, _tokenId), ERR_UNAUTHORIZED);
        operator[_tokenId] = _approved;
        emit Approval(ownerOf(_tokenId), _approved, _tokenId);
    }

    function setApprovalForAll(address _operator, bool _approved)
        external
        override
    {
        approvedForAll[msg.sender][_operator] = _approved;
        emit ApprovalForAll(msg.sender, _operator, _approved);
    }

    function getApproved(uint256 _tokenId)
        external
        view
        override
        returns (address)
    {
        _batchData(_tokenId); // ensure exists
        return operator[_tokenId];
    }

    function isApprovedForAll(address _owner, address _operator)
        external
        view
        override
        returns (bool)
    {
        return approvedForAll[_owner][_operator];
    }

    function supportsInterface(bytes4 _interfaceId)
        external
        pure
        override
        returns (bool)
    {
        return
            _interfaceId == type(IERC165).interfaceId ||
            _interfaceId == type(IERC721).interfaceId ||
            _interfaceId == type(IERC721Metadata).interfaceId;
    }

    // Adapted from OpenZeppelin ERC-721 implementation, which is released
    // under the MIT License.
    function _checkOnERC721Received(
        address _from,
        address _to,
        uint256 _tokenId,
        bytes memory _data
    ) internal {
        if (!Address.isContract(_to)) {
            return;
        }
        try
            IERC721Receiver(_to).onERC721Received(
                msg.sender,
                _from,
                _tokenId,
                _data
            )
        returns (bytes4 _retval) {
            require(
                _retval == IERC721Receiver.onERC721Received.selector,
                ERR_UNSAFE_TRANSFER
            );
        } catch (bytes memory _reason) {
            if (_reason.length == 0) {
                revert(ERR_UNSAFE_TRANSFER);
            } else {
                assembly {
                    revert(add(32, _reason), mload(_reason))
                }
            }
        }
    }
}