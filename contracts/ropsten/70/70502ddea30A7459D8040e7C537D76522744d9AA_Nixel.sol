// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Nixel is ERC721Enumerable, Ownable {
    using Strings for uint256;
    event MintNixel(
        address indexed sender,
        uint256 startWith,
        int256 location_x,
        int256 location_y
    );

    event Deposit(
        uint256 tokenId,
        address payable token,
        address from,
        uint256 amount
    );
    event Withdraw(
        uint256 tokenId,
        address payable token,
        address from,
        uint256 amount
    );

    uint256 public totalBlocks;
    uint256 public totalCount = 10201;

    mapping(uint256 => string) public _tokenURI;
    mapping(int256 => mapping(int256 => string)) public _NFTName;
    mapping(int256 => mapping(int256 => bool)) public _reserved;
    mapping(int256 => mapping(int256 => uint256)) public _reservePrice;

    mapping(uint256 => mapping(address => mapping(address => uint256)))
        public _depositBalance; //tokenId => tokenAddress => userAddress => Amount

    uint256 public priceLuxury = 150000000000000000;
    uint256 public pricePremium = 100000000000000000;
    uint256 public priceEconomy = 10000000000000000;

    string public baseURI;
    bool private started;

    constructor() ERC721("Nixel", "NIXEL") {
        baseURI = "https://ipfs.io/ipfs/";
        setNearSpawnReserved(true);
    }

    function deposit(uint256 tokenId, address payable tokenContract)
        external
        payable
    {
        require(
            _exists(tokenId),
            "ERC721Metadata: Query for nonexistent token"
        );
        require(
            IERC20(tokenContract).transferFrom(
                _msgSender(),
                address(this),
                msg.value
            )
        );
        _depositBalance[tokenId][tokenContract][_msgSender()] += msg.value;
        emit Deposit(tokenId, tokenContract, _msgSender(), msg.value);
    }

    function withdraw(
        uint256 tokenId,
        address payable tokenContract,
        uint256 _amount
    ) external payable {
        require(
            _exists(tokenId),
            "ERC721Metadata: Query for nonexistent token"
        );
        require(ownerOf(tokenId) == _msgSender(), "Not owner of NFT");
        require(
            _depositBalance[tokenId][tokenContract][_msgSender()] >= _amount,
            "Insufficient funds in contract"
        );
        _depositBalance[tokenId][tokenContract][_msgSender()] -= _amount;
        require(IERC20(tokenContract).transfer(_msgSender(), _amount));
        emit Withdraw(tokenId, tokenContract, _msgSender(), _amount);
    }

    function recoveryWithdraw(address payable tokenContract, uint256 _amount)
        external
        payable
        onlyOwner
    {
        require(
            IERC20(tokenContract).balanceOf(address(this)) >= _amount,
            "Insufficient funds in contract"
        );
        require(IERC20(tokenContract).transfer(_msgSender(), _amount));
        emit Withdraw(0, tokenContract, _msgSender(), _amount);
    }

    function nftBalance(
        uint256 tokenId,
        address tokenContract,
        address owner
    ) public view virtual returns (uint256) {
        require(
            _exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token."
        );
        return _depositBalance[tokenId][tokenContract][owner];
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }

    function setBaseURI(string memory _newURI) public onlyOwner {
        baseURI = _newURI;
    }

    function setNearSpawnReserved(bool _reserveToken) public onlyOwner {
        _reserved[0][-1] = _reserveToken;
        _reserved[1][-1] = _reserveToken;
        _reserved[1][0] = _reserveToken;
        _reserved[1][1] = _reserveToken;
        _reserved[0][1] = _reserveToken;
        _reserved[-1][0] = _reserveToken;
        _reserved[-1][1] = _reserveToken;
        _reserved[-1][-1] = _reserveToken;
    }

    function setReserved(
        int256 x_pos,
        int256 y_pos,
        bool _reserveToken
    ) public onlyOwner {
        _reserved[x_pos][y_pos] = _reserveToken;
    }

    function setReservedPrice(
        int256 x_pos,
        int256 y_pos,
        uint256 price
    ) public onlyOwner {
        _reservePrice[x_pos][y_pos] = price;
    }

    function getReservedPrice(int256 x_pos, int256 y_pos)
        public
        view
        returns (uint256)
    {
        return _reservePrice[x_pos][y_pos];
    }

    function setTokenURI(
        uint256 tokenId,
        string memory _newURI,
        string memory _name
    ) public {
        require(
            _exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token."
        );
        require(ownerOf(tokenId) == _msgSender(), "Not owner of NFT");
        _tokenURI[tokenId] = _newURI;
        _NFTName[blockLocation(tokenId)[0]][blockLocation(tokenId)[1]] = _name;
    }

    function nameFromID(uint256 tokenId) public view returns (string memory) {
        require(
            _exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token."
        );
        return _NFTName[blockLocation(tokenId)[0]][blockLocation(tokenId)[1]];
    }

    function nameFromLocation(int256 x_pos, int256 y_pos)
        public
        view
        returns (string memory)
    {
        require(blockOwner(x_pos, y_pos) != address(0), "NFT does not exist");
        return _NFTName[x_pos][y_pos];
    }

    function setNFTName(
        int256 x_pos,
        int256 y_pos,
        string memory name
    ) public {
        require(blockOwner(x_pos, y_pos) == _msgSender(), "Not owner of NFT");
        _NFTName[x_pos][y_pos] = name;
    }

    function getBlockPrice(int256 x_pos, int256 y_pos)
        public
        view
        virtual
        returns (uint256)
    {
        if (y_pos >= -5 && x_pos >= -5 && y_pos <= 5 && x_pos <= 5) {
            return priceLuxury;
        } else {
            if (y_pos >= -21 && x_pos >= -21 && y_pos <= 21 && x_pos <= 21) {
                return pricePremium;
            } else {
                if (
                    y_pos >= -50 && x_pos >= -50 && y_pos <= 50 && x_pos <= 50
                ) {
                    return priceEconomy;
                } else {
                    return 0;
                }
            }
        }
    }

    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        require(
            _exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token."
        );
        return string(abi.encodePacked(baseURI, _tokenURI[tokenId]));
    }

    function tokenBlockURI(int256 x_pos, int256 y_pos)
        public
        view
        virtual
        returns (string memory)
    {
        require(
            _exists(blockTokenId(x_pos, y_pos)),
            "ERC721Metadata: URI query for nonexistent token."
        );
        return
            string(
                abi.encodePacked(baseURI, _tokenURI[blockTokenId(x_pos, y_pos)])
            );
    }

    function setStart(bool _start) public onlyOwner {
        started = _start;
    }

    function tokensOfOwner(address owner)
        public
        view
        returns (uint256[] memory)
    {
        uint256 count = balanceOf(owner);
        uint256[] memory ids = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            ids[i] = tokenOfOwnerByIndex(owner, i);
        }
        return ids;
    }

    function mint(int256 x_pos, int256 y_pos) public payable {
        require(started, "not started");
        require(blockOwner(x_pos, y_pos) == address(0), "block already minted");
        require(totalBlocks + 1 <= totalCount, "max supply reached!");
        require(
            (y_pos >= -50 && y_pos <= 50 && x_pos >= -50 && x_pos <= 50) ==
                true,
            "out of bounds"
        );
        require(
            (x_pos != 0 && y_pos != 0) == true,
            "cannot mint spawn location"
        );
        require(
            (_reserved[x_pos][y_pos]) == false,
            "this nft is currently reserved"
        );
        if (_reservePrice[x_pos][y_pos] == 0) {
            if (y_pos >= -5 && x_pos >= -5 && y_pos <= 5 && x_pos <= 5) {
                require(
                    msg.value == priceLuxury,
                    "value error, please check price."
                );
            } else {
                if (
                    y_pos >= -21 && x_pos >= -21 && y_pos <= 21 && x_pos <= 21
                ) {
                    require(
                        msg.value == pricePremium,
                        "value error, please check price."
                    );
                } else {
                    if (
                        y_pos >= -50 &&
                        x_pos >= -50 &&
                        y_pos <= 50 &&
                        x_pos <= 50
                    ) {
                        require(
                            msg.value == priceEconomy,
                            "value error, please check price."
                        );
                    }
                }
            }
        } else {
            require(
                msg.value == _reservePrice[x_pos][y_pos],
                "value error, please check price."
            );
        }
        payable(owner()).transfer(msg.value);
        setBlockOwner(_msgSender(), x_pos, y_pos);
        setBlockTokenId(x_pos, y_pos, totalBlocks + 1);
        setBlockLocation(totalBlocks + 1, x_pos, y_pos);
        _NFTName[x_pos][y_pos] = "";
        emit MintNixel(_msgSender(), totalBlocks + 1, x_pos, y_pos);
        _mint(_msgSender(), 1 + totalBlocks++);
    }
}