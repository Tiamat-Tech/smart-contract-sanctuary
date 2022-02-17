// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0; // Maybe use higher solidity version

// Maybe use custom errors https://medium.com/coinmonks/solidity-revert-with-custom-error-explained-with-example-d9dff8937ef4

// Use own ERC721 implementation
import "ERC721.sol";

contract Collectible is ERC721 {
    // immutable which causes them to be read-only, but assignable in the constructor
    uint256 public immutable maxPerAddressDuringMint;

    uint256 public tokenCounter = 0;
    uint256 public collectionSize = 10;
    uint256 public publicPrice = 0.05 ether;
    address public owner;
    string private baseTokenURI;

    constructor() ERC721("TestoE", "TEST") {
        owner = msg.sender;
        maxPerAddressDuringMint = 5;
        baseTokenURI = "https://gateway.pinata.cloud/ipfs/QmX4GXFJANM5JKVUtf5GMCcv3ewsDGXKsau1fDjtePDC2Q/"; // ONLY FOR TESTING
    }

    // function publicSaleMint(uint256 quantity) external payable callerIsUser
    // {
    //     require(tokenCounter + quantity <= collectionSize, "reached max supply");
    //     require(balanceOf(msg.sender) + quantity <= maxPerAddressDuringMint, "can not mint this many");

    //     for(uint256 i = 0; i < quantity; i++) {
    //         _safeMint(msg.sender, tokenCounter);
    //         unchecked {
    //             tokenCounter++;    
    //         }
    //     }
        
    //     refundIfOver(publicPrice * quantity);
    // }

    function publicSaleMint(uint256 quantity) external payable callerIsUser
    {

        uint8 minted = 0;
        for(uint8 i = 0; i < quantity && tokenCounter<collectionSize && balanceOf(msg.sender) < maxPerAddressDuringMint; i++) {
            _safeMint(msg.sender, tokenCounter);
            unchecked {
                tokenCounter++;
                minted++;    
            }
        }
        refundIfOver(publicPrice * minted);
    }

    function refundIfOver(uint256 price) private 
    {
        require(msg.value >= price, "Need to send more ETH.");
        // Maybe remove the following lines
        if (msg.value > price) {
            payable(msg.sender).transfer(msg.value - price);
        }
    }

    function _baseURI() internal view virtual override returns (string memory)
    {
        return baseTokenURI;
    }

    function setBaseURI(string calldata baseURI) external onlyOwner
    {
        baseTokenURI = baseURI;
    }

    function withdrawMoney() external onlyOwner
    {
        (bool success, ) = msg.sender.call{value: address(this).balance}("");
        require(success, "Transfer failed.");
    }

    // MODIFIER SECTION -----------------------------------------------------------------
    modifier onlyOwner() {
        isAuthorized();
        _;
    }

    modifier callerIsUser() {
        isCallerUser();
        _;
    }

    // MODIFIER FUNCTION SECTION --------------------------------------------------------
    function isAuthorized() internal view {
        require(msg.sender == owner, "YOU ARE NOT THE OWNER!");
    }

    function isCallerUser() internal view {
        require(tx.origin == msg.sender, "The caller is another contract");
    }
}