// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

interface PixelContract {
    function mint(address _to, uint256 _amount) external;

    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) external;
}

contract Nixel is ERC721Enumerable, Ownable {
    using Strings for uint256;

    event MintNixel(
        address indexed sender,
        uint256 startWith,
        int256 location_x,
        int256 location_y
    );

    event BlockBought(
        uint256 tokenId,
        address seller,
        address buyer,
        uint256 price,
        int256[2] location
    );

    event BlockForSale(
        uint256 tokenId,
        address seller,
        uint256 price,
        int256[2] location
    );

    event BlockForRent(
        uint256 tokenId,
        address landlord,
        uint256 price,
        uint256 duration,
        int256[2] location
    );

    event BlockRented(
        uint256 tokenId,
        address landlord,
        address renter,
        uint256 price,
        uint256 timeStart,
        uint256 timeStop,
        int256[2] location
    );

    event BlockUpdated(
        uint256 tokenId,
        address updater,
        string newURI,
        int256[2] location
    );

    event Withdraw(
        uint256 tokenId,
        address payable token,
        address from,
        uint256 amount
    );

    uint256 public totalBlocks;
    uint256 public maxBlocks = 10201;

    mapping(uint256 => string) private _tokenURI;
    mapping(uint256 => string) private _tokenURIRenter;
    mapping(int256 => mapping(int256 => uint256)) private _spawnBlockId;
    mapping(int256 => mapping(int256 => string)) private _BlockName;
    mapping(int256 => mapping(int256 => string)) private _BlockNameRented;
    mapping(int256 => mapping(int256 => bool)) private _reserved;
    mapping(int256 => mapping(int256 => uint256)) private _reservePrice;

    mapping(int256 => mapping(int256 => bool)) private _forSale;
    mapping(int256 => mapping(int256 => uint256)) private _salePrice;
    mapping(int256 => mapping(int256 => address)) private _sellerAddress;

    mapping(int256 => mapping(int256 => bool)) private _forRent;
    mapping(int256 => mapping(int256 => uint256)) private _rentPrice;
    mapping(int256 => mapping(int256 => address)) private _landlordAddress;
    mapping(int256 => mapping(int256 => address)) private _renterAddress;
    mapping(int256 => mapping(int256 => uint256)) private _rentDuration;
    mapping(int256 => mapping(int256 => uint256)) private _rentStart;
    mapping(int256 => mapping(int256 => uint256)) private _rentStop;

    mapping(uint256 => mapping(address => mapping(address => uint256)))
        private _depositBalance;

    uint256 public priceLuxury = 150000000000000000;
    uint256 public pricePremium = 100000000000000000;
    uint256 public priceEconomy = 10000000000000000;

    int256 public luxuryBounds = 5;
    int256 public premiumBounds = 21;
    int256 public economyBounds = 50;

    PixelContract public pixelContract;
    uint256 public nixelPixelMint = 10000 * 10**18;

    string public baseURI;
    bool private mintingEnabled;

    receive() external payable {}

    constructor() ERC721("Nixel", "NIXEL") {
        baseURI = "https://ipfs.io/ipfs/";
    }

    function createSpawn(int256 x_pos, int256 y_pos) public onlyOwner {
        require(
            pixelContract != PixelContract(address(0)),
            "Pixel contract not set"
        );
        _blockOwner[x_pos][y_pos] = _msgSender();
        _blockTokenId[x_pos][y_pos] = totalBlocks + 1;
        _blockLocation[totalBlocks + 1] = [x_pos, y_pos];
        _BlockName[x_pos][y_pos] = "Nixel Spawn";
        _spawnBlockId[x_pos][y_pos] = totalBlocks + 1;
        emit MintNixel(_msgSender(), totalBlocks + 1, x_pos, y_pos);
        _mint(_msgSender(), 1 + totalBlocks++);
    }

    function setStakingContractAddress(address _stakingContractAddress)
        public
        onlyOwner
    {
        stakingContractAddress = _stakingContractAddress;
    }

    function setMintRewards(uint256 amount) public onlyOwner {
        nixelPixelMint = amount * 10**18;
    }

    function getMintRewards() public view returns (uint256 rewards) {
        return nixelPixelMint;
    }

    function setPixelContract(address contractAddress) public onlyOwner {
        pixelContract = PixelContract(contractAddress);
    }

    function recoveryToken(address payable tokenContract, uint256 _amount)
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

    function recoverETH() external payable onlyOwner {
        uint256 amount = address(this).balance;
        require(IERC20(address(this)).transfer(_msgSender(), amount));
        emit Withdraw(0, payable(address(this)), _msgSender(), amount);
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }

    function setBaseURI(string memory _newURI) public onlyOwner {
        baseURI = _newURI;
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

    function checkReserved(int256 x_pos, int256 y_pos)
        public
        view
        returns (bool)
    {
        return _reserved[x_pos][y_pos];
    }

    function buyBlock(int256 x_pos, int256 y_pos) public payable {
        require(
            _exists(blockTokenId(x_pos, y_pos)),
            "ERC721Metadata: Data query for nonexistent token."
        );
        require(_forSale[x_pos][y_pos], "Block not for sale");
        require(
            msg.value == _salePrice[x_pos][y_pos],
            "Incorrect payment amount"
        );
        require(
            _sellerAddress[x_pos][y_pos] != address(0),
            "Sellers address is invalid"
        );
        require(
            ownerOf(blockTokenId(x_pos, y_pos)) == _sellerAddress[x_pos][y_pos],
            "Seller does not own NFT"
        );
        uint256 toLiquidity = (msg.value * 1) / 100;
        uint256 toSeller = msg.value - toLiquidity;
        payable(_sellerAddress[x_pos][y_pos]).transfer(toSeller);
        payable(address(pixelContract)).transfer(toLiquidity);
        pixelContract.mint(_msgSender(), nixelPixelMint * toLiquidity);
        pixelContract.mint(
            _sellerAddress[x_pos][y_pos],
            nixelPixelMint * toLiquidity
        );
        pixelContract.mint(
            address(pixelContract),
            ((msg.value * nixelPixelMint) / 100) * 2 * 20
        );
        pixelContract.addLiquidity(
            ((msg.value * nixelPixelMint) / 100) * 2 * 20,
            toLiquidity
        );

        _blockOwner[x_pos][y_pos] = _msgSender();
        _transfer(
            _sellerAddress[x_pos][y_pos],
            _msgSender(),
            blockTokenId(x_pos, y_pos)
        );
        emit BlockBought(
            blockTokenId(x_pos, y_pos),
            _sellerAddress[x_pos][y_pos],
            _msgSender(),
            _salePrice[x_pos][y_pos],
            [x_pos, y_pos]
        );
        _forSale[x_pos][y_pos] = false;
        _salePrice[x_pos][y_pos] = 0;
        _sellerAddress[x_pos][y_pos] = address(0);
    }

    function setForSale(
        int256 x_pos,
        int256 y_pos,
        bool _isForSale,
        uint256 price
    ) public {
        require(
            _exists(blockTokenId(x_pos, y_pos)),
            "ERC721Metadata: Data query for nonexistent token."
        );
        require(
            ownerOf(blockTokenId(x_pos, y_pos)) == _msgSender(),
            "Not owner of NFT"
        );
        require(
            _isForSale
                ? _forSale[x_pos][y_pos] == false
                : _forSale[x_pos][y_pos],
            "NFT is already for sale"
        );
        require(_forRent[x_pos][y_pos] == false, "NFT is already for rent");
        require(
            getRenter(x_pos, y_pos) == address(0),
            "NFT is currently being rented"
        );
        _forSale[x_pos][y_pos] = _isForSale;
        _salePrice[x_pos][y_pos] = price;
        _sellerAddress[x_pos][y_pos] = _msgSender();
        emit BlockForSale(
            blockTokenId(x_pos, y_pos),
            _sellerAddress[x_pos][y_pos],
            _salePrice[x_pos][y_pos],
            [x_pos, y_pos]
        );
    }

    function checkForSale(int256 x_pos, int256 y_pos)
        public
        view
        returns (
            bool,
            uint256,
            address
        )
    {
        require(
            _exists(blockTokenId(x_pos, y_pos)),
            "ERC721Metadata: Data query for nonexistent token."
        );
        return (
            _forSale[x_pos][y_pos],
            _salePrice[x_pos][y_pos],
            _sellerAddress[x_pos][y_pos]
        );
    }

    function setForRent(
        int256 x_pos,
        int256 y_pos,
        bool _isForRent,
        uint256 durationDays,
        uint256 price
    ) public {
        require(
            _exists(blockTokenId(x_pos, y_pos)),
            "ERC721Metadata: Data query for nonexistent token."
        );
        require(
            ownerOf(blockTokenId(x_pos, y_pos)) == _msgSender(),
            "Not owner of NFT"
        );
        require(_forSale[x_pos][y_pos] == false, "NFT is already for sale");
        require(
            _isForRent
                ? _forRent[x_pos][y_pos] == false
                : _forRent[x_pos][y_pos] == true,
            "NFT is already for rent"
        );
        require(
            getRenter(x_pos, y_pos) == address(0),
            "NFT is currently being rented"
        );
        _forRent[x_pos][y_pos] = _isForRent;
        _rentDuration[x_pos][y_pos] = durationDays;
        _rentPrice[x_pos][y_pos] = price;
        _landlordAddress[x_pos][y_pos] = _msgSender();
        emit BlockForRent(
            blockTokenId(x_pos, y_pos),
            _msgSender(),
            _rentPrice[x_pos][y_pos],
            _rentDuration[x_pos][y_pos],
            [x_pos, y_pos]
        );
    }

    function checkForRent(int256 x_pos, int256 y_pos)
        public
        view
        returns (
            bool,
            uint256,
            uint256,
            address
        )
    {
        require(
            _exists(blockTokenId(x_pos, y_pos)),
            "ERC721Metadata: Data query for nonexistent token."
        );
        return (
            _forRent[x_pos][y_pos],
            _rentPrice[x_pos][y_pos],
            _rentDuration[x_pos][y_pos],
            _landlordAddress[x_pos][y_pos]
        );
    }

    function rentBlock(int256 x_pos, int256 y_pos) public payable {
        require(
            _exists(blockTokenId(x_pos, y_pos)),
            "ERC721Metadata: Data query for nonexistent token."
        );
        require(_forRent[x_pos][y_pos], "Block not for rent");
        require(
            msg.value == _rentPrice[x_pos][y_pos],
            "Incorrect payment amount"
        );
        require(
            _landlordAddress[x_pos][y_pos] != address(0),
            "Landlords address is invalid"
        );
        require(
            ownerOf(blockTokenId(x_pos, y_pos)) ==
                _landlordAddress[x_pos][y_pos],
            "Landlord does not own NFT"
        );
        require(
            getRenter(x_pos, y_pos) == address(0),
            "NFT is currently being rented"
        );
        uint256 toLiquidity = (msg.value * 1) / 100;
        uint256 toLandlord = msg.value - toLiquidity;
        payable(_landlordAddress[x_pos][y_pos]).transfer(toLandlord);
        payable(address(pixelContract)).transfer(toLiquidity);
        pixelContract.mint(_msgSender(), nixelPixelMint * toLiquidity);
        pixelContract.mint(
            _landlordAddress[x_pos][y_pos],
            nixelPixelMint * toLiquidity
        );
        pixelContract.mint(
            address(pixelContract),
            ((msg.value * nixelPixelMint) / 100) * 2 * 20
        );
        pixelContract.addLiquidity(
            ((msg.value * nixelPixelMint) / 100) * 2 * 20,
            toLiquidity
        );
        _renterAddress[x_pos][y_pos] = _msgSender();
        _forRent[x_pos][y_pos] = false;
        _rentStart[x_pos][y_pos] = block.timestamp;
        _rentStop[x_pos][y_pos] =
            block.timestamp +
            (_rentDuration[x_pos][y_pos] * 1 days);
        emit BlockRented(
            blockTokenId(x_pos, y_pos),
            _landlordAddress[x_pos][y_pos],
            _msgSender(),
            _rentPrice[x_pos][y_pos],
            _rentStart[x_pos][y_pos],
            _rentStop[x_pos][y_pos],
            [x_pos, y_pos]
        );
    }

    function getRenter(int256 x_pos, int256 y_pos)
        public
        view
        returns (address)
    {
        if (block.timestamp <= _rentStop[x_pos][y_pos]) {
            return _renterAddress[x_pos][y_pos];
        } else {
            return address(0);
        }
    }

    function getRenterByTokenId(uint256 tokenId) public view returns (address) {
        if (
            block.timestamp <=
            _rentStop[blockLocation(tokenId)[0]][blockLocation(tokenId)[1]]
        ) {
            return
                _renterAddress[blockLocation(tokenId)[0]][
                    blockLocation(tokenId)[1]
                ];
        } else {
            return address(0);
        }
    }

    function tokensOfRenter(address renter)
        public
        view
        returns (int256[][] memory)
    {
        int256[][] memory blocks = new int256[][](totalBlocks);
        for (uint256 i = 1; i <= totalBlocks; i++) {
            if (getRenterByTokenId(i) == renter) {
                blocks[i] = blockLocation(i);
            }
        }
        return blocks;
    }

    function rentStatus(int256 x_pos, int256 y_pos)
        public
        view
        returns (
            address renter,
            uint256 rentStart,
            uint256 rentStop,
            uint256 expires
        )
    {
        uint256 timeLeft = _rentStop[x_pos][y_pos] - block.timestamp;
        return (
            _renterAddress[x_pos][y_pos],
            _rentStart[x_pos][y_pos],
            _rentStop[x_pos][y_pos],
            timeLeft
        );
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
        if (
            getRenter(blockLocation(tokenId)[0], blockLocation(tokenId)[1]) !=
            address(0)
        ) {
            require(
                getRenter(
                    blockLocation(tokenId)[0],
                    blockLocation(tokenId)[1]
                ) == _msgSender(),
                "Not owner or renter of NFT"
            );
            _tokenURIRenter[tokenId] = _newURI;
            _BlockNameRented[blockLocation(tokenId)[0]][
                blockLocation(tokenId)[1]
            ] = _name;
        } else {
            require(ownerOf(tokenId) == _msgSender(), "Not owner of NFT");
            _tokenURI[tokenId] = _newURI;
            _BlockName[blockLocation(tokenId)[0]][
                blockLocation(tokenId)[1]
            ] = _name;
        }
        emit BlockUpdated(
            tokenId,
            _msgSender(),
            _newURI,
            [blockLocation(tokenId)[0], blockLocation(tokenId)[1]]
        );
    }

    function nameFromID(uint256 tokenId) public view returns (string memory) {
        require(
            _exists(tokenId),
            "ERC721Metadata: Name query for nonexistent token."
        );
        if (
            getRenter(blockLocation(tokenId)[0], blockLocation(tokenId)[1]) !=
            address(0)
        ) {
            return
                _BlockNameRented[blockLocation(tokenId)[0]][
                    blockLocation(tokenId)[1]
                ];
        } else {
            return
                _BlockName[blockLocation(tokenId)[0]][
                    blockLocation(tokenId)[1]
                ];
        }
    }

    function nameFromLocation(int256 x_pos, int256 y_pos)
        public
        view
        returns (string memory)
    {
        require(blockOwner(x_pos, y_pos) != address(0), "NFT does not exist");
        if (getRenter(x_pos, y_pos) != address(0)) {
            return _BlockNameRented[x_pos][y_pos];
        } else {
            return _BlockName[x_pos][y_pos];
        }
    }

    function setNFTName(
        int256 x_pos,
        int256 y_pos,
        string memory name
    ) public {
        if (getRenter(x_pos, y_pos) != address(0)) {
            require(
                getRenter(x_pos, y_pos) == _msgSender(),
                "Not owner or renter of NFT"
            );
            _BlockNameRented[x_pos][y_pos] = name;
        } else {
            require(
                blockOwner(x_pos, y_pos) == _msgSender(),
                "Not owner of NFT"
            );
            _BlockName[x_pos][y_pos] = name;
        }
    }

    function getBlockMintPrice(int256 x_pos, int256 y_pos)
        public
        view
        virtual
        returns (uint256)
    {
        if (
            y_pos >= (luxuryBounds * -1) &&
            x_pos >= (luxuryBounds * -1) &&
            y_pos <= luxuryBounds &&
            x_pos <= luxuryBounds
        ) {
            return priceLuxury;
        } else {
            if (
                y_pos >= (premiumBounds * -1) &&
                x_pos >= (premiumBounds * -1) &&
                y_pos <= premiumBounds &&
                x_pos <= premiumBounds
            ) {
                return pricePremium;
            } else {
                if (
                    y_pos >= (economyBounds * -1) &&
                    x_pos >= (economyBounds * -1) &&
                    y_pos <= economyBounds &&
                    x_pos <= economyBounds
                ) {
                    return priceEconomy;
                } else {
                    return 0;
                }
            }
        }
    }

    function setPriceLuxury(uint256 price) public onlyOwner {
        require(
            totalBlocks == maxBlocks,
            "Cannot change prices until all current blocks have been bought"
        );
        priceLuxury = price;
    }

    function setPricePremium(uint256 price) public onlyOwner {
        require(
            totalBlocks == maxBlocks,
            "Cannot change prices until all current blocks have been bought"
        );
        pricePremium = price;
    }

    function setPriceEconomy(uint256 price) public onlyOwner {
        require(
            totalBlocks == maxBlocks,
            "Cannot change prices until all current blocks have been bought"
        );
        priceEconomy = price;
    }

    function setLuxuryBounds(int256 bounds) public onlyOwner {
        require(
            totalBlocks == maxBlocks,
            "Cannot increase blocks until all current blocks have been bought"
        );
        luxuryBounds = bounds;
    }

    function setPremiumBounds(int256 bounds) public onlyOwner {
        require(
            totalBlocks == maxBlocks,
            "Cannot increase blocks until all current blocks have been bought"
        );
        premiumBounds = bounds;
    }

    function setEconomyBounds(int256 bounds) public onlyOwner {
        require(
            totalBlocks == maxBlocks,
            "Cannot increase blocks until all current blocks have been bought"
        );
        economyBounds = bounds;
    }

    function setMaxBlocks(uint256 _maxBlocks) public onlyOwner {
        require(
            totalBlocks == maxBlocks,
            "Cannot increase blocks until all current blocks have been bought"
        );
        maxBlocks = _maxBlocks;
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
        if (
            getRenter(blockLocation(tokenId)[0], blockLocation(tokenId)[1]) !=
            address(0)
        ) {
            return string(abi.encodePacked(baseURI, _tokenURIRenter[tokenId]));
        } else {
            return string(abi.encodePacked(baseURI, _tokenURI[tokenId]));
        }
    }

    function blockURI(int256 x_pos, int256 y_pos)
        public
        view
        virtual
        returns (string memory)
    {
        require(
            _exists(blockTokenId(x_pos, y_pos)),
            "ERC721Metadata: URI query for nonexistent token."
        );
        if (getRenter(x_pos, y_pos) != address(0)) {
            return
                string(
                    abi.encodePacked(
                        baseURI,
                        _tokenURIRenter[blockTokenId(x_pos, y_pos)]
                    )
                );
        } else {
            return
                string(
                    abi.encodePacked(
                        baseURI,
                        _tokenURI[blockTokenId(x_pos, y_pos)]
                    )
                );
        }
    }

    function setEnableMint(bool _enable) public onlyOwner {
        mintingEnabled = _enable;
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
        require(mintingEnabled, "Minting not enabled");
        require(
            pixelContract != PixelContract(address(0)),
            "Pixel contract not set"
        );
        require(blockOwner(x_pos, y_pos) == address(0), "Block already minted");
        require(totalBlocks + 1 <= maxBlocks, "Max supply reached");
        require(
            (y_pos >= (economyBounds * -1) &&
                y_pos <= (economyBounds) &&
                x_pos >= (economyBounds * -1) &&
                x_pos <= (economyBounds)) == true,
            "Out of bounds"
        );
        require(_spawnBlockId[x_pos][y_pos] == 0, "Cannot mint a spawn block");
        require(
            (_reserved[x_pos][y_pos]) == false,
            "This NFT is currently reserved"
        );
        if (_reservePrice[x_pos][y_pos] == 0) {
            if (
                y_pos >= (luxuryBounds * -1) &&
                x_pos >= (luxuryBounds * -1) &&
                y_pos <= luxuryBounds &&
                x_pos <= luxuryBounds
            ) {
                require(
                    msg.value == priceLuxury,
                    "Value error, please check price."
                );
            } else {
                if (
                    y_pos >= (premiumBounds * -1) &&
                    x_pos >= (premiumBounds * -1) &&
                    y_pos <= premiumBounds &&
                    x_pos <= premiumBounds
                ) {
                    require(
                        msg.value == pricePremium,
                        "Value error, please check price."
                    );
                } else {
                    if (
                        y_pos >= (economyBounds * -1) &&
                        x_pos >= (economyBounds * -1) &&
                        y_pos <= economyBounds &&
                        x_pos <= economyBounds
                    ) {
                        require(
                            msg.value == priceEconomy,
                            "Value error, please check price."
                        );
                    }
                }
            }
        } else {
            require(
                msg.value == _reservePrice[x_pos][y_pos],
                "Value error, please check price."
            );
        }
        uint256 amountOwner = msg.value / 2;
        uint256 amountLiquidity = msg.value / 2;
        payable(owner()).transfer(amountOwner);
        payable(address(pixelContract)).transfer(amountLiquidity);
        pixelContract.mint(_msgSender(), msg.value * nixelPixelMint);
        pixelContract.mint(
            address(pixelContract),
            msg.value * nixelPixelMint * 20
        );
        pixelContract.addLiquidity(
            msg.value * nixelPixelMint * 20,
            amountLiquidity
        );
        _blockOwner[x_pos][y_pos] = _msgSender();
        _blockTokenId[x_pos][y_pos] = totalBlocks + 1;
        _blockLocation[totalBlocks + 1] = [x_pos, y_pos];
        _BlockName[x_pos][y_pos] = "";
        emit MintNixel(_msgSender(), totalBlocks + 1, x_pos, y_pos);
        _mint(_msgSender(), 1 + totalBlocks++);
    }
}