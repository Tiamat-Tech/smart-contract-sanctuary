// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

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
        int256[2] location,
        bool forSale
    );

    event BlockForRent(
        uint256 tokenId,
        address landlord,
        uint256 price,
        uint256 duration,
        int256[2] location,
        bool forRent
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

    event Deposit(
        uint256 tokenId,
        address tokenContract,
        address from,
        uint256 amount
    );

    event ClaimToken(
        uint256 tokenId,
        address tokenContract,
        address claimer,
        uint256 amount
    );

    event Withdraw(
        uint256 tokenId,
        address tokenContract,
        address to,
        uint256 amount
    );

    uint256 public totalBlocks;
    uint256 public maxBlocks;
    int256 public totalSpawns;

    mapping(uint256 => string) private _tokenURI;
    mapping(uint256 => string) private _tokenURIRenter;
    mapping(int256 => mapping(int256 => string)) private _BlockName;
    mapping(int256 => mapping(int256 => string)) private _BlockNameRented;

    mapping(int256 => mapping(int256 => bool)) private _forSale;
    mapping(int256 => mapping(int256 => uint256)) private _salePrice;
    mapping(int256 => mapping(int256 => address)) private _sellerAddress;

    mapping(int256 => mapping(int256 => bool)) private _forRent;
    mapping(int256 => mapping(int256 => uint256)) private _rentPrice;
    mapping(int256 => mapping(int256 => address)) private _landlordAddress;
    mapping(int256 => mapping(int256 => uint256)) private _rentDuration;
    mapping(int256 => mapping(int256 => uint256)) private _rentStart;

    mapping(uint256 => mapping(address => uint256)) private _depositBalance;
    mapping(uint256 => mapping(address => bool)) private _claimable;
    mapping(uint256 => mapping(address => uint256)) private _claimableBalance;
    mapping(uint256 => mapping(address => uint256)) private _claimRate;
    mapping(uint256 => mapping(address => uint256)) private _lastClaimed;

    mapping(int256 => mapping(int256 => uint256)) private _spawnBlockId;

    mapping(int256 => int256[]) private _spawnLocation;

    uint256 public priceLuxury = 150000000000000000;
    uint256 public pricePremium = 100000000000000000;
    uint256 public priceEconomy = 10000000000000000;

    int256 public luxuryBounds = 5;
    int256 public premiumBounds = 21;
    int256 public economyBounds = 50;
    int256 public minMax;

    PixelContract public pixelContract;
    uint256 public nixelPixelMint = 10000 * 10**18;

    string public baseURI;
    bool private mintingEnabled;

    receive() external payable {}

    fallback() external payable {}

    constructor() ERC721("Nixel", "NIXEL") {
        baseURI = "https://nixel.io/ipfs/";
    }

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function createSpawn(
        int256 x_pos,
        int256 y_pos,
        int256 newMinMax,
        uint256 newMaxBlocks
    ) public onlyOwner {
        require(
            pixelContract != PixelContract(address(0)),
            "Pixel contract not set"
        );
        require(
            blockOwner(x_pos, y_pos) == address(0),
            "Cannot create spawn out of already minted block"
        );
        require(
            totalBlocks == maxBlocks,
            "Cannot create spawns until all current maxBlocks minted"
        );
        _blockOwner[x_pos][y_pos] = _msgSender();
        _blockTokenId[x_pos][y_pos] = totalBlocks + 1;
        _blockLocation[totalBlocks + 1] = [x_pos, y_pos];
        _BlockName[x_pos][y_pos] = "Nixel Spawn";
        _spawnBlockId[x_pos][y_pos] = totalBlocks + 1;
        _spawnLocation[totalSpawns + 1] = [x_pos, y_pos];
        minMax = newMinMax;
        maxBlocks = newMaxBlocks;
        totalSpawns += 1;
        emit MintNixel(_msgSender(), totalBlocks + 1, x_pos, y_pos);
        _mint(_msgSender(), 1 + totalBlocks++);
    }

    function getSpawn(int256 spawnId) public view returns (int256[] memory) {
        return _spawnLocation[spawnId];
    }

    function getClosestSpawn(int256 x_pos, int256 y_pos)
        public
        view
        returns (int256[2] memory)
    {
        int256 x1_bounds = x_pos;
        int256 x2_bounds = x_pos;
        int256 y1_bounds = y_pos;
        int256 y2_bounds = y_pos;
        for (int256 i = 0; i < minMax; i++) {
            x1_bounds += i;
            x2_bounds -= i;
            y1_bounds -= i;
            y2_bounds += i;
            for (int256 j = 1; j <= totalSpawns; j++) {
                int256 x = _spawnLocation[j][0];
                int256 y = _spawnLocation[j][1];
                if (
                    x <= x1_bounds &&
                    x >= x2_bounds &&
                    y <= y2_bounds &&
                    y >= y1_bounds
                ) {
                    return [_spawnLocation[j][0], _spawnLocation[j][1]];
                }
            }
        }
        int256 zX = 0;
        int256 zY = 0;
        return [zX, zY];
    }

    function setMintRewards(uint256 amount) public onlyOwner {
        nixelPixelMint = amount * 10**18;
    }

    function setPixelContract(address contractAddress) public onlyOwner {
        require(
            pixelContract == PixelContract(address(0)),
            "Pixel Contract already set"
        );
        pixelContract = PixelContract(contractAddress);
    }

    function setStakingContractAddress(address _stakingContractAddress)
        public
        onlyOwner
    {
        require(
            stakingContractAddress == address(0),
            "Staking Contract already set"
        );
        stakingContractAddress = _stakingContractAddress;
    }

    function depositToken(
        int256 x_pos,
        int256 y_pos,
        address payable tokenContract,
        uint256 amount
    ) external payable {
        require(
            _exists(blockTokenId(x_pos, y_pos)),
            "ERC721Metadata: Query for nonexistent token"
        );
        require(
            IERC20(tokenContract).transferFrom(
                _msgSender(),
                address(this),
                amount
            )
        );
        _depositBalance[blockTokenId(x_pos, y_pos)][tokenContract] += amount;
        emit Deposit(
            blockTokenId(x_pos, y_pos),
            tokenContract,
            _msgSender(),
            amount
        );
    }

    function checkClaimable(
        int256 x_pos,
        int256 y_pos,
        address tokenContract
    )
        public
        view
        returns (
            bool claimable,
            uint256 claimableBalance,
            uint256 claimRate
        )
    {
        if (
            block.timestamp -
                _lastClaimed[blockTokenId(x_pos, y_pos)][_msgSender()] >=
            _claimRate[blockTokenId(x_pos, y_pos)][tokenContract]
        ) {
            return (
                _claimable[blockTokenId(x_pos, y_pos)][tokenContract],
                _claimableBalance[blockTokenId(x_pos, y_pos)][tokenContract],
                _claimRate[blockTokenId(x_pos, y_pos)][tokenContract]
            );
        } else {
            return (
                _claimable[blockTokenId(x_pos, y_pos)][tokenContract],
                0,
                _claimRate[blockTokenId(x_pos, y_pos)][tokenContract]
            );
        }
    }

    function claimToken(
        int256 x_pos,
        int256 y_pos,
        address payable tokenContract,
        uint256 amount
    ) external payable {
        require(
            _claimable[blockTokenId(x_pos, y_pos)][tokenContract],
            "Claiming this token has been set to false"
        );
        require(
            _depositBalance[blockTokenId(x_pos, y_pos)][tokenContract] -
                amount >=
                0,
            "Insufficient Funds to Claim"
        );
        require(
            _claimableBalance[blockTokenId(x_pos, y_pos)][tokenContract] ==
                amount,
            "Trying to claim invalid amount"
        );
        require(
            block.timestamp -
                _lastClaimed[blockTokenId(x_pos, y_pos)][_msgSender()] >=
                _claimRate[blockTokenId(x_pos, y_pos)][tokenContract],
            "Already claimed"
        );

        _lastClaimed[blockTokenId(x_pos, y_pos)][_msgSender()] = block
            .timestamp;
        _depositBalance[blockTokenId(x_pos, y_pos)][tokenContract] -= amount;
        require(IERC20(tokenContract).transfer(_msgSender(), amount));
        emit ClaimToken(
            blockTokenId(x_pos, y_pos),
            tokenContract,
            _msgSender(),
            amount
        );
    }

    function setClaimable(
        int256 x_pos,
        int256 y_pos,
        uint256 claimAmount,
        uint256 dayRate,
        address tokenContract,
        bool claimable
    ) public {
        require(
            ownerOf(blockTokenId(x_pos, y_pos)) == _msgSender(),
            "Not owner of NFT"
        );
        require(dayRate > 0, "Day Rate cannot be 0");
        require(claimAmount > 0, "Claim Amount cannot be 0");
        require(
            _depositBalance[blockTokenId(x_pos, y_pos)][tokenContract] >
                claimAmount,
            "Deposit balance insufficient for claim amount"
        );
        _claimRate[blockTokenId(x_pos, y_pos)][tokenContract] =
            dayRate *
            1 days;
        _claimableBalance[blockTokenId(x_pos, y_pos)][
            tokenContract
        ] = claimAmount;
        _claimable[blockTokenId(x_pos, y_pos)][tokenContract] = claimable;
    }

    function depositBalance(
        int256 x_pos,
        int256 y_pos,
        address payable tokenContract
    ) public view returns (uint256 balance) {
        require(
            _exists(blockTokenId(x_pos, y_pos)),
            "ERC721Metadata: Query for nonexistent token"
        );
        return _depositBalance[blockTokenId(x_pos, y_pos)][tokenContract];
    }

    function withdrawToken(
        int256 x_pos,
        int256 y_pos,
        address payable tokenContract,
        uint256 amount
    ) external payable {
        require(
            _exists(blockTokenId(x_pos, y_pos)),
            "ERC721Metadata: Query for nonexistent token"
        );
        require(
            ownerOf(blockTokenId(x_pos, y_pos)) == _msgSender(),
            "Not owner of NFT"
        );
        require(
            _depositBalance[blockTokenId(x_pos, y_pos)][tokenContract] >=
                amount,
            "Not enough funds for requested amount"
        );
        require(IERC20(tokenContract).transfer(_msgSender(), amount));
        _depositBalance[blockTokenId(x_pos, y_pos)][tokenContract] -= amount;
        emit Withdraw(
            blockTokenId(x_pos, y_pos),
            tokenContract,
            _msgSender(),
            amount
        );
    }

    function recoverETH() public payable onlyOwner returns (bytes memory) {
        (bool sent, bytes memory data) = _msgSender().call{value: getBalance()}(
            ""
        );
        require(sent, "Failed to send Ether");
        return data;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }

    function setBaseURI(string memory _newURI) public onlyOwner {
        baseURI = _newURI;
    }

    function buyBlock(int256 x_pos, int256 y_pos) public payable {
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
        payable(_sellerAddress[x_pos][y_pos]).transfer(msg.value);
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
            [x_pos, y_pos],
            _isForSale
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
        require(durationDays > 0, "Cannot be 0 days");
        require(durationDays <= 365, "Cannot be greater than 365 days");
        _forRent[x_pos][y_pos] = _isForRent;
        _rentDuration[x_pos][y_pos] = durationDays;
        _rentPrice[x_pos][y_pos] = price;
        _landlordAddress[x_pos][y_pos] = _msgSender();
        emit BlockForRent(
            blockTokenId(x_pos, y_pos),
            _msgSender(),
            _rentPrice[x_pos][y_pos],
            _rentDuration[x_pos][y_pos],
            [x_pos, y_pos],
            _isForRent
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
        return (
            _forRent[x_pos][y_pos],
            _rentPrice[x_pos][y_pos],
            _rentDuration[x_pos][y_pos],
            _landlordAddress[x_pos][y_pos]
        );
    }

    function rentBlock(int256 x_pos, int256 y_pos) public payable {
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
        payable(_landlordAddress[x_pos][y_pos]).transfer(msg.value);
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
        int256 x = getClosestSpawn(x_pos, y_pos)[0];
        int256 y = getClosestSpawn(x_pos, y_pos)[1];

        if (
            y_pos >= y + (luxuryBounds * -1) &&
            x_pos >= x + (luxuryBounds * -1) &&
            y_pos <= y + luxuryBounds &&
            x_pos <= x + luxuryBounds
        ) {
            return priceLuxury;
        } else {
            if (
                y_pos >= y + (premiumBounds * -1) &&
                x_pos >= x + (premiumBounds * -1) &&
                y_pos <= y + premiumBounds &&
                x_pos <= x + premiumBounds
            ) {
                return pricePremium;
            } else {
                if (
                    y_pos >= y + (economyBounds * -1) &&
                    x_pos >= x + (economyBounds * -1) &&
                    y_pos <= y + economyBounds &&
                    x_pos <= x + economyBounds
                ) {
                    return priceEconomy;
                } else {
                    return priceEconomy;
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
            (y_pos >= (minMax * -1) &&
                y_pos <= (minMax) &&
                x_pos >= (minMax * -1) &&
                x_pos <= (minMax)) == true,
            "Out of bounds"
        );
        int256 x = getClosestSpawn(x_pos, y_pos)[0];
        int256 y = getClosestSpawn(x_pos, y_pos)[1];
        if (
            y_pos >= y + (luxuryBounds * -1) &&
            x_pos >= x + (luxuryBounds * -1) &&
            y_pos <= y + luxuryBounds &&
            x_pos <= x + luxuryBounds
        ) {
            require(
                msg.value == priceLuxury,
                "Value error, please check price."
            );
        } else {
            if (
                y_pos >= y + (premiumBounds * -1) &&
                x_pos >= x + (premiumBounds * -1) &&
                y_pos <= y + premiumBounds &&
                x_pos <= x + premiumBounds
            ) {
                require(
                    msg.value == pricePremium,
                    "Value error, please check price."
                );
            } else {
                require(
                    msg.value == priceEconomy,
                    "Value error, please check price."
                );
            }
        }
        uint256 amountOwner = msg.value / 2;
        uint256 amountLiquidity = msg.value / 2;
        uint256 mintAmount = msg.value == priceLuxury
            ? 1500 * 10**18
            : msg.value == pricePremium
            ? 1000 * 10**18
            : 100 * 10**18;
        payable(owner()).transfer(amountOwner);
        payable(address(pixelContract)).transfer(amountLiquidity);
        pixelContract.mint(_msgSender(), mintAmount);
        pixelContract.mint(address(pixelContract), mintAmount * 20);
        pixelContract.addLiquidity(mintAmount * 20, amountLiquidity);
        _blockOwner[x_pos][y_pos] = _msgSender();
        _blockTokenId[x_pos][y_pos] = totalBlocks + 1;
        _blockLocation[totalBlocks + 1] = [x_pos, y_pos];
        _BlockName[x_pos][y_pos] = "";
        emit MintNixel(_msgSender(), totalBlocks + 1, x_pos, y_pos);
        _mint(_msgSender(), 1 + totalBlocks++);
    }
}