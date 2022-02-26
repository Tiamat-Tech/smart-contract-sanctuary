// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0; // Maybe use higher solidity version

// Use own ERC721 implementation
import "./ERC721MULTI.sol";
import "@openzeppelin/contracts/utils/Strings.sol";


import "hardhat/console.sol"; // HARDHAT LOCAL TESTING

// Maybe use custom errors https://medium.com/coinmonks/solidity-revert-with-custom-error-explained-with-example-d9dff8937ef4
error TotalAmountWasMinted();
error MaxUserMintLimitWasReached();
error NotWhitelistedOrAlreadyMinted();
error EthValueTooLow();
error CalledByContract();
error NotAuthorized();
error TransferFailed();

contract Collectible is ERC721MULTI {   
  using Strings for uint256;
    // immutable which causes them to be read-only, but assignable in the constructor

    uint256 public publicPrice = 0.05 ether;
    address public owner;

    string private baseUri;

    // MISSING PROPERTIES
    // hasPublicMintStarted -> Also check in publicMint method and add a setter for this property and add tests
    // hasWhitelistMintStarted -> Also check in whitelistMint method and add a setter for this property and add tests

    mapping(address => bool) public whiteList;

    constructor() {
        owner = _msgSender();
        baseUri = "https://gateway.pinata.cloud/ipfs/QmX4GXFJANM5JKVUtf5GMCcv3ewsDGXKsau1fDjtePDC2Q/";
    }

    function publicMint(uint256 quantity) external payable 
    {
        if(!calledByUser())revert CalledByContract();
        if(balances[_msgSender()] + quantity > state.maxMintsPerUser) revert MaxUserMintLimitWasReached();
        if(state.tokenCounter + quantity > state.collectionSize) revert TotalAmountWasMinted();

        _safeMint(_msgSender(), quantity);

        refundIfOver(publicPrice * quantity);
    }

    function refundIfOver(uint256 price) private
    {
        if(msg.value < price) revert EthValueTooLow();
        // Maybe remove the following lines
        if (msg.value > price) {
            payable(_msgSender()).transfer(msg.value - price);
        }
    }

    function whitelistMint() external payable {
        if(!whiteList[_msgSender()]) revert NotWhitelistedOrAlreadyMinted();
        if(state.tokenCounter + 1 > state.collectionSize) revert TotalAmountWasMinted();

        whiteList[_msgSender()] = false;
        _safeMint(_msgSender(), 1);
        refundIfOver(publicPrice);
    }

    function withdrawMoney() external onlyOwner
    {
        (bool success, ) = _msgSender().call{value: address(this).balance}("");
        if(!success) revert TransferFailed();
    }

    // MODIFIER SECTION -----------------------------------------------------------------
    modifier onlyOwner() {
        isAuthorized();
        _;
    }

    function isAuthorized() internal view {
        if(_msgSender() != owner) revert NotAuthorized();
    }

    // EXTERNAL GETTER SECTION -----------------------------------------------------------

    function tokenURI(uint256 id) external view returns (string memory) {
        return string(abi.encodePacked(baseUri, id.toString(), '.json'));
    }

    function balanceOf(address from)external view returns (uint256){
    if(owner == address(0)) revert("balance of zero address");
        return balances[from];
    }

    // EXTERNAL SETTER SECTION ------------------------------------------------------------
    function setBaseURI(string calldata _baseUri) external onlyOwner
    {
        baseUri = _baseUri;
    }

    function setWhiteListUsers(address[] calldata users) external onlyOwner {
        for (uint256 i = 0; i < users.length; i++) {
           whiteList[users[i]] = true;// TODO maybe use unchecked  (compare gas costs)
        }
    }
}