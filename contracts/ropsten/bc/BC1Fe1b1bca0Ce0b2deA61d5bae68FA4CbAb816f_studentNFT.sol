pragma solidity ^0.8.11;

import "ERC721.sol";
import "etsisi.sol";

contract studentNFT is ERC721, etsisi {

    event ChangeBaseURI(string oldURI, string newUri);

    uint256 public tokenCounter;

    string private baseURI;

    constructor() ERC721("ETSISI proof of student NFT", "ETSISI") {
        tokenCounter = 0;
        setBaseURI("ipfs:/base-uri/");
    }

    function setBaseURI(string memory uri) public onlyOwner {
        emit ChangeBaseURI(baseURI, uri);
        baseURI = uri;
    }

    function _baseURI() internal view override returns(string memory) {
        return baseURI;
    }

    function mintStudentNFT() public onlyStudent {
        require(balanceOf(msg.sender) == 0, "Student: student already minted an nft");
        _safeMint(msg.sender,  tokenCounter + 1);
        tokenCounter ++;
    }
}