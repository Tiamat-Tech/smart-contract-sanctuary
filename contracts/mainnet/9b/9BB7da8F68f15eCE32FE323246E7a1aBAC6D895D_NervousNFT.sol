// SPDX-License-Identifier: MIT
pragma solidity ^0.7.4;
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/payment/PaymentSplitter.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

//        nervous.eth
//
//
// ██████╗██████╗ ██╗   ██╗██████╗ ████████╗██╗██████╗      ██████╗ ██████╗ ██╗     ██╗     ███████╗ ██████╗████████╗██╗██╗   ██╗███████╗
//██╔════╝██╔══██╗╚██╗ ██╔╝██╔══██╗╚══██╔══╝██║██╔══██╗    ██╔════╝██╔═══██╗██║     ██║     ██╔════╝██╔════╝╚══██╔══╝██║██║   ██║██╔════╝
//██║     ██████╔╝ ╚████╔╝ ██████╔╝   ██║   ██║██║  ██║    ██║     ██║   ██║██║     ██║     █████╗  ██║        ██║   ██║██║   ██║█████╗  
//██║     ██╔══██╗  ╚██╔╝  ██╔═══╝    ██║   ██║██║  ██║    ██║     ██║   ██║██║     ██║     ██╔══╝  ██║        ██║   ██║╚██╗ ██╔╝██╔══╝  
//╚██████╗██║  ██║   ██║   ██║        ██║   ██║██████╔╝    ╚██████╗╚██████╔╝███████╗███████╗███████╗╚██████╗   ██║   ██║ ╚████╔╝ ███████╗
// ╚═════╝╚═╝  ╚═╝   ╚═╝   ╚═╝        ╚═╝   ╚═╝╚═════╝      ╚═════╝ ╚═════╝ ╚══════╝╚══════╝╚══════╝ ╚═════╝   ╚═╝   ╚═╝  ╚═══╝  ╚══════╝
//                                                                                                                                       
//██╗  ██╗                                                                                                                               
//╚██╗██╔╝                                                                                                                               
// ╚███╔╝                                                                                                                                
// ██╔██╗                                                                                                                                
//██╔╝ ██╗                                                                                                                               
//╚═╝  ╚═╝                                                                                                                               
//                                                                                                                                       
//███╗   ██╗███████╗██████╗ ██╗   ██╗ ██████╗ ██╗   ██╗███████╗   ███████╗████████╗██╗  ██╗                                              
//████╗  ██║██╔════╝██╔══██╗██║   ██║██╔═══██╗██║   ██║██╔════╝   ██╔════╝╚══██╔══╝██║  ██║                                              
//██╔██╗ ██║█████╗  ██████╔╝██║   ██║██║   ██║██║   ██║███████╗   █████╗     ██║   ███████║                                              
//██║╚██╗██║██╔══╝  ██╔══██╗╚██╗ ██╔╝██║   ██║██║   ██║╚════██║   ██╔══╝     ██║   ██╔══██║                                              
//██║ ╚████║███████╗██║  ██║ ╚████╔╝ ╚██████╔╝╚██████╔╝███████║██╗███████╗   ██║   ██║  ██║                                              
//╚═╝  ╚═══╝╚══════╝╚═╝  ╚═╝  ╚═══╝   ╚═════╝  ╚═════╝ ╚══════╝╚═╝╚══════╝   ╚═╝   ╚═╝  ╚═╝                                              
//                                                                                                                                       
//
//        work with us: nervous.net // [email protected]


contract NervousNFT is ERC721, PaymentSplitter, Ownable {

    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    uint public MAX_TOKENS = 10101;
    uint public tokenPrice = 60000000000000000; // 0.06 ETH

    bool public hasSaleStarted = true;
    string public constant R = "We are Nervous. Are you? Let us help you with your next NFT Project -> [email protected]";
    
    constructor(string memory name, string memory symbol, string memory baseURI, address[] memory payees, uint256[] memory shares) ERC721(name, symbol) PaymentSplitter(payees, shares) {
  
        _setBaseURI(baseURI);
    }

    function setBaseURI(string memory baseURI) public onlyOwner {
        _setBaseURI(baseURI);
    }
    function calculatePrice() public view returns (uint256) {
        require(hasSaleStarted == true, "Sale hasn't started");
        require(totalSupply() < MAX_TOKENS, "No more tokens");
        return tokenPrice;  // 0.06 ETH
    }
    function startSale() public onlyOwner {
        hasSaleStarted = true;
    }
    
    function pauseSale() public onlyOwner {
        hasSaleStarted = false;
    }
    function mint(uint256 numTokens) public payable {
        require(SafeMath.add(totalSupply(), 1) <= MAX_TOKENS, "Exceeds maximum token supply.");
        require(numTokens > 0 && numTokens <= 10, "Machine can dispense a minimum of 1, maximum of 10 tokens");
        require(msg.value >= SafeMath.mul(calculatePrice(), numTokens), "Amount of Ether sent is not correct.");
        
        for (uint i = 0; i < numTokens; i++) {
            uint mintIndex = totalSupply();
            _safeMint(msg.sender, mintIndex);
        }
        
    }
    function magicMint(uint256 numTokens) external  onlyOwner {
        require(SafeMath.add(totalSupply(), numTokens) <= MAX_TOKENS, "Exceeds maximum token supply.");
        require(numTokens > 0 && numTokens <= 100, "Machine can dispense a minimum of 1, maximum of 100 tokens");

        for (uint i = 0; i < numTokens; i++) {
            uint mintIndex = totalSupply();
            _safeMint(msg.sender, mintIndex);
        }
    }
}