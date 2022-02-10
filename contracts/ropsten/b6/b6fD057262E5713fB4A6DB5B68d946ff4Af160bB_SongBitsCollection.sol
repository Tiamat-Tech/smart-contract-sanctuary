// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.9;

import "./interfaces/IParams.sol";
import "./interfaces/ICollection.sol";
import "./interfaces/IERC721Receiver.sol";

import "./utils/Ownable.sol";
import "./utils/Pausable.sol";

import "./utils/Strings.sol";
import "./utils/Address.sol";

contract SongBitsCollection is Ownable, Pausable, ICollection {
    using Address for address;
    using Strings for uint256;

    mapping(uint256 => Metadata) public metadata;

    address private _artist;
    address private _manager;

    string private _name;
    string private _symbol;
    string private _uri;

    uint256 private _totalSupply;

    mapping(uint256 => address) private _owners;
    mapping(address => uint256) private _balances;
    mapping(uint256 => address) private _tokenApprovals;
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    constructor(
        IParams.CollectionParams memory params,
        address _owner,
        address manager_
    ) {
        _name = params._name;
        _symbol = params._symbol;
        _uri = params._uri;

        _artist = _owner;
        _manager = manager_;

        _transferOwnership(_owner);
    }

    modifier onlyTokenOwner(uint256 _tokenId) {
        require(_owners[_tokenId] == msg.sender);
        _;
    }

    modifier onlyOwnerOrManager() {
        require(
            (owner() == _msgSender() || _manager == _msgSender()),
            "Ownable: caller is not the owner"
        );
        _;
    }

    function isOwnerOrManager(address _address) internal view returns (bool) {
        if (owner() == _address || _manager == _address) {
            return true;
        }

        return false;
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override
        returns (bool)
    {
        return interfaceId == type(IERC721).interfaceId;
    }

    function balanceOf(address owner)
        public
        view
        virtual
        override
        returns (uint256)
    {
        require(
            owner != address(0),
            "SongBitsCollection: balance query for the zero address"
        );
        return _balances[owner];
    }

    function ownerOf(uint256 tokenId)
        public
        view
        virtual
        override
        returns (address)
    {
        address owner = _owners[tokenId];
        require(
            owner != address(0),
            "SongBitsCollection: owner query for nonexistent token"
        );
        return owner;
    }

    function name() public view virtual override returns (string memory) {
        return _name;
    }

    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    function artist() public view override returns (address) {
        return _artist;
    }

    function getMetadata(uint256 tokenId)
        public
        view
        override
        returns (Metadata memory)
    {
        return metadata[tokenId];
    }

    function setManager(address manager_) public onlyOwnerOrManager {
        _manager = manager_;
    }

    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        require(
            _exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );

        string memory baseURI = _baseURI();
        return
            bytes(baseURI).length > 0
                ? string(abi.encodePacked(baseURI, tokenId.toString()))
                : "";
    }

    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    function approve(address to, uint256 tokenId) public virtual override {
        address owner = SongBitsCollection.ownerOf(tokenId);
        require(to != owner, "SongBitsCollection: approval to current owner");

        require(
            _msgSender() == owner || isApprovedForAll(owner, _msgSender()),
            "SongBitsCollection: approve caller is not owner nor approved for all"
        );

        _approve(to, tokenId);
    }

    function getApproved(uint256 tokenId)
        public
        view
        virtual
        override
        returns (address)
    {
        require(
            _exists(tokenId),
            "SongBitsCollection: approved query for nonexistent token"
        );

        return _tokenApprovals[tokenId];
    }

    function setApprovalForAll(address operator, bool approved)
        public
        virtual
        override
        onlyOwner
    {
        _setApprovalForAll(_msgSender(), operator, approved);
    }

    function setCost(uint256 _cost, uint256 _tokenId)
        public
        onlyTokenOwner(_tokenId)
    {
        metadata[_tokenId].cost = _cost;
    }

    function isApprovedForAll(address owner, address operator)
        public
        view
        virtual
        override
        returns (bool)
    {
        return _operatorApprovals[owner][operator];
    }

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        //solhint-disable-next-line max-line-length
        require(
            _isApprovedOrOwner(_msgSender(), tokenId),
            "SongBitsCollection: transfer caller is not owner nor approved"
        );

        _transfer(from, to, tokenId);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        safeTransferFrom(from, to, tokenId, "");
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) public virtual override {
        require(
            _isApprovedOrOwner(_msgSender(), tokenId),
            "SongBitsCollection: transfer caller is not owner nor approved"
        );
        _safeTransfer(from, to, tokenId, _data);
    }

    function mint(
        address _to,
        uint256 _duration,
        uint256 _cost
    ) public override onlyOwnerOrManager {
        uint256 newId = totalSupply() + 1;

        _safeMint(_to, newId, "");
        createMetadata(newId, _duration, 0, 0, _duration, _cost, false, false);
    }

    function mintBatch(
        address _to,
        uint256[] memory _durations,
        uint256[] memory _costs
    ) public onlyOwner {
        require(_durations.length == _costs.length);

        for (uint256 i = 0; i < _durations.length; i++) {
            mint(_to, _durations[i], _costs[i]);
        }
    }

    function createMetadata(
        uint256 tokenId,
        uint256 duration,
        uint256 parentId,
        uint256 boughtFrom,
        uint256 boughtTo,
        uint256 cost,
        bool isPart,
        bool hasPart
    ) public override onlyOwnerOrManager {
        require(_exists(tokenId));
        require(boughtTo != 0);

        metadata[tokenId] = Metadata(
            duration,
            parentId,
            boughtFrom,
            boughtTo,
            cost,
            isPart,
            hasPart
        );
    }

    function calculatePartCost(
        uint256 _tokenId,
        uint256 _from,
        uint256 _to
    ) public view returns (uint256 partCost) {
        require(_to > _from);

        Metadata memory _metadata = getMetadata(_tokenId);

        partCost = ((_to - _from) * _metadata.duration) / _metadata.cost;
    }

    function _baseURI() internal view virtual returns (string memory) {
        return _uri;
    }

    function _safeTransfer(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) internal virtual {
        _transfer(from, to, tokenId);
        require(
            _checkOnERC721Received(from, to, tokenId, _data),
            "SongBitsCollection: transfer to non ERC721Receiver implementer"
        );
    }

    function _exists(uint256 tokenId) internal view virtual returns (bool) {
        return _owners[tokenId] != address(0);
    }

    function _isApprovedOrOwner(address spender, uint256 tokenId)
        internal
        view
        virtual
        returns (bool)
    {
        require(
            _exists(tokenId),
            "SongBitsCollection: operator query for nonexistent token"
        );
        address owner = SongBitsCollection.ownerOf(tokenId);
        return (spender == owner ||
            getApproved(tokenId) == spender ||
            isApprovedForAll(owner, spender));
    }

    function _safeMint(address to, uint256 tokenId) internal virtual {
        _safeMint(to, tokenId, "");
    }

    function _safeMint(
        address to,
        uint256 tokenId,
        bytes memory _data
    ) internal virtual {
        _mint(to, tokenId);
        require(
            _checkOnERC721Received(address(0), to, tokenId, _data),
            "SongBitsCollection: transfer to non ERC721Receiver implementer"
        );
    }

    function _mint(address to, uint256 tokenId) internal virtual {
        require(
            to != address(0),
            "SongBitsCollection: mint to the zero address"
        );
        require(!_exists(tokenId), "SongBitsCollection: token already minted");

        _beforeTokenTransfer(address(0), to, tokenId);

        _balances[to] += 1;
        _owners[tokenId] = to;
        _totalSupply += 1;

        emit Transfer(address(0), to, tokenId);
    }

    function _burn(uint256 tokenId) internal virtual onlyOwner whenNotPaused {
        address owner = SongBitsCollection.ownerOf(tokenId);

        _beforeTokenTransfer(owner, address(0), tokenId);

        // Clear approvals
        _approve(address(0), tokenId);

        _balances[owner] -= 1;
        delete _owners[tokenId];
        _totalSupply -= 1;

        emit Transfer(owner, address(0), tokenId);
    }

    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual whenNotPaused {
        require(
            SongBitsCollection.ownerOf(tokenId) == from,
            "SongBitsCollection: transfer of token that is not own"
        );
        require(
            to != address(0),
            "SongBitsCollection: transfer to the zero address"
        );

        _beforeTokenTransfer(from, to, tokenId);

        // Clear approvals from the previous owner
        _approve(address(0), tokenId);

        _balances[from] -= 1;
        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(from, to, tokenId);
    }

    function _approve(address to, uint256 tokenId) internal virtual {
        _tokenApprovals[tokenId] = to;
        emit Approval(SongBitsCollection.ownerOf(tokenId), to, tokenId);
    }

    function _setApprovalForAll(
        address owner,
        address operator,
        bool approved
    ) internal virtual {
        require(owner != operator, "SongBitsCollection: approve to caller");
        _operatorApprovals[owner][operator] = approved;
        emit ApprovalForAll(owner, operator, approved);
    }

    function _checkOnERC721Received(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) private returns (bool) {
        if (to.isContract()) {
            try
                IERC721Receiver(to).onERC721Received(
                    _msgSender(),
                    from,
                    tokenId,
                    _data
                )
            returns (bytes4 retval) {
                return retval == IERC721Receiver.onERC721Received.selector;
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert(
                        "SongBitsCollection: transfer to non ERC721Receiver implementer"
                    );
                } else {
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        } else {
            return true;
        }
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {}
}