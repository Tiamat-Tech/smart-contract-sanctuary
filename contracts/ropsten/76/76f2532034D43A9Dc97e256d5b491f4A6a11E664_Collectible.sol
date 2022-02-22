// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0; // Maybe use higher solidity version

// Use own ERC721 implementation
import "./ERC721.sol";
import "@openzeppelin/contracts/utils/Strings.sol";


//import "hardhat/console.sol"; // HARDHAT LOCAL TESTING

// Maybe use custom errors https://medium.com/coinmonks/solidity-revert-with-custom-error-explained-with-example-d9dff8937ef4
error TotalAmountWasMinted();
error MaxUserMintLimitWasReached();
error NotWhitelistedOrAlreadyMinted();
error EthValueTooLow();
error NotRealUser();
error NotAuthorized();
error TransferFailed();

contract Collectible is ERC721 {   
  using Strings for uint256;
    // immutable which causes them to be read-only, but assignable in the constructor
    uint256 public immutable maxMintsPerUser = 5;
    uint256 public immutable collectionSize = 10;

    uint256 public tokenCounter = 0;
    uint256 public publicPrice = 0.05 ether;
    address public owner;

    string private baseUri;

    // MISSING PROPERTIES
    // hasPublicMintStarted -> Also check in publicMint method and add a setter for this property
    // hasWhitelistMintStarted -> Also check in whitelistMint method and add a setter for this property

    mapping(address => bool) public whiteList;

    constructor() ERC721("TestoE", "TEST") {
        owner = msg.sender;
        baseUri = "https://gateway.pinata.cloud/ipfs/QmX4GXFJANM5JKVUtf5GMCcv3ewsDGXKsau1fDjtePDC2Q/";


        //console.log("OWNER", owner);
    }

    function publicMint(uint256 quantity) external payable callerIsUser
    {
        if(balanceOf[msg.sender] + quantity > maxMintsPerUser) revert MaxUserMintLimitWasReached();

        uint256 _tokenCounter = tokenCounter;

        if(_tokenCounter + quantity > collectionSize) { //                 8 + 3   >  10      =true
            quantity = collectionSize - _tokenCounter; //                 10  -  8            =2(leftover)
            if(quantity == 0) revert TotalAmountWasMinted(); //                               =false
        }


        for(uint256 i = 0; i < quantity; i++) {
            _safeMint(msg.sender, _tokenCounter);// todo maybe use _mint instead
            unchecked {
                _tokenCounter++;
            }
        }

        tokenCounter=_tokenCounter;
        
        refundIfOver(publicPrice * quantity);
    }

    function refundIfOver(uint256 price) private 
    {
        if(msg.value < price) revert EthValueTooLow();
        // Maybe remove the following lines
        if (msg.value > price) {
            payable(msg.sender).transfer(msg.value - price);
        }
    }

    function whitelistMint() external payable {
        if(!whiteList[msg.sender]) revert NotWhitelistedOrAlreadyMinted();
        if(tokenCounter + 1 > collectionSize) revert TotalAmountWasMinted();

        whiteList[msg.sender] = false;
        _safeMint(msg.sender, tokenCounter);// todo maybe use _mint instead
        unchecked {
            tokenCounter++;    
        }
        refundIfOver(publicPrice);
    }

    function withdrawMoney() external onlyOwner
    {
        (bool success, ) = msg.sender.call{value: address(this).balance}("");
        if(!success) revert TransferFailed();
    }

    // SETTER SECTION -------------------------------------------------------------------
    function setBaseURI(string calldata _baseUri) external onlyOwner
    {
        baseUri = _baseUri;
    }

    function setWhiteListUsers(address[] calldata users) external onlyOwner {
        for (uint256 i = 0; i < users.length; i++) {
           whiteList[users[i]] = true;// TODO maybe use unchecked  (compare gas costs)
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
        if(msg.sender != owner) revert NotAuthorized();
    }

    function isCallerUser() internal view {
        if(tx.origin != msg.sender) revert NotRealUser();
    }

    //INTERFACE SATISFACTION-------------------------------------------------------------
    function tokenURI(uint256 id) public view override returns (string memory) {
    return string(abi.encodePacked(baseUri, id.toString(), '.json'));
    }
}