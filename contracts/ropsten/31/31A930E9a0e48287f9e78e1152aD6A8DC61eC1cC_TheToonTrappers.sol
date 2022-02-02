// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract OwnableDelegateProxy {}

contract ProxyRegistry {
    mapping(address => OwnableDelegateProxy) public proxies;
}

abstract contract ContextMixin {
    function msgSender()
        internal
        view
        returns (address payable sender)
    {
        if (msg.sender == address(this)) {
            bytes memory array = msg.data;
            uint256 index = msg.data.length;
            assembly {
                // Load the 32 bytes word from memory with the address on the lower 20 bytes, and mask those.
                sender := and(
                    mload(add(array, index)),
                    0xffffffffffffffffffffffffffffffffffffffff
                )
            }
        } else {
            sender = payable(msg.sender);
        }
        return sender;
    }
}

contract TheToonTrappers is ERC721Enumerable, ContextMixin, Ownable {
    uint public constant MAX_TOONS = 9999;
    string _baseTokenURI;

    address proxyRegistryAddress = 0xa5409ec958C83C3f309868babACA7c86DCB077c1;

    uint256 presaleDate = 1643929200; //Feb 4
    uint256 saleDate = 1644015600; // Feb 5

    uint256 PRICE = 69000000000000000; //0.069 ETH

    mapping(address=>uint256) public canBuyDuringPresale;
    mapping(address=>uint256) public canGetForFree;

    constructor() ERC721("TheToonTrappers", "TOON")  {
        _setBaseURI('https://thetoontrappers.com/api/metadata/');
        
        for(uint i = 0; i < 10; i++){
            _safeMint(_msgSender(), totalSupply());
        }
    }

    function claimFreeTokens(uint _count) public {
        require(canGetForFree[msg.sender] >= _count, "Nothing to claim");

        canGetForFree[msg.sender] -= _count;

        mintForUser(msg.sender, _count);
    }

    function mintForUser(address _to, uint256 _count) internal {
        for(uint i = 0; i < _count; i++){
            _safeMint(_to, totalSupply());
        }
    }

    function mintToons(uint _count) public payable {
        require(block.timestamp > presaleDate, "Sale not started");
        require(_count <= 5, "Exceeds 5");
        require(totalSupply() + _count <= MAX_TOONS, "Max limit");

        if (block.timestamp < saleDate) {
            require(canBuyDuringPresale[msg.sender] > 0, "Not whitelisted");
            canBuyDuringPresale[msg.sender] -= _count;
            mintForUser(msg.sender, _count);
        } else {
            require(msg.value == PRICE * _count, "Invalid value");
            mintForUser(msg.sender, _count);
        }
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }

    function walletOfOwner(address _owner) external view returns(uint256[] memory) {
        uint tokenCount = balanceOf(_owner);

        uint256[] memory tokensId = new uint256[](tokenCount);
        for(uint i = 0; i < tokenCount; i++){
            tokensId[i] = tokenOfOwnerByIndex(_owner, i);
        }

        return tokensId;
    }

    function _setBaseURI(string memory baseURI) public onlyOwner {
        _baseTokenURI = baseURI;
    }
    
    function _setCanBuyDuringPresale(address[] memory _addresses, uint256 _total) public onlyOwner {
        for(uint i = 0; i < _addresses.length; i++){
            canBuyDuringPresale[_addresses[i]] += _total;
        }
    }

    function _setCanGetForFree(address[] memory _addresses, uint256 _total) public onlyOwner {
        for(uint i = 0; i < _addresses.length; i++){
            require(canGetForFree[_addresses[i]] + _total <= 5, "Too many free tokens");

            canGetForFree[_addresses[i]] += _total;
        }
    }
    
    function _withdrawFees() public {
        require(payable(owner()).send(address(this).balance));
    }

    /**
     * This is used instead of msg.sender as transactions won't be sent by the original token owner, but by OpenSea.
     */
    function _msgSender()
        internal
        override
        view
        returns (address sender)
    {
        return ContextMixin.msgSender();
    }
    
    /**
   * Override isApprovedForAll to auto-approve OS's proxy contract
   */
    function isApprovedForAll(
        address _owner,
        address _operator
    ) public override view returns (bool isOperator) {
        // Whitelist OpenSea proxy contract for easy trading.
        ProxyRegistry proxyRegistry = ProxyRegistry(proxyRegistryAddress);
        if (address(proxyRegistry.proxies(_owner)) == _operator) {
            return true;
        }
        // otherwise, use the default ERC721.isApprovedForAll()
        return ERC721.isApprovedForAll(_owner, _operator);
    }
}