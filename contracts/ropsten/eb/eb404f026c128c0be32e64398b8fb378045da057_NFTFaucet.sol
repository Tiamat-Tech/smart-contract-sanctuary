// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract NFTFaucet is ERC721Enumerable, Ownable {
    using Strings for uint256;

    uint256 public constant MINT_LIMIT = 42;
    bool public isFaucetActive = true;
    string private baseTokenURI;

    event faucetPaused(bool paused);
    event tokenMinted(uint256 indexed id, address owner);

    constructor() ERC721("NFTFaucet", "NFTF") {
        setBaseURI("nftf://");
    }

    modifier faucetIsActive() {
        require(isFaucetActive, "Faucet on pause");
        _;
    }

    function setBaseURI(string memory _baseURI) public onlyOwner {
        baseTokenURI = _baseURI;
    }

    function setFaucetActiveStatus(bool _isFaucetActive) external onlyOwner {
        isFaucetActive = _isFaucetActive;
        emit faucetPaused(!_isFaucetActive);
    }

    function withdrawAll() public payable onlyOwner {
        uint balance = address(this).balance;
        payable(msg.sender).transfer(balance);
    }

    function mint(address to, uint256 num) external faucetIsActive {
        require(num <= MINT_LIMIT, "Don't be greedy :)");
        uint256 supply = totalSupply();

        for(uint256 i = 0; i < num; i++) {
            uint256 mintIndex = supply + i;
            _safeMint(to, mintIndex);
            emit tokenMinted(mintIndex, to);
        }
    }

    function tokenURI(uint256 _tokenId) public view virtual override returns (string memory) {
      require(_exists(_tokenId), 'Token does not exist');

      return bytes(baseTokenURI).length > 0 ? string(abi.encodePacked(baseTokenURI, _tokenId.toString())) : "";
    }

    function walletOfOwner(address _owner) external view returns(uint256[] memory) {
        uint256 tokenCount = balanceOf(_owner);

        uint256[] memory tokensId = new uint256[](tokenCount);
        for(uint256 i; i < tokenCount; i++){
            tokensId[i] = tokenOfOwnerByIndex(_owner, i);
        }
        return tokensId;
    }
}