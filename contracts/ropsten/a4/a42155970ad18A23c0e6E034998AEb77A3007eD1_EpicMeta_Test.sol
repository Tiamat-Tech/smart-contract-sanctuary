pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol"; 
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract EpicMeta_Test is Ownable, ERC1155 {

    string private _name;
    string private _symbol;

    using Counters for Counters.Counter;
    using Address for address;
    Counters.Counter private _tokenIds;

    mapping(string => uint8) unique_checker;
    mapping(uint256 => string) rarity_map;
    mapping(string => uint256) max_distribution;
    mapping (uint256 => string) private _tokenURIs;
    mapping (address => mapping(address => bool))  _operatorApprovals;
    mapping (uint256 => mapping(address => uint256))  _balances;

    constructor() ERC1155("https://epicmeta.io/"){
        max_distribution["Common"] = 1000;
        max_distribution["Rare"] = 100;
        max_distribution["Epic"] = 10;
        _name = "EpicMeta";
        _symbol = "EPICMETA";
    }

    modifier isUnique(string memory metadata){
        require(unique_checker[metadata] != 1);
        _;
    }

    function createNFT(address recipient, string memory metadata, uint16 amount, string memory rarity) public onlyOwner isUnique(metadata) returns (uint256) {
        require(amount <= max_distribution[rarity]);
        unique_checker[metadata] = 1;
        _tokenIds.increment();
        uint256 newItemId = _tokenIds.current();
        _mint(recipient, newItemId, amount, "");
        _setTokenURI(newItemId, metadata);
        rarity_map[newItemId] = rarity;
        return newItemId;
    }

    function createNFT(address[] memory recipients, string memory metadata, uint16[] memory amounts, string memory rarity) public onlyOwner isUnique(metadata) returns (uint256) {
        require(recipients.length == amounts.length);
        uint16 total = 0;
        for (uint16 i=0;i<amounts.length;i++){
            total += amounts[i];
        }
        require(total<=max_distribution[rarity]);

        unique_checker[metadata] = 1;
        _tokenIds.increment();
        uint256 newItemId = _tokenIds.current();

        for (uint16 j=0;j<recipients.length;j++){
            address recipient = recipients[j];
            uint16 amount = amounts[j];
            _mint(recipient, newItemId, amount, "");
            
        }
        
        _setTokenURI(newItemId, metadata);
        rarity_map[newItemId] = rarity;
        return newItemId;
    }

    function setApprovalForAll(address operator, bool approved) public virtual override(ERC1155) {
        require(_msgSender() != operator, "ERC1155: setting approval status for self");

        _operatorApprovals[_msgSender()][operator] = approved;
        emit ApprovalForAll(_msgSender(), operator, approved);
    }

    function isApprovedForAll(address account, address operator) public view virtual override(ERC1155) returns (bool) {
        return _operatorApprovals[account][operator];
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC1155) returns (bool) {
        return interfaceId == type(IERC1155).interfaceId
            || interfaceId == type(IERC1155MetadataURI).interfaceId
            || super.supportsInterface(interfaceId);
    }

    function _mint(address account, uint256 id, uint256 amount, bytes memory data) internal virtual override(ERC1155) {
        require(account != address(0), "ERC1155: mint to the zero address");

        address operator = _msgSender();

        _beforeTokenTransfer(operator, address(0), account, asSingletonArray(id), asSingletonArray(amount), data);

        _balances[id][account] += amount;
        emit TransferSingle(operator, address(0), account, id, amount);

        doSafeTransferAcceptanceCheck(operator, address(0), account, id, amount, data);
    }

        function doSafeTransferAcceptanceCheck(address operator, address from, address to, uint256 id, uint256 amount, bytes memory data ) private {
        if (to.isContract()) {
            try IERC1155Receiver(to).onERC1155Received(operator, from, id, amount, data) returns (bytes4 response) {
                if (response != IERC1155Receiver(to).onERC1155Received.selector) {
                    revert("ERC1155: ERC1155Receiver rejected tokens");
                }
            } catch Error(string memory reason) {
                revert(reason);
            } catch {
                revert("ERC1155: transfer to non ERC1155Receiver implementer");
            }
        }
    }

    function asSingletonArray(uint256 element) private pure returns (uint256[] memory) {
        uint256[] memory array = new uint256[](1);
        array[0] = element;

        return array;
    }

    function _setTokenURI(uint256 tokenId, string memory _tokenURI) internal virtual {
        require(_exists(tokenId), "ERC721URIStorage: URI set of nonexistent token");
        _tokenURIs[tokenId] = _tokenURI;
    }

    function _exists(uint256 tokenId) internal view virtual returns (bool) {
        return tokenId <= _tokenIds.current();
    }

    function moment_URI(uint256 tokenId) public view returns (string memory metadata){
        return _tokenURIs[tokenId];
    }

    function name() public view virtual returns (string memory) {
        return _name;
    }

    function symbol() public view virtual returns (string memory) {
        return _symbol;
    }

}