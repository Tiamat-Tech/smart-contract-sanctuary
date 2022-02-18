// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0; // Maybe use higher solidity version

// Use own ERC721 implementation
import "ERC721.sol";

// Maybe use custom errors https://medium.com/coinmonks/solidity-revert-with-custom-error-explained-with-example-d9dff8937ef4
error TotalAmountWasMinted();
error NotWhitelisted();
error EthValueTooLow(uint256 sent, uint256 required);

contract Collectible is ERC721 {
    // immutable which causes them to be read-only, but assignable in the constructor
    uint256 public immutable maxPerAddressDuringMint;

    uint256 public tokenCounter = 0;
    uint256 public collectionSize = 10;
    uint256 public publicPrice = 0.05 ether;
    address public owner;
    string private baseTokenURI;

    mapping(address => bool) public whiteList;

    constructor() ERC721("TestoE", "TEST") {
        owner = msg.sender;
        maxPerAddressDuringMint = 5;
        baseTokenURI = "https://gateway.pinata.cloud/ipfs/QmX4GXFJANM5JKVUtf5GMCcv3ewsDGXKsau1fDjtePDC2Q/"; // ONLY FOR TESTING
    }

    function publicSaleMint(uint256 quantity) external payable callerIsUser
    {
        require(tokenCounter + quantity <= collectionSize, "reached max supply");
        require(balanceOf(msg.sender) + quantity <= maxPerAddressDuringMint, "can not mint this many");

        for(uint256 i = 0; i < quantity; i++) {
            _safeMint(msg.sender, tokenCounter);
            unchecked {
                tokenCounter++;    
            }
        }
        
        refundIfOver(publicPrice * quantity);
    }

    // function publicSaleMint(uint256 quantity) external payable callerIsUser
    // {
    //     for(uint256 i = 0; i < quantity && tokenCounter<collectionSize && balanceOf(msg.sender) < maxPerAddressDuringMint; i++) {
    //         _safeMint(msg.sender, tokenCounter);
    //         unchecked {
    //             tokenCounter++;    
    //         }
    //     }
    //     refundIfOver(publicPrice * quantity);
    // }

    function refundIfOver(uint256 price) private 
    {
        if(msg.value < price) revert EthValueTooLow({
            sent: msg.value,
            required: price
        });
        // Maybe remove the following lines
        if (msg.value > price) {
            payable(msg.sender).transfer(msg.value - price);
        }
    }

    function whitelistMint() public payable {
        if(tokenCounter + 1 > collectionSize) revert TotalAmountWasMinted();
        if(!whiteList[msg.sender]) revert NotWhitelisted();

        whiteList[msg.sender] = false;
        _safeMint(msg.sender, tokenCounter);
        unchecked {
            tokenCounter++;    
        }
        refundIfOver(publicPrice);
    }

    function _baseURI() internal view virtual override returns (string memory)
    {
        return baseTokenURI;
    }

    function withdrawMoney() external onlyOwner
    {
        (bool success, ) = msg.sender.call{value: address(this).balance}("");
        require(success, "Transfer failed.");
    }

    // SETTER SECTION -------------------------------------------------------------------
    function setBaseURI(string calldata baseURI) external onlyOwner
    {
        baseTokenURI = baseURI;
    }

    function whiteListUser(address user) public onlyOwner {
        whiteList[user] = true;
    }

    function whiteListUsers(address[] calldata users) public onlyOwner {
        for (uint256 i = 0; i < users.length; i++) {
           whiteList[users[i]] = true; 
        }
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