// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/ERC721Pausable.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/utils/math/SafeMath.sol';
import '@openzeppelin/contracts/utils/Strings.sol';
import '@openzeppelin/contracts/utils/Counters.sol';

import './IBirthday.sol';

/** 

**/
contract Birthday is IBirthday, ERC721Pausable, ERC721Enumerable, ERC721Burnable, ERC721URIStorage, Ownable {
    using Strings for uint256;
    using SafeMath for uint256;
    using Counters for Counters.Counter;

    Counters.Counter private generalCounter; 

    event Minted(address indexed account, uint tokenId);

    bytes prefix = "data:text/plain;charset=utf-8,";

    uint constant USIZE = 26;
    uint public constant MAX_LIMIT = 20000;

    uint public constant PRICE = 200000000000000000;

    uint internal constant MONTHS = 12;
    uint[] internal monthDays = [31,28,31,30,31,30,31,31,30,31,30,31];
    uint[] internal leapYears = [1972, 1976, 1980, 1984, 1988, 1992, 1996, 2000, 2004, 2008, 2012, 2016, 2020, 2024];

    bytes zer = '..0000...00..00..00..00..00..00...0000..';
    bytes one = '.1111......11......11......11....111111.';
    bytes two = '..2222...22..22.....22.....22....222222.';
    bytes thr = '..3333...33..33.....333..33..33...3333..';
    bytes fou = '.44..44..44..44..444444......44......44.';
    bytes fiv = '.555555..55......55555.......55..55555..';
    bytes six = '..6666...66......66666...66..66...6666..';
    bytes sev = '.777777.....77.....77.....77.....77.....';
    bytes eig = '..8888...88..88...8888...88..88...8888..';
    bytes nin = '..9999...99..99...99999......99...9999..';
    // bytes hyp = '...................--...................';
    bytes hyp = '............/....../....../.............';

    bytes[] numbers = [zer, one, two, thr, fou, fiv, six, sev, eig, nin, hyp];

    uint[] internal rows = [0, 1, 2, 3, 4];

    // links
    string public _contractURI;

    /**
     * @dev Total number of birthdays.
     */
    uint internal numBirthdays = 0;

    uint internal MAX_PER_WALLET = 2;

    /**
     * @dev Mapping from NFT ID to approved address.
     */
    mapping (uint256 => address) internal idToApproval;

    /**
     * @dev A mapping from NFT ID to the address that owns it.
     */
    mapping (uint256 => address) internal idToOwner;

    /**
     * @dev Mapping from owner address to mapping of operator addresses.
     */
    mapping (address => mapping (address => bool)) internal ownerToOperators;

    /**
     * @dev Mapping from owner to list of owned NFT IDs.
     */
    mapping(address => uint256[]) internal ownerToIds;


    /**
     * @dev the stored tokens on the chain
     */
    mapping(uint256 => string) private _tokenURIs;

    /**
     * @dev Mapping from NFT ID to its index in the owner tokens list.
     */
    mapping(uint256 => uint256) internal idToOwnerIndex;

    constructor (string memory _name,  string memory _symbol, string memory _contractMetaDataURI) ERC721(_name, _symbol) {
        _contractURI = _contractMetaDataURI;
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165, ERC721, ERC721Enumerable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal virtual override(ERC721, ERC721Enumerable, ERC721Pausable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    /**
    * @notice Pause redeems until unpause is called. this pauses the whole contract. 
    */
    function pause() external override onlyOwner {
        _pause();
    }

    /**
    * @notice Unpause redeems until pause is called. this unpauses the whole contract. 
    */
    function unpause() external override onlyOwner {
        _unpause();
    }

    /**
    * @notice Widthdraw Ether from contract.
    * 
    * @param _to the address to send to
    * @param _amount the amount to withdraw
    */
    function withdrawEther(address payable _to, uint256 _amount) public onlyOwner
    {
        _to.transfer(_amount);
    }


    /**
    * @notice Set contract URI.
    * 
    * @param uri URI of the contract
    */
    function setContractURI(string memory uri) external onlyOwner{
        _contractURI = uri;
    }


    /**
    * @notice Get contract URI.
    * 
    * @return URI of the contract.
    */
    function contractURI() public view returns (string memory) {
        return _contractURI;
    }

    /**
    * @notice Mint a Birthday.
    * 
    * @param tokenId token to mint
    * @param mdy True if the date should be formatted in the mdy format
    * @return URI of token ID.
    */
    function mint(uint tokenId, bool mdy) external payable override returns (string memory) {
        // check if there are enough tokens left for them to mint. 
        require(generalCounter.current() <= MAX_LIMIT, "Max limit");

        // limit number that can be claimed for given wallet. 
        require(ownerToIds[msg.sender].length + 1 <=  MAX_PER_WALLET, "Too many");

        require(msg.value >= PRICE, "Value below price");  
        
        _safeMint(msg.sender, tokenId);

        emit Minted(msg.sender, tokenId);

        string memory uri = draw(tokenId, mdy);

        _setTokenURI(tokenId, uri);

        generalCounter.increment();

        return uri;
    }  

    /**
     * @dev Guarantees that the msg.sender is an owner or operator of the given NFT.
     * @param _tokenId ID of the NFT to validate.
     */
    modifier canOperate(uint256 _tokenId) {
        address tokenOwner = idToOwner[_tokenId];
        require(tokenOwner == msg.sender || ownerToOperators[tokenOwner][msg.sender]);
        _;
    }

    /**
     * @dev Guarantees that the msg.sender is allowed to transfer NFT.
     * @param _tokenId ID of the NFT to transfer.
     */
    modifier canTransfer(uint256 _tokenId) {
        address tokenOwner = idToOwner[_tokenId];
        require(
            tokenOwner == msg.sender
            || idToApproval[_tokenId] == msg.sender
            || ownerToOperators[tokenOwner][msg.sender]
        );
        _;
    }

    /**
     * @dev The draw function to return the ASCII art for the birthday date
     *      formatted in the Gregorian calendar date format day - month year.
     *      
     * @param id The token ID to draw
     * @param mdy True if the date should be formatted in the mdy format
     * @return URI of token ID.
     */
    function draw(uint id, bool mdy) public view returns (string memory) {
        uint year = uint(1970) + ((id - 1) / 365);
        uint month = 1;
        uint day = 1;
        uint dayCount = 0;
        uint leapYear = 0;
        for (uint k = 0; k < leapYears.length; k++) {
            if (year > leapYears[k]) {
                leapYear = (k + 1);
            }
        }

        dayCount += ((year - leapYear - 1970) * 365);
        dayCount += (leapYear * 366);

        bytes memory output = new bytes(USIZE * (USIZE + 3) + 30); // 628
        uint c;

        for (c = 0; c < 30; c++) {
            output[c] = prefix[c];
        }

        for (uint j = 0; j < MONTHS; j++) {
            if (id > dayCount) {
                month = j + 1;
                day = id - dayCount;
            }
            bool isLeapYear = year == leapYears[leapYear];
            if (isLeapYear && j == 1) { // february
                dayCount += 29;
            } else {
                dayCount += monthDays[j];
            }
        }
        
        for(uint i = 0; i < 2; i++) {
            for(uint j = 0; j < 44; j++) {
                output[c] = 0x2E;
                c++;
            }
            output[c] = 0x25;
            c++;
            output[c] = 0x30;
            c++;
            output[c] = 0x41;
            c++;
        }

        for(uint i = 0; i < rows.length; i++) {
            for(uint j = 0; j < 2; j++) {
                output[c] = 0x2E;
                c++;
            }
            if (mdy) {
                for(uint j = (i * 8); j < ((i * 8) + 8); j++) {
                    uint mon1 = (month / 10);
                    output[c] = numbers[mon1][j];
                    c++;
                }
                for(uint j = (i * 8); j < ((i * 8) + 8); j++) {
                    uint mon2 = month % 10;
                    output[c] = numbers[mon2][j];
                    c++;
                }
                for(uint j = (i * 8); j < ((i * 8) + 8); j++) {
                    output[c] = numbers[10][j];
                    c++;
                }
                for(uint j = (i * 8); j < ((i * 8) + 8); j++) {
                    uint day1 = (day / 10);
                    output[c] = numbers[day1][j];
                    c++;
                }
                for(uint j = (i * 8); j < ((i * 8) + 8); j++) {
                    uint day2 = day % 10;
                    output[c] = numbers[day2][j];
                    c++;
                }
            } else {
                for(uint j = (i * 8); j < ((i * 8) + 8); j++) {
                    uint day1 = (day / 10);
                    output[c] = numbers[day1][j];
                    c++;
                }
                for(uint j = (i * 8); j < ((i * 8) + 8); j++) {
                    uint day2 = day % 10;
                    output[c] = numbers[day2][j];
                    c++;
                }
                for(uint j = (i * 8); j < ((i * 8) + 8); j++) {
                    output[c] = numbers[10][j];
                    c++;
                }
                for(uint j = (i * 8); j < ((i * 8) + 8); j++) {
                    uint mon1 = (month / 10);
                    output[c] = numbers[mon1][j];
                    c++;
                }
                for(uint j = (i * 8); j < ((i * 8) + 8); j++) {
                    uint mon2 = month % 10;
                    output[c] = numbers[mon2][j];
                    c++;
                }
            }
            for(uint j = 0; j < 2; j++) {
                output[c] = 0x2E;
                c++;
            }
            output[c] = 0x25;
            c++;
            output[c] = 0x30;
            c++;
            output[c] = 0x41;
            c++;
        }
        
        for(uint i = 0; i < 2; i++) {
            for(uint j = 0; j < 44; j++) {
                output[c] = 0x2E;
                c++;
            }
            output[c] = 0x25;
            c++;
            output[c] = 0x30;
            c++;
            output[c] = 0x41;
            c++;
        }

        for(uint i = 0; i < rows.length; i++) {
            for(uint i = 0; i < 6; i++) {
                output[c] = 0x2E;
                c++;
            }
            for(uint j = (i * 8); j < ((i * 8) + 8); j++) {
                uint year1 = (year / 1000);
                output[c] = numbers[year1][j];
                c++;
            }
            for(uint j = (i * 8); j < ((i * 8) + 8); j++) {
                uint year2 = (year / 100) % 10;
                output[c] = numbers[year2][j];
                c++;
            }
            for(uint j = (i * 8); j < ((i * 8) + 8); j++) {
                uint year3 = (year / 10) % 10;
                output[c] = numbers[year3][j];
                c++;
            }
            for(uint j = (i * 8); j < ((i * 8) + 8); j++) {
                uint year4 = year % 10;
                output[c] = numbers[year4][j];
                c++;
            }
            for(uint i = 0; i < 6; i++) {
                output[c] = 0x2E;
                c++;
            }
            output[c] = 0x25;
            c++;
            output[c] = 0x30;
            c++;
            output[c] = 0x41;
            c++;
        }
        
        for(uint i = 0; i < 2; i++) {
            for(uint j = 0; j < 44; j++) {
                output[c] = 0x2E;
                c++;
            }
            output[c] = 0x25;
            c++;
            output[c] = 0x30;
            c++;
            output[c] = 0x41;
            c++;
        }
        if (mdy) {
            output[c] = 0x4D;
            c++;
            output[c] = 0x44;
            c++;
        } else {
            output[c] = 0x44;
            c++;
            output[c] = 0x4D;
            c++;
        }
        string memory result = string(output);
        return result;
    }

    /**
     * @dev A distinct URI (RFC 3986) for a given NFT.
     * @param _tokenId Id for which we want uri.
     * @return URI of _tokenId.
     */
    function tokenURI(uint256 _tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(_tokenId);
    }

    function _burn(uint256 tokenId) internal virtual override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);

        if (bytes(_tokenURIs[tokenId]).length != 0) {
            delete _tokenURIs[tokenId];

            generalCounter.decrement();
        }
    }
}