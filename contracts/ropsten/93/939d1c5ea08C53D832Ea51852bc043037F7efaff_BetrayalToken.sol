pragma solidity ^0.6.2;

import '../node_modules/@openzeppelin/contracts/access/Ownable.sol';
import '../node_modules/@openzeppelin/contracts/utils/Context.sol';
import '../node_modules/@openzeppelin/contracts/utils/Counters.sol';
import '../node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol';
import '../node_modules/@openzeppelin/contracts/token/ERC721/ERC721Burnable.sol';
import '../node_modules/@openzeppelin/contracts/token/ERC721/ERC721Pausable.sol';

contract BetrayalToken is Context, Ownable, ERC721, ERC721Burnable, ERC721Pausable {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdTracker;

    constructor() ERC721('Betrayal.io', 'BTRYL') public {
        _setBaseURI('https://betrayal.io/api/ether/token/');
    }

    function mint(address toAddress) public onlyOwner {
        _tokenIdTracker.increment();

        _mint(toAddress, _tokenIdTracker.current());
    }

    function mintMulti(address[] memory toAddresses) public onlyOwner {
        uint256 addressCount = toAddresses.length;

        for (uint256 i = 0; i < addressCount; i++) {
            _tokenIdTracker.increment();

            _mint(toAddresses[i], _tokenIdTracker.current());
        }
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal virtual override(ERC721, ERC721Pausable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }
}