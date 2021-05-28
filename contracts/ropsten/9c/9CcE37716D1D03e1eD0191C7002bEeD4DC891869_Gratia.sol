// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./SafeMath.sol";
import "./Stringstrings.sol";
import "./Ownable.sol";
import "./IERC20.sol";
import "./SafeERC20.sol";
import "./IGratia.sol";
import "./ERC721.sol";

interface ERC20Interface is IERC20 {
    function deposit() external payable;
}

interface IGratiaPack {
    function increaseInsideTokenBalance(
        uint256 gratiaId,
        uint8 tokenType,
        address token,
        uint256 amount
    ) external;
}

/**
 * @title Gratia NFT contract
 * @dev Extends ERC721 Non-Fungible Token Standard basic implementation
 */
contract Gratia is Ownable, IGratia, ERC721 {
    using SafeMath for uint256;
    using Address for address;
    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableMap for EnumerableMap.UintToAddressMap;
    using Stringstrings for string;
    using SafeERC20 for IERC20;

    // Public variables

    // This is SHA256 hash of the provenance record of all Gratia artworks
    // It is derived by hashing every individual NFT's picture, and then concatenating all those hash, deriving yet another SHA256 from that.
    string public constant GRATIA_PROVENANCE = "19c96c9954ef49fe26843f6bc19b8dd5a66063df24b3eecaf8c0ef56d5a9e755";

    // June 1, 2021 @ 1:33:37 PM UTC = 1622491417
    uint256 public constant SALE_START_TIMESTAMP = 1621857137;

    // Time after which Gratia NFTs are randomized and allotted (after 21 days)
    uint256 public constant REVEAL_TIMESTAMP = SALE_START_TIMESTAMP + (86400 * 21);

    uint256 public constant NAME_CHANGE_PRICE = 1337 * (10 ** 18);

    uint256 public constant MAX_NFT_SUPPLY = 13337;
    
    uint256 public constant REFERRAL_REWARD_PERCENT = 1000;  // 10%

    uint256 public startingIndexBlock;

    uint256 public startingIndex;

    // Mapping from token ID to name
    mapping (uint256 => string) private _tokenName;

    // Mapping if certain name string has already been reserved
    mapping (string => bool) private _nameReserved;

    // Mapping from token ID to whether the Gratia was minted before reveal
    mapping (uint256 => bool) private _mintedBeforeReveal;
    
    // Referral management
    mapping(address => uint256) public _referralAmounts;
    mapping(address => mapping(address => bool)) public _referralStatus;

    IGratiaPack public _gratiaPack;

    ERC20Interface public _weth;
    
    // Name Your Gratia(NYG) token address
    address private _nygAddress;

    /*
     *     bytes4(keccak256('balanceOf(address)')) == 0x70a08231
     *     bytes4(keccak256('ownerOf(uint256)')) == 0x6352211e
     *     bytes4(keccak256('approve(address,uint256)')) == 0x095ea7b3
     *     bytes4(keccak256('getApproved(uint256)')) == 0x081812fc
     *     bytes4(keccak256('setApprovalForAll(address,bool)')) == 0xa22cb465
     *     bytes4(keccak256('isApprovedForAll(address,address)')) == 0xe985e9c5
     *     bytes4(keccak256('transferFrom(address,address,uint256)')) == 0x23b872dd
     *     bytes4(keccak256('safeTransferFrom(address,address,uint256)')) == 0x42842e0e
     *     bytes4(keccak256('safeTransferFrom(address,address,uint256,bytes)')) == 0xb88d4fde
     *
     *     => 0x70a08231 ^ 0x6352211e ^ 0x095ea7b3 ^ 0x081812fc ^
     *        0xa22cb465 ^ 0xe985e9c5 ^ 0x23b872dd ^ 0x42842e0e ^ 0xb88d4fde == 0x80ac58cd
     */
    bytes4 private constant _INTERFACE_ID_ERC721 = 0x80ac58cd;

    /*
     *     bytes4(keccak256('name()')) == 0x06fdde03
     *     bytes4(keccak256('symbol()')) == 0x95d89b41
     *     bytes4(keccak256('tokenURI(uint256)')) == 0xc87b56dd
     *
     *     => 0x06fdde03 ^ 0x95d89b41 == 0x93254542
     *     => 0x06fdde03 ^ 0x95d89b41 ^ 0xc87b56dd == 0x5b5e139f
     */
    bytes4 private constant _INTERFACE_ID_ERC721_METADATA = 0x5b5e139f;

    /*
     *     bytes4(keccak256('totalSupply()')) == 0x18160ddd
     *     bytes4(keccak256('tokenOfOwnerByIndex(address,uint256)')) == 0x2f745c59
     *     bytes4(keccak256('tokenByIndex(uint256)')) == 0x4f6ccce7
     *
     *     => 0x18160ddd ^ 0x2f745c59 ^ 0x4f6ccce7 == 0x780e9d63
     */
    bytes4 private constant _INTERFACE_ID_ERC721_ENUMERABLE = 0x780e9d63;

    // Events
    event NameChange (uint256 indexed gratiaIndex, string newName);

    /**
     * @dev Initializes the contract by setting a `name` and a `symbol` to the token collection.
     */
    constructor (string memory name_, string memory symbol_, address nygAddress, address weth) ERC721(name_, symbol_) {
        _nygAddress = nygAddress;
        _weth = ERC20Interface(weth);

        // register the supported interfaces to conform to ERC721 via ERC165
        _registerInterface(_INTERFACE_ID_ERC721);
        _registerInterface(_INTERFACE_ID_ERC721_METADATA);
        _registerInterface(_INTERFACE_ID_ERC721_ENUMERABLE);
    }

    /**
     * @dev See {IERC721Enumerable-tokenOfOwnerByIndex}.
     */
    function tokenOfOwnerByIndex(address owner, uint256 index) public view override returns (uint256) {
        return _holderTokens[owner].at(index);
    }

    /**
     * @dev See {IERC721Enumerable-totalSupply}.
     */
    function totalSupply() public view override returns (uint256) {
        // _tokenOwners are indexed by tokenIds, so .length() returns the number of tokenIds
        return _tokenOwners.length();
    }

    /**
     * @dev See {IERC721Enumerable-tokenByIndex}.
     */
    function tokenByIndex(uint256 index) public view override returns (uint256) {
        (uint256 tokenId, ) = _tokenOwners.at(index);
        return tokenId;
    }

    /**
     * @dev Returns name of the NFT at index.
     */
    function tokenNameByIndex(uint256 index) public view returns (string memory) {
        return _tokenName[index];
    }

    /**
     * @dev Returns if the name has been reserved.
     */
    function isNameReserved(string memory nameString) public view returns (bool) {
        return _nameReserved[toLower(nameString)];
    }

    /**
     * @dev Returns if the NFT has been minted before reveal phase
     */
    function isMintedBeforeReveal(uint256 index) public view override returns (bool) {
        return _mintedBeforeReveal[index];
    }

    function setGratiaPackAddress(address gratiaPack) public onlyOwner {
        require(address(_gratiaPack) == address(0), "Already set");

        _gratiaPack = IGratiaPack(gratiaPack);
    }
    
    function distributeReferral(uint256 startGratiaId, uint256 endGratiaId) external onlyOwner {
        require(block.timestamp >= SALE_START_TIMESTAMP, "Sale has not started");
        require(totalSupply() >= MAX_NFT_SUPPLY, "Sale has not ended yet");
        
        uint256 totalReferralAmount;

        for (uint256 i = startGratiaId; i <= endGratiaId; i++) {
            address owner = ownerOf(i);
            uint256 referralAmount = _referralAmounts[owner];
            if (referralAmount > 0) {
                _gratiaPack.increaseInsideTokenBalance(i, 1, address(_weth), referralAmount);  // 1: TOKEN_TYPE_ERC20
                
                totalReferralAmount = totalReferralAmount.add(referralAmount);
                delete _referralAmounts[owner];
            }
        }

        if (totalReferralAmount > 0) {
            _weth.deposit{ value: totalReferralAmount }();
            _weth.transfer(address(_gratiaPack), totalReferralAmount);
        }
    }

    /**
     * @dev Gets current Gratia Price
     */
    function getNFTPrice(uint256 numberOfNfts) public view returns (uint256) {
        require(block.timestamp >= SALE_START_TIMESTAMP, "Sale has not started");
        require(totalSupply().add(numberOfNfts) <= MAX_NFT_SUPPLY, "Exceeds MAX_NFT_SUPPLY");

        uint currentSupply = totalSupply();
        uint upperBoundary;

        if (currentSupply >= 0 && currentSupply < 4000) {
            upperBoundary = 4000;
        } else if (currentSupply >= 4000 && currentSupply < 7000) {
            upperBoundary = 7000;
        } else if (currentSupply >= 7000 && currentSupply < 10000) {
            upperBoundary = 10000;
        } else if (currentSupply >= 10000 && currentSupply < 13000) {
            upperBoundary = 13000;
        } else if (currentSupply >= 13000 && currentSupply < 13333) {
            upperBoundary = 13333;
        }

        if (currentSupply >= 13287 && currentSupply.add(numberOfNfts) <= 13336) {
            upperBoundary = 13333;
        } else if (currentSupply >= 13287 && currentSupply.add(numberOfNfts) == 13337) {
            uint totalPrice = getPrice(13336);
            if (numberOfNfts.sub(1) > 0 && numberOfNfts.sub(1) <= 3) {
                totalPrice = totalPrice.add(numberOfNfts.sub(1).mul(getPrice(13333)));
            } else if (numberOfNfts.sub(4) > 0) {
                totalPrice = totalPrice.add(getPrice(13333).mul(3));
                totalPrice = totalPrice.add(getPrice(13000).mul(numberOfNfts.sub(4)));
            }
            return totalPrice;
        }

        if (currentSupply.add(numberOfNfts) > upperBoundary) {
            uint256 totalPriceBelowBoundary = getPrice(currentSupply).mul(upperBoundary.sub(currentSupply));
            uint256 totalPriceAboveBoundary = getPrice(upperBoundary).mul(currentSupply.add(numberOfNfts).sub(upperBoundary));
            return totalPriceBelowBoundary.add(totalPriceAboveBoundary);
        } else {
            return getPrice(currentSupply).mul(numberOfNfts);
        }
    }

    function getPrice(uint256 currentSupply) internal pure returns (uint256) {
        if (currentSupply >= 13336) {
            return 100000000000000000000;  // 13336 = 100 ETH
        } else if (currentSupply >= 13333) {
            return 3000000000000000000;   // 13333 - 13335 = 3 ETH
        } else if (currentSupply >= 13000) {
            return 1700000000000000000;    // 13000 - 13332 = 1.7 ETH
        } else if (currentSupply >= 10000) {
            return 450000000000000000;    // 10000 - 12999 = 0.45 ETH
        } else if (currentSupply >= 7000) {
            return 250000000000000000;     // 7000  - 9999  = 0.25 ETH
        } else if (currentSupply >= 4000) {
            return 150000000000000000;     // 4000  - 6999  = 0.15 ETH
        } else {
            return 40000000000000000;      //   0   - 3999  = 0.04 ETH
        }
    }
    
    function mintNFT(uint256 numberOfNfts, address referee) public payable {
        require(totalSupply() < MAX_NFT_SUPPLY, "Sale has already ended");
        require(numberOfNfts > 0, "numberOfNfts cannot be 0");
        require(numberOfNfts <= 50, "You may not buy more than 50 NFTs at once");
        require(totalSupply().add(numberOfNfts) <= MAX_NFT_SUPPLY, "Exceeds MAX_NFT_SUPPLY");
        require(getNFTPrice(numberOfNfts) == msg.value, "Ether value sent is not correct");

        for (uint i = 0; i < numberOfNfts; i++) {
            uint mintIndex = totalSupply();
            if (block.timestamp < REVEAL_TIMESTAMP) {
                _mintedBeforeReveal[mintIndex] = true;
            }
            _safeMint(msg.sender, mintIndex);
        }

        /**
        * Source of randomness. Theoretical miner withhold manipulation possible but should be sufficient in a pragmatic sense
        */
        if (startingIndexBlock == 0 && (totalSupply() == MAX_NFT_SUPPLY || block.timestamp >= REVEAL_TIMESTAMP)) {
            startingIndexBlock = block.number;
        }
        
        if (referee != address(0) && referee != msg.sender) {
            _addReferralAmount(referee, msg.sender, msg.value);
        }
    }
    
    function _addReferralAmount(address referee, address referrer, uint256 amount) private {
        uint256 refereeBalance = ERC721.balanceOf(referee);
        bool status = _referralStatus[referrer][referee];
        uint256 referralAmount = percent(amount, REFERRAL_REWARD_PERCENT);

        if (refereeBalance != 0 && !status) {
            _referralAmounts[referee] = _referralAmounts[referee].add(referralAmount);
            _referralAmounts[referrer] = _referralAmounts[referrer].add(referralAmount);
            _referralStatus[referrer][referee] = true;
        }
    }

    /**
     * @dev Finalize starting index
     */
    function finalizeStartingIndex() public {
        require(startingIndex == 0, "Starting index is already set");
        require(startingIndexBlock != 0, "Starting index block must be set");

        startingIndex = uint(blockhash(startingIndexBlock)) % MAX_NFT_SUPPLY;
        // Just a sanity case in the worst case if this function is called late (EVM only stores last 256 block hashes)
        if (block.number.sub(startingIndexBlock) > 255) {
            startingIndex = uint(blockhash(block.number-1)) % MAX_NFT_SUPPLY;
        }
        // Prevent default sequence
        if (startingIndex == 0) {
            startingIndex = startingIndex.add(1);
        }
    }

    /**
     * @dev Changes the name for Gratia tokenId
     */
    function changeName(uint256 tokenId, string memory newName) public {
        address owner = ownerOf(tokenId);

        require(_msgSender() == owner, "ERC721: caller is not the owner");
        require(validateName(newName) == true, "Not a valid new name");
        require(sha256(bytes(newName)) != sha256(bytes(_tokenName[tokenId])), "New name is same as the current one");
        require(isNameReserved(newName) == false, "Name already reserved");

        IERC20(_nygAddress).safeTransferFrom(msg.sender, address(this), NAME_CHANGE_PRICE);
        // If already named, dereserve old name
        if (bytes(_tokenName[tokenId]).length > 0) {
            toggleReserveName(_tokenName[tokenId], false);
        }
        toggleReserveName(newName, true);
        _tokenName[tokenId] = newName;
        IERC20(_nygAddress).burn(NAME_CHANGE_PRICE);
        emit NameChange(tokenId, newName);
    }

    /**
     * @dev Withdraw ether from this contract (Callable by owner)
    */
    function withdraw() onlyOwner public {
        uint balance = address(this).balance;
        payable(msg.sender).transfer(balance);
    }


    /**
     * @dev Reserves the name if isReserve is set to true, de-reserves if set to false
     */
    function toggleReserveName(string memory str, bool isReserve) internal {
        _nameReserved[toLower(str)] = isReserve;
    }

    /**
     * @dev Check if the name string is valid (Alphanumeric and spaces without leading or trailing space)
     */
    function validateName(string memory str) public pure returns (bool){
        bytes memory b = bytes(str);
        if(b.length < 1) return false;
        if(b.length > 25) return false; // Cannot be longer than 25 characters
        if(b[0] == 0x20) return false; // Leading space
        if (b[b.length - 1] == 0x20) return false; // Trailing space

        bytes1 lastChar = b[0];

        for(uint i; i<b.length; i++){
            bytes1 char = b[i];

            if (char == 0x20 && lastChar == 0x20) return false; // Cannot contain continous spaces

            if(
                !(char >= 0x30 && char <= 0x39) && //9-0
                !(char >= 0x41 && char <= 0x5A) && //A-Z
                !(char >= 0x61 && char <= 0x7A) && //a-z
                !(char == 0x20) //space
            )
                return false;

            lastChar = char;
        }

        return true;
    }

    /**
     * @dev Converts the string to lowercase
     */
    function toLower(string memory str) public pure returns (string memory) {
        bytes memory bStr = bytes(str);
        bytes memory bLower = new bytes(bStr.length);
        for (uint i = 0; i < bStr.length; i++) {
            // Uppercase character
            if ((uint8(bStr[i]) >= 65) && (uint8(bStr[i]) <= 90)) {
                bLower[i] = bytes1(uint8(bStr[i]) + 32);
            } else {
                bLower[i] = bStr[i];
            }
        }
        return string(bLower);
    }
    
    // helper function to count percentage of amount 
    function percent(uint _amount, uint _fraction) internal pure returns(uint) {
        require((_amount.div(10000)).mul(10000) == _amount, 'too small');
        return ((_amount).mul(_fraction)).div(10000);
    }
}