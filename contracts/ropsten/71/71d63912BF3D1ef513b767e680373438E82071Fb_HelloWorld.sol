// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;
/*

  _                                          __   _  __     _
 | |                                        / _| | |/ /    | |
 | |     ___  __ _  __ _ _   _  ___    ___ | |_  | ' / __ _| |_ __ _ _ __   __ _ ___
 | |    / _ \/ _` |/ _` | | | |/ _ \  / _ \|  _| |  < / _` | __/ _` | '_ \ / _` / __|
 | |___|  __/ (_| | (_| | |_| |  __/ | (_) | |   | . \ (_| | || (_| | | | | (_| \__ \
 |______\___|\__,_|\__, |\__,_|\___|  \___/|_|   |_|\_\__,_|\__\__,_|_| |_|\__,_|___/
                    __/ |
                   |___/

    League of Katanas
*/


import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";


contract HelloWorld is ERC721Enumerable, Ownable, ReentrancyGuard {

    using Strings for uint256;

		// maximum number of tokens available to be reserved(i.e giveaways, team etc.)
    uint256 public constant RESERVE_SUPPLY = 111;
		// maximum number of tokens available to be minted for public sale
    uint256 public constant PUBLIC_SUPPLY = 9889;
		// maximum number of tokens ever gonna be minted on this contract
    uint256 public constant MAX_TOTAL_SUPPLY = RESERVE_SUPPLY + PUBLIC_SUPPLY;
		// price of a single NFT
    uint256 public constant TOKEN_PRICE = 0.08 ether;
		// max. number of tokens that can be purchased in one sale transaction
    uint256 public constant MAX_PER_MINT = 5;
		// max. number of tokens that can be purchased in one pre-sale transaction
    uint256 public PRESALE_MAX_MINT = 3;
		// max. number of tokens that can be purchased by single address
		uint256 public constant MAX_MINT_PER_ADDRESS = 50;


		// how many tokens were already minted from reserve
    uint256 public reserveAmountMinted;
		// how many tokens were already minted for public sale
    uint256 public publicSaleAmountMinted;
		// how many tokens were already minted for pre-sale
    uint256 public presaleAmountMinted;


    // fill this out when calculated
    string public proof;
		// base token URI
		string public tokenBaseURI;
		string public baseExtension = ".json";
		// URI shown when token is not revealed
		string public tokenNotRevealedURI;


		// can be used to launch and pause the pre-sale
    bool public presaleActive;
		// can be used to launch and pause the sale
    bool public saleActive;
		// can be used to reveal tokens metadata
    bool public revealed = false;


		// addresses that can participate in the presale event
    mapping(address => bool) private _presaleEligibleList;
		// how many presale tokens are claimed by address
    mapping(address => uint256) private _presaleTokensClaimed;
		// how many sale tokens are claimed by address
    mapping(address => uint256) private _publicSaleTokensClaimed;
		// how many mintGtokens are claimed by address
    mapping(address => uint256) private _reserveTokensClaimed;
		// how many total tokens are claimed by address
    mapping(address => uint256) private _totalTokensClaimed;


    string private _contractURI;
		string private _tokenRevealedBaseURI;


    event BaseURIChanged(string baseURI);
    event PresaleMint(address minter, uint256 amountOfTokens);
    event PublicSaleMint(address minter, uint256 amountOfTokens);
		event ReserveMint(address recipient, uint256 amountOfTokens);

    constructor(
			string memory _name,
			string memory _symbol,
			string memory _initTokenBaseURI,
			string memory _initNotRevealedURI
		) ERC721(_name, _symbol) {
				tokenBaseURI = _initTokenBaseURI;
				tokenNotRevealedURI = _initNotRevealedURI;
			}

    // INTERNALS

  function _baseURI() internal view virtual override returns (string memory) {
    return tokenBaseURI;
  }

		// PUBLIC

    // purchase tokens from the contract sale
    function mint(uint256 tokenQuantity) external nonReentrant payable {
				require(saleActive, "SALE_NOT_ACTIVE");
        require(totalSupply() < MAX_TOTAL_SUPPLY, "SOLD_OUT");
				require(totalSupply() + tokenQuantity <= MAX_TOTAL_SUPPLY, "MINTING_WOULD_EXCEED_MAX_SUPPLY");
        require(publicSaleAmountMinted + tokenQuantity <= PUBLIC_SUPPLY, "MINTING_WOULD_EXCEED_PUBLIC_SUPPLY");
        require(tokenQuantity <= MAX_PER_MINT, "MINTING_WOULD_EXCEED_PER_MINT_LIMIT");
				require(_totalTokensClaimed[msg.sender] + tokenQuantity <= MAX_MINT_PER_ADDRESS, "MINTING_WOULD_EXCEED_PER_ADDRESS_MINT_LIMIT");
        require(TOKEN_PRICE * tokenQuantity <= msg.value, "INSUFFICIENT_ETH");
				require(tokenQuantity > 0, "TOKEN_QUANTITY_INCORRECT");


        for(uint256 i = 0; i < tokenQuantity; i++) {
            publicSaleAmountMinted++;
						_publicSaleTokensClaimed[msg.sender]++;
						_totalTokensClaimed[msg.sender]++;
            _safeMint(msg.sender, totalSupply() + 1);
        }

				emit PublicSaleMint(msg.sender, tokenQuantity);
    }

    // purchase tokens from the contract presale
    function mintPresale(uint256 tokenQuantity) external nonReentrant payable {
				require(presaleActive, "PRESALE_NOT_ACTIVE");
        require(!saleActive, "PUBLIC_SALE_IS_NOW_ACTIVE");
        require(_presaleEligibleList[msg.sender], "PRESALE_NOT_AUTHORIZED");
        require(totalSupply() < MAX_TOTAL_SUPPLY, "SOLD_OUT");
				require(totalSupply() + tokenQuantity <= MAX_TOTAL_SUPPLY, "MINTING_WOULD_EXCEED_MAX_SUPPLY");
        require(_totalTokensClaimed[msg.sender] + tokenQuantity <= PRESALE_MAX_MINT, "MINTING_WOULD_EXCEED_PRESALE_MINT_LIMIT");
				require(_totalTokensClaimed[msg.sender] + tokenQuantity <= MAX_MINT_PER_ADDRESS, "MINTING_WOULD_EXCEED_PER_ADDRESS_MINT_LIMIT");
        require(TOKEN_PRICE * tokenQuantity <= msg.value, "INSUFFICIENT_ETH");
				require(tokenQuantity > 0, "TOKEN_QUANTITY_INCORRECT");


        for (uint256 i = 0; i < tokenQuantity; i++) {
            presaleAmountMinted++;
            _presaleTokensClaimed[msg.sender]++;
						_totalTokensClaimed[msg.sender]++;
            _safeMint(msg.sender, totalSupply() + 1);
        }

				emit PresaleMint(msg.sender, tokenQuantity);
    }

    // checks if address is on the pre-sale Eligible list
    function checkPresaleEligiblity(address addr) external view returns (bool) {
        return _presaleEligibleList[addr];
    }

    // returns the number of tokens an address has minted during the presale
    function presaleClaimedCount(address addr) external view returns (uint256) {
        return _presaleTokensClaimed[addr];
    }

		// returns the number of tokens an address has claimed in total
    function totalClaimedCount(address addr) external view returns (uint256) {
        return _totalTokensClaimed[addr];
    }

    function contractURI() public view returns (string memory) {
        return _contractURI;
    }

    function tokenURI(uint256 tokenId) public view override(ERC721) returns (string memory) {
        require(_exists(tokenId), "INVALID_TOKEN_ID");
				if(revealed == false) {
					return tokenNotRevealedURI;
				}
        // Convert string to bytes so we can check if it's empty or not.
        string memory revealedBaseURI = _baseURI();
        return bytes(revealedBaseURI).length > 0
          ? string(abi.encodePacked(revealedBaseURI, tokenId.toString(), baseExtension))
					: "";
    }

		function tokensOwnedByAddress(address addr) public view returns (uint256[] memory) {
			uint256 ownerTokenCount = balanceOf(addr);
			uint256[] memory tokenIds = new uint256[](ownerTokenCount);
			for (uint256 i; i < ownerTokenCount; i++) {
				tokenIds[i] = tokenOfOwnerByIndex(addr, i);
			}
			return tokenIds;
		}

		// ONLY OWNER
    // Owner functions for enabling presale, sale, revealing and setting the provenance hash


		function addToPresaleList(address[] calldata entries) external onlyOwner {
        for(uint256 i = 0; i < entries.length; i++) {
            address entry = entries[i];
            require(entry != address(0), "NULL_ADDRESS");
            _presaleEligibleList[entry] = true;
        }
    }

    function removeFromPresaleList(address[] calldata entries) external onlyOwner {
        for(uint256 i = 0; i < entries.length; i++) {
            address entry = entries[i];
            require(entry != address(0), "NULL_ADDRESS");

            _presaleEligibleList[entry] = false;
        }
    }

    function mintReserved(address[] calldata receivers) external onlyOwner {
				require(totalSupply() < MAX_TOTAL_SUPPLY, "SOLD_OUT");
        require(totalSupply() + receivers.length <= MAX_TOTAL_SUPPLY, "MINTING_WOULD_EXCEED_MAX_SUPPLY");
        require(reserveAmountMinted + receivers.length <= RESERVE_SUPPLY, "MINTING_WOULD_EXCEED_MAX_RESERVE_SUPPLY");

        for (uint256 i = 0; i < receivers.length; i++) {
            reserveAmountMinted++;
						_reserveTokensClaimed[receivers[i]]++;
						_totalTokensClaimed[receivers[i]]++;
            _safeMint(receivers[i], totalSupply() + 1);

						emit ReserveMint(receivers[i], 1);
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
		// starts or pauses the pre-sale
    function togglePresaleStatus() external onlyOwner {
        presaleActive = !presaleActive;
    }

		// starts or pauses the sale
    function toggleSaleStatus() external onlyOwner {
        saleActive = !saleActive;
    }

 		// set provenance hash once it's calculated
    function setProvenanceHash(string calldata hash) external onlyOwner {
        proof = hash;
    }

    function setContractURI(string calldata URI) external onlyOwner {
        _contractURI = URI;
    }

    function setBaseURI(string calldata URI) public onlyOwner {
			tokenBaseURI = URI;
			emit BaseURIChanged(tokenBaseURI);
    }

		function setBaseExtension(string memory newBaseExtension) public onlyOwner {
			baseExtension = newBaseExtension;
		}

		function setRevealedBaseURI(string calldata URI) external onlyOwner {
			_tokenRevealedBaseURI = URI;
		}

		function setNotRevealedURI(string calldata URI) public onlyOwner {
			tokenNotRevealedURI = URI;
		}

}