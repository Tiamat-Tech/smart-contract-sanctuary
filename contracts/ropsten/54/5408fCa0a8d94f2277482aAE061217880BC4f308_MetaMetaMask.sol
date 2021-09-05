// SPDX-License-Identifier: None
// pragma solidity >=0.6.0 <=0.8.4;
pragma solidity ^0.8.4;

/*
  ______             _             __  __               __ _____ __            ___     
 /_  __/________    (_)___ _____  / / / /__  ____ _____/ // ___// /___  ______/ (_)___ 
  / / / ___/ __ \  / / __ `/ __ \/ /_/ / _ \/ __ `/ __  / \__ \/ __/ / / / __  / / __ \
 / / / /  / /_/ / / / /_/ / / / / __  /  __/ /_/ / /_/ / ___/ / /_/ /_/ / /_/ / / /_/ /
/_/ /_/   \____/_/ /\__,_/_/ /_/_/ /_/\___/\__,_/\__,_(_)____/\__/\__,_/\__,_/_/\____/ 
              /___/
    https://trojanhead.studio brings you  https://metametamask.rocks

*/
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract MetaMetaMask is ERC721, Ownable {
    using Strings for uint256;
    using SafeMath for uint256;
    
    // Code is truth.
    uint256 public mintPrice = 0.0003 ether; /// TEST CHANGE THIS
    uint256 public mintLimit = 25;

    uint256 public supplyLimit;
    bool public saleActive = false;

    // Shareholders - Logic based on CanineCartel Contract at 0x23c54ac322Cba66EDdcf95c5697b53fc3a8a608c - Love you guys!
    address public wallet1Address;
    address public wallet2Address;
    address public wallet3Address;

    uint8 public wallet1Share = 33;
    uint8 public wallet2Share = 34;
    uint8 public wallet3Share = 33;

    string public baseURI = "";
    uint256 public totalSupply = 0;

    // ======================= EVENTS START =======================
    event wallet1AddressChanged(address _wallet1);
    event wallet2AddressChanged(address _wallet2);
    event wallet3AddressChanged(address _wallet3);

    event SharesChanged(uint8 _value1, uint8 _value2, uint8 _value3);

    event SaleStateChanged(bool _state);
    event SupplyLimitChanged(uint256 _supplyLimit);
    event MintLimitChanged(uint256 _mintLimit);
    event MintPriceChanged(uint256 _mintPrice);
    event BaseURIChanged(string _baseURI);

    event MetaMetaMaskMinted(address indexed _user, uint256 indexed _tokenId, string _tokenURI);
    event ReserveMetaMetaMasks(uint256 _numberOfTokens);
    // ======================= EVENTS END =========================

    constructor(
        uint256 tokenSupplyLimit,
        string memory _baseURI
    ) ERC721("MetaMetaMask", "MMMASK") {

        supplyLimit = tokenSupplyLimit;
        baseURI = _baseURI;

        wallet1Address = owner();
        wallet2Address = owner();
        wallet3Address = owner();

        emit SupplyLimitChanged(supplyLimit);
        emit MintLimitChanged(mintLimit);
        emit MintPriceChanged(mintPrice);
        emit SharesChanged(wallet1Share, wallet2Share, wallet3Share);
        emit BaseURIChanged(_baseURI);
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

        return bytes(baseURI).length > 0 ?
        string(abi.encodePacked(baseURI, "/", tokenId.toString())) : "";
    }

    function setBaseURI(string memory _baseURI) external onlyOwner {
        baseURI = _baseURI;
        emit BaseURIChanged(_baseURI);
    }
    
    function setWallet_1(address _address) external onlyOwner{
        wallet1Address = _address;
        emit wallet1AddressChanged(_address);
    }

    function setWallet_2(address _address) external onlyOwner{
        wallet2Address = _address;
        transferOwnership(_address);
        emit wallet2AddressChanged(_address);
    }

    function setWallet_3(address _address) external onlyOwner{
        wallet3Address = _address;
        emit wallet3AddressChanged(_address);
    }

    function changeWalletShares(uint8 _value1, uint8 _value2, uint8 _value3) external onlyOwner{
        require(_value1 + _value2 + _value3 == 100, "Shares are not adding up to 100.");
        wallet1Share = _value1;
        wallet2Share = _value2;
        wallet3Share = _value3;
        emit SharesChanged(_value1, _value2, _value3);
    }
    
    function toggleSaleActive() external onlyOwner {
        saleActive = !saleActive;
        emit SaleStateChanged(saleActive);
    }

    function changeSupplyLimit(uint256 _supplyLimit) external onlyOwner {
        require(_supplyLimit >= totalSupply, "Value should be greater currently minted Meta MetaMasks.");
        supplyLimit = _supplyLimit;
        emit SupplyLimitChanged(_supplyLimit);
    }

    function changeMintLimit(uint256 _mintLimit) external onlyOwner {
        mintLimit = _mintLimit;
        emit MintLimitChanged(_mintLimit);
    }

    function changeMintPrice(uint256 _mintPrice) external onlyOwner {
        mintPrice = _mintPrice;
        emit MintPriceChanged(_mintPrice);
    }

    // If you're reading this, then that means this project was probably a success
    function buyMetaMetaMasks(uint _numberOfTokens) external payable {
        require(saleActive, "Meta MetaMask sale is not active.");
        require(_numberOfTokens <= mintLimit, "Too many tokens for one transaction.");
        require(msg.value >= mintPrice.mul(_numberOfTokens), "Unsufficient payment.");

        _mintMetaMasks(_numberOfTokens);
    }

    function _mintMetaMasks(uint _numberOfTokens) internal {
        require(totalSupply.add(_numberOfTokens) <= supplyLimit, "Not enough tokens left");

        uint256 newId = totalSupply;
        for(uint i = 0; i < _numberOfTokens; i++) {
            newId += 1;
            totalSupply = totalSupply.add(1);

            _safeMint(msg.sender, newId);
            emit MetaMetaMaskMinted(msg.sender, newId, tokenURI(newId)); // Say that function 3 times fast amiright
        }
    }

    /*********  Fund Functions  **********/
    function emergencyWithdraw() external onlyOwner {
        // Houston, we have a problem
        require(address(this).balance > 0, "No funds in smart Contract.");
        (bool success, ) = owner().call{value: address(this).balance}("");
        require(success, "Withdraw Failed.");
    }

    function withdrawAll() external {
        require(msg.sender == wallet1Address || msg.sender == wallet2Address || msg.sender == wallet3Address, "Only shareholders can call this method.");
        _withdraw();
    }

    function _withdraw() internal {
        require(address(this).balance > 0, "No balance to withdraw.");
        uint256 _amount = address(this).balance;
        (bool wallet1Success, ) = wallet1Address.call{value: _amount.mul(wallet1Share).div(100)}("");
        (bool wallet2Success, ) = wallet2Address.call{value: _amount.mul(wallet2Share).div(100)}("");
        (bool wallet3Success, ) = wallet3Address.call{value: _amount.mul(wallet3Share).div(100)}("");
        
        require(wallet1Success && wallet2Success && wallet3Success, "Withdrawal failed.");
    }

    // If this contract works, it was written by CyberAstronaut
    // If not, I don't know who wrote it
}