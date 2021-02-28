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
        _setBaseURI('https://betrayal.io/api/erc721/token/');
    }

    function mint(address to) public onlyOwner {
        _tokenIdTracker.increment();

        _mint(to, _tokenIdTracker.current());
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