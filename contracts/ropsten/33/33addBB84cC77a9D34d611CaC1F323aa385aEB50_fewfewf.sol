// SPDX-License-Identifier: MIT
    pragma solidity ^0.8.0;
    
    import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
    import "@openzeppelin/contracts/utils/math/SafeMath.sol";
    import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
    import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
    import "@openzeppelin/contracts/access/Ownable.sol";
    import "@openzeppelin/contracts/security/Pausable.sol";
    
    contract fewfewf is Ownable, IERC721Metadata, ERC721, ERC721Burnable{
        
        bool _isActive = true;
        
        bool _discountIsActive = true;
        
        modifier checkActive() {
            require (_isActive);
            _;
        }
        
        modifier checkActiveDiscount() {
            require (_discountIsActive);
            _;
        }
    
        using SafeMath for uint256;
        
        uint[] private shankIDsUsed;
        
        string private newURI = "/";
        
        //this is actually 10k because the first NFT ID is 0
        uint256 public constant MAX_NFT_SUPPLY = 1000;
        
        mapping(string => bool) _colorExists;
    
        constructor() ERC721("eweqwe", "2321312") {
        }
        
        function setURI(string memory _newURI) public onlyOwner{
            newURI = _newURI;
        }
        
        function _baseURI() internal view override returns (string memory) {
            return newURI;
        }
        
    
        // numberOfNfts = number you want to mint
        function mintNFT(uint256 numberOfNfts) public payable checkActive{
            require(totalSupply() <= MAX_NFT_SUPPLY, "Sale has already ended");
            require(numberOfNfts > 0 && numberOfNfts <= 20, "You can make minimum 1, maximum 20 knives");
            require(totalSupply().add(numberOfNfts) <= MAX_NFT_SUPPLY, "Exceeds MAX_NFT_SUPPLY");
            require(msg.value >= getNFTPrice().mul(numberOfNfts), "Ether value sent is not correct");
            
            for (uint i = 0; i < numberOfNfts; i++) {
                shankIDsUsed.push(shankIDsUsed.length + 1);
                uint _tokenid = shankIDsUsed.length - 1;
                _safeMint(msg.sender, _tokenid);
            }
        }
        
        function discountMintNFT(uint256 numberOfNfts) public payable checkActiveDiscount{
            
            //if ID is in DiscountIDs and is not in DiscountIDsUsed = 
            require(totalSupply() <= MAX_NFT_SUPPLY, "Sale has already ended");
            require(numberOfNfts > 0 && numberOfNfts <= 20, "You can make minimum 1, maximum 20 knives");
            require(totalSupply().add(numberOfNfts) <= MAX_NFT_SUPPLY, "Exceeds MAX_NFT_SUPPLY");
            require(msg.value >= getNFTPrice().mul(numberOfNfts), "Ether value sent is not correct");
            
            for (uint i = 0; i < numberOfNfts; i++) {
                shankIDsUsed.push(shankIDsUsed.length + 1);
                uint _tokenid = shankIDsUsed.length - 1;
                _safeMint(msg.sender, _tokenid);
            }
        }
        
        function totalSupply() public view returns (uint256) {
            // _tokenOwners are indexed by tokenIds, so .length() returns the number of tokenIds
           return shankIDsUsed.length;
        }
        
        
        function getNFTPrice() public view returns (uint256) {
            require(totalSupply() < MAX_NFT_SUPPLY, "Sale has already ended");
    
            uint currentSupply = totalSupply();
            
            if (currentSupply >= 990) {
                return 1000000000000000000;        // 990-1000: 1.00 ETH
            } else if (currentSupply >= 950) {
                return 600000000000000000;         // 950-990:  0.6 ETH
            } else if (currentSupply >= 750) {
                return 300000000000000000;         // 750-950:  0.3 ETH
            } else if (currentSupply >= 350) {
                return 100000000000000000;         // 350-750:  0.1 ETH
            } else if (currentSupply >= 150) {
                return 80000000000000000;          // 150-350:  0.08 ETH 
            } else if (currentSupply >= 50) {
                return 40000000000000000;          // 50-150:   0.04 ETH 
            } else {
                return 20000000000000000;          // 0 - 50     0.02 ETH
            }
        }
        
        function getNFTPriceDiscount() public view returns (uint256) {
            require(totalSupply() < MAX_NFT_SUPPLY, "Sale has already ended");
    
            uint currentSupply = totalSupply();
            
            if (currentSupply >= 990) {
                return 1000000000000000000;        // 990-1000: 1.00 ETH
            } else if (currentSupply >= 950) {
                return 600000000000000000;         // 950-990:  0.45 ETH
            } else if (currentSupply >= 750) {
                return 225000000000000000;         // 750-950:  0.225 ETH
            } else if (currentSupply >= 350) {
                return 75000000000000000;         // 350-750:  0.075 ETH
            } else if (currentSupply >= 150) {
                return 60000000000000000;          // 150-350:  0.06 ETH 
            } else if (currentSupply >= 50) {
                return 40000000000000000;          // 50-150:   0.03 ETH 
            } else {
                return 15000000000000000;          // 0 - 50     0.015 ETH
            }
        }
        
    
        function setActivity(bool isActive) public {
            // restrict access to this function
            _isActive = isActive;
        }
        
        function setDiscountActivity(bool discountIsActive) public {
            // restrict access to this function
            _discountIsActive = discountIsActive;
        }
    
        function withdrawAll() public payable onlyOwner {
            require(payable(msg.sender).send(address(this).balance));
        }
    }