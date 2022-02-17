// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/ERC721Pausable.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/utils/math/SafeMath.sol';
import '@openzeppelin/contracts/utils/Strings.sol';
import '@openzeppelin/contracts/utils/Counters.sol';
import '@openzeppelin/contracts/utils/Base64.sol';
import "@openzeppelin/contracts/security/PullPayment.sol";

import './IBirthday.sol';

/** 
 * On chain collection of 20k unique dates with the following properties:
 * - Each date is unique
 * - all metadata on chain
 * - all images on chain in svg format
 *
 * @title Birthday Contract
**/
contract Birthday is IBirthday, ERC721, ERC721Pausable, ERC721Burnable, ERC721URIStorage, PullPayment, Ownable {
    using Strings for uint256;
    using SafeMath for uint256;

    event Minted(address indexed account, uint tokenId);

    bytes prefix = "data:text/plain;charset=US-ASCII,";

    uint constant USIZE = 1064;
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
    bytes hyp = '............/....../....../.............';

    bytes[] numbers = [zer, one, two, thr, fou, fiv, six, sev, eig, nin, hyp];

    uint[] internal rows = [0, 1, 2, 3, 4];

    uint internal MAX_PER_WALLET = 2;

    /**
     * @dev the stored tokens on the chain
     */
    mapping(uint256 => string) private _tokenURIs;

    constructor (string memory _name,  string memory _symbol) ERC721(_name, _symbol) {}

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal virtual override(ERC721, ERC721Pausable) {
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
        _asyncTransfer(_to, _amount);
    }


    /**
    * @notice Get contract URI.
    * 
    * @return URI of the contract.
    */
    function contractURI() public view returns (string memory) {
        string memory json = Base64.encode(
            bytes(string(
                abi.encodePacked(
                    '{"name": "DOB",',
                    '"image": "https://nftdob.com/logo",',
                    '"description": "DOB is a collection of 20,000 Date of Birth NFTs; unique digital collectibles living on the Ethereum blockchain. Each DOB NFT is a unique date between 01-01-1970 and 03-10-2024. Once minited, the date is stored on the blockchain in ASCII art form with a supported SVG image.",',
                    '"external_link": "https://nftdob.com", "seller_fee_basis_points": 250, "fee_recipient": "0x78Ff8AcA432cF99a76BCE9C01Bca7D44E46F270b"}'
                )
            ))
        );
        return string(abi.encodePacked('data:application/json;base64,', json));
    }

    /**
    * @notice Mint a Birthday.
    * 
    * @param tokenId token to mint
    * @param mdy True if the date should be formatted in the mdy format
    * @return URI of token ID.
    */
    function mint(uint tokenId, bool mdy) external payable override returns (string memory) {
        require(tokenId <= MAX_LIMIT, "Max limit");
        require(balanceOf(msg.sender) + 1 <=  MAX_PER_WALLET, "Too many");
        require(msg.value >= PRICE, "Value below price");  
        
        _safeMint(msg.sender, tokenId);

        emit Minted(msg.sender, tokenId);

        string memory uri = draw(tokenId, mdy);

        _setTokenURI(tokenId, uri);

        return uri;
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
        require(id <= MAX_LIMIT, "Max limit");
        (uint day, uint month, uint year) = tokenToDayMonthYear(id);

        bytes memory output = new bytes(USIZE);
        uint c;

        for (c = 0; c < 33; c++) {
            output[c] = prefix[c];
        }
        
        for(uint i = 0; i < 5; i++) {
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
        
        for(uint i = 0; i < 4; i++) {
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
        for(uint j = 0; j < 42; j++) {
            output[c] = 0x2E;
            c++;
        }
        if (mdy) {
            output[c] = 0x2E;
            c++;
            output[c] = 0x2E;
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
        require(_tokenId <= MAX_LIMIT, "Max limit");
        string memory imageData = super.tokenURI(_tokenId);
        (uint day, uint month, uint year) = tokenToDayMonthYear(_tokenId);
        string memory dayStr = uint2str(day);
        string memory monthStr = uint2str(month);
        string memory yearStr = uint2str(year);
        string memory svg = getSvg(imageData);
        string memory json = Base64.encode(
            bytes(string(
                abi.encodePacked(
                    '{"name": "#', uint2str(_tokenId),'",',
                    '"image_data": "', svg, '",',
                    '"attributes": [{"trait_type": "Day", "value": "',dayStr,'"},',
                    '{"trait_type": "Month", "value": "',monthStr,'"},',
                    '{"trait_type": "Year", "value": "',yearStr,'"}',
                    ']}'
                )
            ))
        );
        return string(abi.encodePacked('data:application/json;base64,', json));
    }

    /**
     * Burn your DOB NFT and release the date back into the pool of purcahseable NFTs
     * If you wish to burn your NFT and keep the date out of the pool, you can transfer
     * the token directly to the 0x0 address.
     * 
     * @dev Burns the token and releases the date for minting 
     * @param tokenId the ID of the token to be burned
     */
    function _burn(uint256 tokenId) internal virtual override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);

        if (bytes(_tokenURIs[tokenId]).length != 0) {
            delete _tokenURIs[tokenId];
        }
    }

    function uint2str(uint _i) private pure returns (string memory _uintAsString) {
        if (_i == 0) {
            return "0";
        }
        uint j = _i;
        uint len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint k = len;
        while (_i != 0) {
            k = k-1;
            uint8 temp = (48 + uint8(_i - _i / 10 * 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            _i /= 10;
        }
        return string(bstr);
    }

    function substring(string memory str, uint startIndex, uint endIndex) private view returns (string memory) {
        bytes memory strBytes = bytes(str);
        bytes memory result = new bytes(endIndex-startIndex);
        for(uint i = startIndex; i < endIndex; i++) {
            result[i-startIndex] = strBytes[i];
        }
        return string(result);
    }

    function getSvg(string memory imageData) private view returns (string memory) {
        string memory svg;

        string memory dayMonth = string(abi.encodePacked(substring(imageData, 124 + 144, 168 + 144), "</text><text x='180' y='116' >", substring(imageData, 171 + 144,215 + 144), "</text><text x='180' y='132' >", substring(imageData, 218 + 144,262 + 144), "</text><text x='180' y='148'>", substring(imageData, 265 + 144,309 + 144), "</text><text x='180' y='164'>", substring(imageData, 312 + 144,356 + 144)));
        string memory year = string(abi.encodePacked(substring(imageData, 453 + 144,497 + 144), "</text><text x='180' y='228'>", substring(imageData, 500 + 144,544 + 144), "</text><text x='180' y='244'>", substring(imageData, 547 + 144,591 + 144), "</text><text x='180' y='260'>", substring(imageData, 594 + 144,638 + 144), "</text><text x='180' y='276'>", substring(imageData, 641 + 144,685 + 144)));
        string memory md = substring(imageData, USIZE - 2, USIZE);

        svg = string(abi.encodePacked(
            "<svg xmlns='http://www.w3.org/2000/svg' version='1.1' height='1080' width='1080' viewBox='0 0 360 370' style='background-color:white' class='diagram' text-anchor='middle' font-family='monospace' font-size='13px'><g class='text'><text x='180' y='20'>............................................</text><text x='180' y='36'>............................................</text><text x='180' y='52'>............................................</text><text x='180' y='68'>............................................</text><text x='180' y='84'>............................................</text><text x='180' y='100' >", dayMonth, "</text><text x='180' y='180'>............................................</text><text x='180' y='196'>............................................</text><text x='180' y='212'>", year, "</text><text x='180' y='292'>............................................</text><text x='180' y='308'>............................................</text><text x='180' y='324'>............................................</text><text x='180' y='340'>............................................</text><text x='180' y='356'>..........................................", md ,"</text></g></svg>"
        ));
        return svg;
    }

    function tokenToDayMonthYear(uint id) private view returns (uint _day, uint _month, uint _year) {
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

        for (uint j = 0; j < MONTHS; j++) {
            if (id > dayCount) {
                month = j + 1;
                day = id - dayCount;
            }
            bool isLeapYear = year == leapYears[leapYear];
            if (isLeapYear && j == 1) {
                dayCount += 29;
            } else {
                dayCount += monthDays[j];
            }
        }

        return (day, month, year);
    }
}