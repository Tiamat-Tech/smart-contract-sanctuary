// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";


contract Cathode is Ownable, ERC721 {

    event Mint(uint indexed _tokenId);

    uint public maxSupply = 1000;
    uint public totalSupply = 0;
    uint public limitPerAccount = 5;
    bool private saleState = false;
    uint256 constant public PRICE = 0.07 ether;
    
    address payable claimEthAddress;
    
    string private _baseURIextended = "https://artstart.mypinata.cloud/ipfs/Qmf9Y2Lfo3G5W2FNp1qbhrvbFnWUAKMgw3KTCtLjwQZNGD/Cathode%20%23";

    mapping(address => uint) public mintCounts; // Amount minted per user
    mapping (uint256 => string) private _tokenURIs;

    constructor(address payable _claimEthAddress) payable ERC721("Cathode", "CATHODE") {
        claimEthAddress = _claimEthAddress;
    }
    
    function mint(address to, uint quantity) public payable {
        require(saleState == true , "Sale has not yet been unlocked");
        require(quantity > 0, "Can't mint zero tokens.");
        require(totalSupply + quantity <= maxSupply, "maxSupply of mints already reached");
        require(mintCounts[to] + quantity <= limitPerAccount, "max 5 mints per account");
        require(PRICE * quantity <= msg.value, "ETH sent is incorrect");
        for (uint i = 0; i < quantity; i++) {
            totalSupply += 1; // 1-indexed instead of 0
            _mint(to, totalSupply);
            _setTokenURI(totalSupply, _baseURIextended);
            mintCounts[to] += 1;
            emit Mint(totalSupply);
        }
    }
    
    function _setTokenURI(uint256 tokenId, string memory _tokenURI) internal virtual {
        require(_exists(tokenId), "ERC721Metadata: URI set of nonexistent token");
        _tokenURIs[tokenId] = _tokenURI;
    }
    
    function _baseURI() internal view virtual override returns (string memory) {
        return _baseURIextended;
    }
    
    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

        string memory baseURI = _baseURI();
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, uint2str(tokenId), '.json')) : "";
    }
    
    function uint2str(uint _i) internal pure returns (string memory _uintAsString) {
        if (_i == 0) {
            return "0";
        }
        uint j = _i;
        uint len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint k = len;
        while (_i != 0) {
            k = k-1;
            uint8 temp = (48 + uint8(_i - _i / 10 * 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            _i /= 10;
        }
        return string(bstr);
    }
    
    function flipSaleState() public onlyOwner {
        saleState = !saleState;
    }
    
    function claimETH() public {
        require(claimEthAddress == _msgSender(), "Ownable: caller is not the claimEthAddress");
        payable(address(claimEthAddress)).transfer(address(this).balance);
    }
}