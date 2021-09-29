// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";


contract GenericNFTCollection is ERC721Enumerable, Ownable, ReentrancyGuard {

    using Strings for uint256;

		// maximum number of tokens reserved(i.e giveaways, team etc.)
    uint256 public constant RESERVED_SUPPLY = 111;
		// maximum number of tokens available to be minted for presale & public sale
    uint256 public constant PUBLIC_SUPPLY = 9889;
		// maximum number of tokens ever gonna be minted on this contract
    uint256 public constant MAX_SUPPLY = RESERVED_SUPPLY + PUBLIC_SUPPLY;
		// price of a single NFT
    uint256 public constant PRICE = 0.08 ether;
		// max. number of tokens that can be purchased in one sale transaction
    uint256 public constant MAX_PER_TRANSACTION = 5;
		// max. number of tokens that can be purchased at pre-sale by single address
    uint256 public MAX_PER_ADDRESS_AT_PRESALE = 3;
		// max. number of tokens that can be purchased by single address
	uint256 public constant MAX_PER_ADDRESS = 50;


		// how many tokens were already minted from reserved
    uint256 public reservedAmountMinted;
		// how many tokens were already minted for public sale
    uint256 public publicSaleAmountMinted;
		// how many tokens were already minted for pre-sale
    uint256 public presaleAmountMinted;


    // fill this out when calculated
    string public proof;


		// can be used to launch and pause the pre-sale
    bool public presaleActive;
		// can be used to launch and pause the sale
    bool public saleActive;
		// can be used to reveal tokens metadata
    bool public revealed = false;


		// addresses that can participate in the presale event
    mapping(address => bool) private _presaleEligibleList;
		// how many presale tokens are minted by address
    mapping(address => uint256) private _presaleTokensMinted;
		// how many sale tokens are minted by address
    mapping(address => uint256) private _publicSaleTokensMinted;
		// how many mintGtokens are minted by address
    mapping(address => uint256) private _reservedTokensMinted;
		// how many total tokens are minted by address
    mapping(address => uint256) private _totalTokensMinted;


    string private _contractURI;
	string private _tokenBaseURI;
	string private _baseExtension = ".json";
	// URI shown when token is not revealed
	string private _tokenNotRevealedURI;

    event BaseURIChanged(string baseURI);
    event PresaleMint(address minter, uint256 count);
    event PublicSaleMint(address minter, uint256 count);
	event ReservedMint(address recipient, uint256 count);
	event TotalSupplyChanged(uint256 count);
	event PreSaleStatusChanged(bool status);
	event SaleStatusChanged(bool status);

    constructor(string memory _name,string memory _symbol,string memory _initTokenBaseURI,string memory _initNotRevealedURI) ERC721(_name, _symbol) {
		_tokenBaseURI = _initTokenBaseURI;
		_tokenNotRevealedURI = _initNotRevealedURI;
	}

    // INTERNALS

    function _baseURI() internal view virtual override returns (string memory) {
        return _tokenBaseURI;
    }

		// PUBLIC

    // purchase tokens from the contract sale
    function mint(uint256 tokenQuantity) external nonReentrant payable {
		require(saleActive, "SALE_NOT_ACTIVE");
        require(totalSupply() < MAX_SUPPLY, "SOLD_OUT");
		require(totalSupply() + tokenQuantity <= MAX_SUPPLY, "MINTING_WOULD_EXCEED_MAX_SUPPLY");
        require(publicSaleAmountMinted + tokenQuantity <= PUBLIC_SUPPLY, "MINTING_WOULD_EXCEED_PUBLIC_SUPPLY");
        require(tokenQuantity <= MAX_PER_TRANSACTION, "MINTING_WOULD_EXCEED_PER_TRANSACTION_LIMIT");
		require(_totalTokensMinted[msg.sender] + tokenQuantity <= MAX_PER_ADDRESS, "MINTING_WOULD_EXCEED_PER_ADDRESS_LIMIT");
        require(PRICE * tokenQuantity <= msg.value, "INSUFFICIENT_ETH");
		require(tokenQuantity > 0, "TOKEN_QUANTITY_INCORRECT");


        for(uint256 i = 0; i < tokenQuantity; i++) {
            publicSaleAmountMinted++;
						_publicSaleTokensMinted[msg.sender]++;
						_totalTokensMinted[msg.sender]++;
            _safeMint(msg.sender, totalSupply() + 1);
        }

		emit PublicSaleMint(msg.sender, tokenQuantity);
		emit TotalSupplyChanged(totalSupply());
    }

    // purchase tokens from the contract presale
    function mintPresale(uint256 tokenQuantity) external nonReentrant payable {
		require(presaleActive, "PRESALE_NOT_ACTIVE");
        require(!saleActive, "PUBLIC_SALE_IS_NOW_ACTIVE");
        require(_presaleEligibleList[msg.sender], "PRESALE_NOT_AUTHORIZED");
        require(totalSupply() < MAX_SUPPLY, "SOLD_OUT");
		require(totalSupply() + tokenQuantity <= MAX_SUPPLY, "MINTING_WOULD_EXCEED_MAX_SUPPLY");
        require(_totalTokensMinted[msg.sender] + tokenQuantity <= MAX_PER_ADDRESS_AT_PRESALE, "MINTING_WOULD_EXCEED_PRESALE_PER_ADDRESS_LIMIT");
		require(_totalTokensMinted[msg.sender] + tokenQuantity <= MAX_PER_ADDRESS, "MINTING_WOULD_EXCEED_PER_ADDRESS_LIMIT");
        require(PRICE * tokenQuantity <= msg.value, "INSUFFICIENT_ETH");
		require(tokenQuantity > 0, "TOKEN_QUANTITY_INCORRECT");


        for (uint256 i = 0; i < tokenQuantity; i++) {
            presaleAmountMinted++;
            _presaleTokensMinted[msg.sender]++;
						_totalTokensMinted[msg.sender]++;
            _safeMint(msg.sender, totalSupply() + 1);
        }

		emit PresaleMint(msg.sender, tokenQuantity);
		emit TotalSupplyChanged(totalSupply());
    }

    // checks if address is on the pre-sale Eligible list
    function presaleEligible(address addr) external view returns (bool) {
        return _presaleEligibleList[addr];
    }

    // returns the number of tokens an address has minted during the presale
    function presaleMintedCountPerAddress(address addr) external view returns (uint256) {
        return _presaleTokensMinted[addr];
    }

		// returns the number of tokens an address has minted in total
    function totalMintedCountPerAddress(address addr) external view returns (uint256) {
        return _totalTokensMinted[addr];
    }

    function contractURI() public view returns (string memory) {
        return _contractURI;
    }

    function tokenURI(uint256 tokenId) public view override(ERC721) returns (string memory) {
        require(_exists(tokenId), "INVALID_TOKEN_ID");
		if(revealed == false) {
		    return _tokenNotRevealedURI;
		}
        // Convert string to bytes so we can check if it's empty or not.
        string memory revealedBaseURI = _baseURI();
        return bytes(revealedBaseURI).length > 0
          ? string(abi.encodePacked(revealedBaseURI, tokenId.toString(), _baseExtension))
					: "";
    }

	function ownedTokenIds(address addr) public view returns (uint256[] memory) {
		uint256 ownerTokenCount = balanceOf(addr);
		uint256[] memory tokenIds = new uint256[](ownerTokenCount);
		for (uint256 i; i < ownerTokenCount; i++) {
			tokenIds[i] = tokenOfOwnerByIndex(addr, i);
		}
		return tokenIds;
	}

		// ONLY OWNER
    // Owner functions for enabling presale, sale, revealing and setting the provenance hash


	function addToPresaleList(address[] calldata addresses) external onlyOwner {
        for(uint256 i = 0; i < addresses.length; i++) {
            address entry = addresses[i];
            require(entry != address(0), "NULL_ADDRESS");
            _presaleEligibleList[entry] = true;
        }
    }

    function removeFromPresaleList(address[] calldata addresses) external onlyOwner {
        for(uint256 i = 0; i < addresses.length; i++) {
            address entry = addresses[i];
            require(entry != address(0), "NULL_ADDRESS");

            _presaleEligibleList[entry] = false;
        }
    }

    function mintReserved(address[] calldata addresses) external onlyOwner {
				require(totalSupply() < MAX_SUPPLY, "SOLD_OUT");
        require(totalSupply() + addresses.length <= MAX_SUPPLY, "MINTING_WOULD_EXCEED_MAX_SUPPLY");
        require(reservedAmountMinted + addresses.length <= RESERVED_SUPPLY, "MINTING_WOULD_EXCEED_MAX_RESERVED_SUPPLY");

        for (uint256 i = 0; i < addresses.length; i++) {
            reservedAmountMinted++;
			_reservedTokensMinted[addresses[i]]++;
			_totalTokensMinted[addresses[i]]++;
            _safeMint(addresses[i], totalSupply() + 1);

			emit ReservedMint(addresses[i], 1);
			emit TotalSupplyChanged(totalSupply());
        }
    }

        // withdraws funds
    function withdraw() public onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "INSUFFICIENT_ETH");
		payable(owner()).transfer(balance);
    }

    function setRevealed() external onlyOwner {
        revealed = true;
    }

    function startPresale() external onlyOwner {
        require(presaleActive == false, "PRESALE_ALREADY_ACTIVE");
        presaleActive = true;
        emit PreSaleStatusChanged(presaleActive);
    }

    function pausePresale() external onlyOwner {
        require(presaleActive == true, "PRESALE_ALREADY_PAUSED");
        presaleActive = false;
        emit PreSaleStatusChanged(presaleActive);
    }

    function startSale() external onlyOwner {
        require(saleActive == false, "SALE_ALREADY_ACTIVE");
        saleActive = true;
        emit SaleStatusChanged(saleActive);
    }

    function pauseSale() external onlyOwner {
        require(saleActive == true, "SALE_ALREADY_PAUSED");
        saleActive = false;
        emit SaleStatusChanged(saleActive);
    }

 		// set provenance hash once it's calculated
    function setProvenanceHash(string calldata hash) external onlyOwner {
        proof = hash;
    }

    function setContractURI(string calldata URI) external onlyOwner {
        _contractURI = URI;
    }

    function setBaseURI(string calldata URI) public onlyOwner {
		_tokenBaseURI = URI;
		emit BaseURIChanged(_tokenBaseURI);
    }

	function setBaseExtension(string memory newBaseExtension) public onlyOwner {
		_baseExtension = newBaseExtension;
	}

	function setNotRevealedURI(string calldata URI) public onlyOwner {
		_tokenNotRevealedURI = URI;
	}

}