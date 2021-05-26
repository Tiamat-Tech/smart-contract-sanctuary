pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./EpicMeta_Test_Factory.sol";
import "./EpicMeta_Token_Test.sol";

contract EpicMeta_Test is ERC721URIStorage, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    mapping(uint256 => address) owners;
    mapping(address => uint256[]) public owner_holdings;
    mapping (address => uint256) private _balances;
    mapping (uint256 => string) private _tokenURIs;
    mapping(address => uint256) public prices;
    string public _rarity;
    string public _name;
    string public _symbol;
    string private _metadata;
    uint256 public _max_distribution;
    address public _factory;
    address public _content_creator;
    EpicMeta_Test_Factory factory;
    EpicMeta_Token_Test ledger;

    constructor(string memory name, string memory symbol, string memory metadata, uint16 num_mint, string memory rarity, uint256 price, address content_creator) ERC721(name,symbol) {
        _rarity = rarity;
        _name = name;
        _symbol = symbol;
        prices[content_creator] = price;
        _factory = msg.sender;
        _content_creator = content_creator;
        factory = EpicMeta_Test_Factory(_factory);
        ledger = EpicMeta_Token_Test(factory.utility_token_address());
        require(num_mint <= factory.max_distribution(_rarity));
        _max_distribution = num_mint;

        for (uint i = 0; i < num_mint; i++){
            _tokenIds.increment();
            _metadata = metadata;
            mint(content_creator,_tokenIds.current());
        }
    }
    
    event Debug(string text);

    function mint(address recipient, uint256 itemId) internal onlyOwner {
        require(itemId <= _max_distribution);
        _mint(recipient, itemId);
        _setTokenURI(itemId, _metadata);
        owner_holdings[recipient].push(itemId);
    }

    function _mint(address to, uint256 tokenId) internal override virtual {
        _balances[to] += 1;
        owners[tokenId] = to;

    }
    
    function buy(address owner, uint16 amount, uint256 new_price) public{
        uint256 last_token;
        uint256 txn_px;
        uint256 total_px;
        uint256 _price = prices[owner];
        
        txn_px = amount* _price; //1% for original content creator, 1% to platform
        total_px = amount* _price* 102 / 100;
        
        // emit Debug()
        require(ledger.balanceOf(msg.sender) >= total_px, "MSG sender doesn't have enough funds");
        require(amount <= owner_holdings[owner].length, "Asking for too many tokens from this owner");
        if (ledger.transfer(msg.sender,owner,txn_px)){
            for (uint i = 0;i<amount;i++){
                last_token = owner_holdings[owner][owner_holdings[owner].length-1];
                owner_holdings[owner].pop();
                
                owner_holdings[msg.sender].push(last_token);
    
                owners[last_token] = msg.sender;
    
                prices[msg.sender] = new_price;                
            }

        }

        ledger.transfer(msg.sender,_content_creator, (txn_px * 101 / 100) - txn_px);
        ledger.transfer(msg.sender,factory.epicmeta_address(), (txn_px * 101 / 100) - txn_px);
        
    }

    function set_price(uint256 tokenId, uint256 new_price) public{
        require(owners[tokenId] == msg.sender);
        prices[msg.sender] = new_price;
    }
    
    function balanceOf(address owner) public view virtual override(ERC721) returns (uint256) {
        require(owner != address(0), "ERC721: balance query for the zero address");
        return _balances[owner];
    }
    
    function _burn(uint256 tokenId) internal virtual override {
        address owner = ERC721.ownerOf(tokenId);

        _beforeTokenTransfer(owner, address(0), tokenId);

        // Clear approvals
        _approve(address(0), tokenId);

        _balances[owner] -= 1;
        delete owners[tokenId];

        emit Transfer(owner, address(0), tokenId);
    }
    
    function _transfer(address from, address to, uint256 tokenId) internal virtual override(ERC721) {
        require(ERC721.ownerOf(tokenId) == from, "ERC721: transfer of token that is not own");
        require(to != address(0), "ERC721: transfer to the zero address");

        _beforeTokenTransfer(from, to, tokenId);

        // Clear approvals from the previous owner
        _approve(address(0), tokenId);

        _balances[from] -= 1;
        _balances[to] += 1;
        owners[tokenId] = to;

        emit Transfer(from, to, tokenId);
    }
    
    function ownerOf(uint256 tokenId) public view virtual override returns (address) {
        address owner = owners[tokenId];
        require(owner != address(0), "ERC721: owner query for nonexistent token");
        return owner;
    }
    
    function _exists(uint256 tokenId) internal view virtual override(ERC721) returns (bool) {
        return owners[tokenId] != address(0);
    }
    
     function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721URIStorage: URI query for nonexistent token");

        string memory _tokenURI = _tokenURIs[tokenId];
        string memory base = _baseURI();

        // If there is no base URI, return the token URI.
        if (bytes(base).length == 0) {
            return _tokenURI;
        }
        // If both are set, concatenate the baseURI and tokenURI (via abi.encodePacked).
        if (bytes(_tokenURI).length > 0) {
            return string(abi.encodePacked(base, _tokenURI));
        }

        return super.tokenURI(tokenId);
    }
    
    function _setTokenURI(uint256 tokenId, string memory _tokenURI) internal virtual override {
        require(_exists(tokenId), "ERC721URIStorage: URI set of nonexistent token");
        _tokenURIs[tokenId] = _tokenURI;
    }
    
    function num_tokens() public view returns (uint256){
        return _tokenIds.current();
    }
}