// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.0;
import "./IDwarfs_NFT.sol";
import "./IClan.sol";
import "./ITraits.sol";
import "./GOD.sol";
import "./Strings.sol";

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";

/// @title Dwarfs NFT
/// @author Bounyavong
/// @dev Dwarfs NFT logic is implemented and this is the updradeable
contract Dwarfs_NFT is ERC721Upgradeable, IDwarfs_NFT {
    // eth prices for mint
    uint256[] public MINT_ETH_PRICES;

    // god prices for mint
    uint256[] public MINT_GOD_PRICES;

    // max number of tokens that can be minted in each phase- 20000 in production
    uint256[] public MAX_GEN_TOKENS;

    // sold amount percent by eth (50%)
    uint16 public MAX_TOKENS_ETH_SOLD;

    // number of dwarfs in a city
    uint16[] public MAX_MOBSTERS_CITY;

    // number of tokens have been minted so far
    uint32 private minted;

    // mapping from tokenId to a struct containing the token's traits
    mapping(uint32 => DwarfTrait) private mapTokenTraits;
    // mapping from hashed(tokenTrait) to the tokenId it's associated with
    // used to ensure there are no duplicates
    mapping(uint256 => uint32) private mapTraithashToken;

    // reference to the Clan
    IClan private clan;
    // reference to the ITrait
    ITraits private nft_traits;
    // reference to $GOD for burning in mint
    GOD private god;

    // traits parameters range
    uint8[] public MAX_TRAITS;

    // Base URI
    string private baseURI;

    // current chosen city ID
    uint8 private cityId;

    // number of dwarfs in the current city
    uint16[] private count_mobsters;

    // current number of boss
    uint8 private totalBosses;

    // current number of dwarfathers
    uint8 private totalDwarfathers;

    // the rest number of dwarfs in the current city
    uint16 remainMobstersOfCity;

    // static boss traits
    DwarfTrait[] public bossTraits;

    // static dwarfather traits
    DwarfTrait[] public dwarfatherTraits;

    // current generation number of NFT
    uint8 private generationOfNft;

    // owner address
    address private _owner;

    // paused flag
    bool private _paused;

    /**
     * @dev instantiates contract and rarity tables
     * @param _god the GOD address
     */
    function initialize(address _god, address _traits)
        public
        virtual
        initializer
    {
        __ERC721_init("Game Of Dwarfs", "DWARF");
        god = GOD(_god);
        nft_traits = ITraits(_traits);
        _setOwner(_msgSender());
        _paused = false;

        // eth prices for mint
        MINT_ETH_PRICES = [
            0.0012 ether, // ETH price in Gen0
            0.0014 ether, // ETH price in Gen1
            0.0016 ether, // ETH price in Gen2
            0.0018 ether // ETH price in Gen3
        ];

        // god prices for mint
        MINT_GOD_PRICES = [
            0 ether, // GOD price in Gen0
            100000 ether, // GOD price in Gen1
            120000 ether, // GOD price in Gen2
            140000 ether // GOD price in Gen3
        ];

        // max number of tokens that can be minted in each phase- 20000 in production
        MAX_GEN_TOKENS = [
            8000, // number of tokens in Gen0
            12000, // number of tokens in Gen1
            16000, // number of tokens in Gen2
            20000
        ]; // number of tokens in Gen3

        // sold amount percent by eth (50%)
        MAX_TOKENS_ETH_SOLD = 50;

        // number of dwarfs in a city
        MAX_MOBSTERS_CITY = [
            150, // max dwarfsoldiers in a city
            45, // max dwarfcapos in a city
            4, // max boss in a city
            1
        ]; // max dwarfather in a city

        // traits parameters range
        MAX_TRAITS = [
            255, // background
            255, // weapon
            255, // body
            255, // outfit
            255, // head
            255, // ears
            255, // mouth
            255, // nose
            255, // eyes
            255, // brows
            255, // hair
            255, // facialhair
            255 // eyewear
        ];

        // number of dwarfs in the current city
        count_mobsters = [0, 0, 0, 0];

        // the rest number of dwarfs in the current city
        remainMobstersOfCity = 200;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev set the address of the new owner.
     */
    function _setOwner(address newOwner) private {
        _owner = newOwner;
    }

    /**
     * @dev Returns true if the contract is paused, and false otherwise.
     */
    function paused() public view virtual returns (bool) {
        return _paused;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    modifier whenNotPaused() {
        require(!paused(), "Pausable: paused");
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is paused.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    modifier whenPaused() {
        require(paused(), "Pausable: not paused");
        _;
    }

    /**
     * @dev Triggers stopped state.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    function _pause() internal virtual whenNotPaused {
        _paused = true;
    }

    /**
     * @dev Returns to normal state.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    function _unpause() internal virtual whenPaused {
        _paused = false;
    }

    /**
     * @dev mint a token by owner
     * @param amount the mint amount
     * @param s the traits array
     */
    function mintByOwner(uint16 amount, DwarfTrait[] memory s)
        external
        onlyOwner
    {
        require(s.length == amount, "Invalid parameter");
        for (uint16 i = 0; i < amount; i++) {
            if (mapTraithashToken[getTraitHash(s[i])] == 0) {
                minted++;
                mapTokenTraits[minted] = s[i];
                mapTraithashToken[getTraitHash(s[i])] = minted;

                _safeMint(_msgSender(), minted);
            }
        }
    }

    /**
     * @dev mint a token - 85% Merchant, 15% Mobsters
     * @param amount the amount of the token
     */
    function mint(uint16 amount) external payable whenNotPaused {
        require(tx.origin == _msgSender(), "Only EOA");
        require(minted + amount <= MAX_GEN_TOKENS[3], "All tokens minted");
        require(amount > 0 && amount <= 10, "Invalid mint amount");
        if (minted < MAX_GEN_TOKENS[0]) {
            require(
                minted + amount <= MAX_GEN_TOKENS[0],
                "All tokens of generation 0 on-sale already sold"
            );
            require(
                amount * MINT_ETH_PRICES[0] <= msg.value,
                "Invalid ETH payment amount"
            );
        } else if (
            minted >= MAX_GEN_TOKENS[0] &&
            minted <
            MAX_GEN_TOKENS[0] +
                ((MAX_GEN_TOKENS[1] - MAX_GEN_TOKENS[0]) *
                    MAX_TOKENS_ETH_SOLD) /
                100
        ) {
            require(
                minted + amount <=
                    MAX_GEN_TOKENS[0] +
                        ((MAX_GEN_TOKENS[1] - MAX_GEN_TOKENS[0]) *
                            MAX_TOKENS_ETH_SOLD) /
                        100,
                "All tokens of generation 1 on-sale already sold"
            );
            require(
                amount * MINT_ETH_PRICES[1] <= msg.value,
                "Invalid ETH payment amount"
            );
        } else if (
            minted >= MAX_GEN_TOKENS[1] &&
            minted <
            MAX_GEN_TOKENS[1] +
                ((MAX_GEN_TOKENS[2] - MAX_GEN_TOKENS[1]) *
                    MAX_TOKENS_ETH_SOLD) /
                100
        ) {
            require(
                minted + amount <=
                    MAX_GEN_TOKENS[1] +
                        ((MAX_GEN_TOKENS[2] - MAX_GEN_TOKENS[1]) *
                            MAX_TOKENS_ETH_SOLD) /
                        100,
                "All tokens of generation 2 on-sale already sold"
            );
            require(
                amount * MINT_ETH_PRICES[2] <= msg.value,
                "Invalid ETH payment amount"
            );
        } else if (
            minted >= MAX_GEN_TOKENS[2] &&
            minted <
            MAX_GEN_TOKENS[2] +
                ((MAX_GEN_TOKENS[3] - MAX_GEN_TOKENS[2]) *
                    MAX_TOKENS_ETH_SOLD) /
                100
        ) {
            require(
                minted + amount <=
                    MAX_GEN_TOKENS[2] +
                        ((MAX_GEN_TOKENS[3] - MAX_GEN_TOKENS[2]) *
                            MAX_TOKENS_ETH_SOLD) /
                        100,
                "All tokens of generation 3 on-sale already sold"
            );
            require(
                amount * MINT_ETH_PRICES[3] <= msg.value,
                "Invalid ETH payment amount"
            );
        }

        uint256 totalGodCost = 0;
        for (uint16 i = 0; i < amount; i++) {
            minted++;
            totalGodCost += mintCost(minted);
        }
        if (totalGodCost > 0) god.burn(_msgSender(), totalGodCost);

        uint32[] memory tokenIds = new uint32[](amount);
        uint256 seed;
        minted = minted - amount;
        for (uint16 i = 0; i < amount; i++) {
            if (i == 0 || clan.getAvailableCity() != cityId) {
                cityId = clan.getAvailableCity();
                count_mobsters = clan.getNumMobstersOfCity(cityId);
            }

            minted++;
            if (minted > MAX_GEN_TOKENS[generationOfNft]) {
                generationOfNft++;
            }
            seed = random(minted);
            generate(minted, seed);

            _safeMint(address(clan), minted);
            tokenIds[i] = minted;
        }

        clan.addManyToClan(tokenIds);
    }

    /**
     * @dev the calculate the cost of mint by the generating
     * @param tokenId the ID to check the cost of to mint
     * @return the GOD cost of the given token ID
     */
    function mintCost(uint32 tokenId) public view returns (uint256) {
        if (tokenId <= MAX_GEN_TOKENS[0]) return MINT_GOD_PRICES[0];
        else if (
            tokenId <=
            MAX_GEN_TOKENS[0] +
                ((MAX_GEN_TOKENS[1] - MAX_GEN_TOKENS[0]) *
                    MAX_TOKENS_ETH_SOLD) /
                100
        ) return 0;
        else if (tokenId <= MAX_GEN_TOKENS[1]) return MINT_GOD_PRICES[1];
        if (
            tokenId <=
            MAX_GEN_TOKENS[1] +
                ((MAX_GEN_TOKENS[2] - MAX_GEN_TOKENS[1]) *
                    MAX_TOKENS_ETH_SOLD) /
                100
        ) return 0;
        else if (tokenId <= MAX_GEN_TOKENS[2]) return MINT_GOD_PRICES[2];
        else if (
            tokenId <=
            MAX_GEN_TOKENS[2] +
                ((MAX_GEN_TOKENS[3] - MAX_GEN_TOKENS[2]) *
                    MAX_TOKENS_ETH_SOLD) /
                100
        ) return 0;
        else if (tokenId <= MAX_GEN_TOKENS[3]) return MINT_GOD_PRICES[3];

        return 0;
    }

    /**
     * @dev transfer token
     * @param from the address of source
     * @param to the address of destination
     * @param tokenId the token id
     */
    function transferFrom(
        address from,
        address to,
        uint32 tokenId
    ) public virtual {
        require(
            _isApprovedOrOwner(_msgSender(), tokenId),
            "ERC721: transfer caller is not owner nor approved"
        );
        _transfer(from, to, tokenId);
    }

    /**
     * @dev generates traits for a specific token, checking to make sure it's unique
     * @param tokenId the id of the token to generate traits for
     * @param seed a pseudorandom 256 bit number to derive traits from
     * @return t - a struct of traits for the given token ID
     */
    function generate(uint32 tokenId, uint256 seed)
        internal
        returns (DwarfTrait memory t)
    {
        // check the merchant or mobster
        uint8 alphaIndex = 0;
        bool bConstantMerchant = (cityId >
            clan.getMaxNumCityOfGen()[generationOfNft] &&
            tokenId <= MAX_GEN_TOKENS[generationOfNft]);
        if (bConstantMerchant == false) {
            alphaIndex = selectDwarfType(seed);
        }
        while (true) {
            t = selectTraits(seed, alphaIndex);
            if (mapTraithashToken[getTraitHash(t)] == 0) {
                t.generation = generationOfNft;
                t.isMerchant = (alphaIndex < 5);
                t.cityId = (alphaIndex < 5) ? 0 : cityId; // if Merchant, cityId should be 0 (no city)
                t.alphaIndex = alphaIndex;

                mapTokenTraits[tokenId] = t;
                mapTraithashToken[getTraitHash(t)] = tokenId;

                if (t.isMerchant == false) count_mobsters[t.alphaIndex - 5]++;

                if (bConstantMerchant == false) {
                    remainMobstersOfCity--;
                    if (remainMobstersOfCity <= 0) {
                        remainMobstersOfCity =
                            MAX_MOBSTERS_CITY[0] + // dwarfsoldier
                            MAX_MOBSTERS_CITY[1] + // dwarfcapos
                            MAX_MOBSTERS_CITY[2] + // boss
                            MAX_MOBSTERS_CITY[3]; // dwarfather
                    }
                }

                return t;
            }
        }
    }

    /**
     * @dev select Dwarf Type Merchant : alphaIndex = 0 ~ 4 Mobster : alphaIndex = 5 ~ 8
     * @param seed the seed to generate random
     * @return alphaIndex the alpha index
     */
    function selectDwarfType(uint256 seed)
        internal
        view
        returns (uint8 alphaIndex)
    {
        uint256 cur_seed = random(seed);
        bool isMerchant = (cur_seed & 0xFFFF) % 100 > 15;

        if (isMerchant == true) {
            return 0;
        } else {
            cur_seed = random(cur_seed);

            if (
                (cur_seed & 0xFFFF) % remainMobstersOfCity <
                (MAX_MOBSTERS_CITY[3] - count_mobsters[3]) // checking the dwarfather
            ) {
                return 8;
            } else if (
                (cur_seed & 0xFFFF) % remainMobstersOfCity <
                (MAX_MOBSTERS_CITY[2] +
                    MAX_MOBSTERS_CITY[3] -
                    count_mobsters[2] -
                    count_mobsters[3]) // checking the boss
            ) {
                return 7;
            } else if (
                (cur_seed & 0xFFFF) % remainMobstersOfCity <
                (MAX_MOBSTERS_CITY[1] +
                    MAX_MOBSTERS_CITY[2] +
                    MAX_MOBSTERS_CITY[3] -
                    count_mobsters[1] -
                    count_mobsters[2] -
                    count_mobsters[3]) // checking the dwarfcapos
            ) {
                return 6;
            } else {
                return 5; // dwarfsoldier
            }
        }
    }

    /**
     * @dev selects the species and all of its traits based on the seed value
     * @param seed a pseudorandom 256 bit number to derive traits from
     * @return t -  a struct of randomly selected traits
     */
    function selectTraits(uint256 seed, uint8 alphaIndex)
        internal
        returns (DwarfTrait memory t)
    {
        // if Boss
        if (alphaIndex == 7) {
            // set the custom traits to boss
            t = bossTraits[totalBosses];
        } else if (alphaIndex == 8) {
            // set the custom traits to dwarfather
            t = dwarfatherTraits[totalDwarfathers];
            totalDwarfathers++;
        } else {
            t.background_weapon =
                uint16((random(seed) % MAX_TRAITS[0]) << 8) + // background
                uint8(random(seed + 1) % MAX_TRAITS[1]); // weapon
            t.body_outfit =
                uint16((random(seed + 2) % MAX_TRAITS[2]) << 8) + // body
                uint8(random(seed + 3) % MAX_TRAITS[3]); // outfit
            t.head_ears =
                uint16((random(seed + 4) % MAX_TRAITS[4]) << 8) + // head
                uint8(random(seed + 5) % MAX_TRAITS[5]); // ears
            t.mouth_nose =
                uint16((random(seed + 6) % MAX_TRAITS[6]) << 8) + // mouth
                uint8(random(seed + 7) % MAX_TRAITS[7]); // nose
            t.eyes_brows =
                uint16((random(seed + 8) % MAX_TRAITS[8]) << 8) + // eyes
                uint8(random(seed + 9) % MAX_TRAITS[9]); // eyebrows
            t.hair_facialhair =
                uint16((random(seed + 10) % MAX_TRAITS[10]) << 8) + // hair
                uint8(random(seed + 11) % MAX_TRAITS[11]); // facialhair
            t.eyewear = uint8(random(seed + 12) % MAX_TRAITS[12]); // eyewear
        }

        return t;
    }

    /**
     * @dev converts a struct to a 256 bit hash to check for uniqueness
     * @param s the struct to pack into a hash
     * @return the 256 bit hash of the struct
     */
    function getTraitHash(DwarfTrait memory s) internal pure returns (uint256) {
        return
            uint256(
                keccak256(
                    abi.encodePacked(
                        s.background_weapon, // background & weapon
                        s.body_outfit, // body & outfit
                        s.head_ears, // head & ears
                        s.mouth_nose, // mouth & nose
                        s.eyes_brows, // eyes & eyebrows
                        s.hair_facialhair, // hair & facialhair
                        s.eyewear // eyewear
                    )
                )
            );
    }

    /**
     * @dev generates a pseudorandom number
     * @param seed a value ensure different outcomes for different sources in the same block
     * @return a pseudorandom value
     */
    function random(uint256 seed) internal view returns (uint256) {
        return
            uint256(
                keccak256(
                    abi.encodePacked(
                        tx.origin,
                        blockhash(block.number - 1),
                        block.timestamp,
                        seed
                    )
                )
            );
    }

    /** READ */
    /**
     * @dev get the token traits details
     * @param tokenId the token id
     * @return DwarfTrait memory
     */
    function getTokenTraits(uint32 tokenId)
        external
        view
        override
        returns (DwarfTrait memory)
    {
        return mapTokenTraits[tokenId];
    }

    /** ADMIN */

    /**
     * @dev called after deployment so that the contract can get random mobster thieves
     * @param _clan the address of the Clan
     */
    function setClan(address _clan) external onlyOwner {
        clan = IClan(_clan);
    }

    /**
     * allows owner to withdraw funds from minting
     */
    function withdraw() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    /**
     * @dev updates the number of tokens for sale
     * @param _genNumTokens the number of tokens array
     */
    function setGenTokens(uint256[] memory _genNumTokens) external onlyOwner {
        require(
            _genNumTokens.length == MAX_GEN_TOKENS.length,
            "Invalid input parameter"
        );
        for (uint8 i = 0; i < _genNumTokens.length; i++) {
            MAX_GEN_TOKENS[i] = _genNumTokens[i];
        }
    }

    /**
     * @dev set the ETH prices
     * @param _prices the prices array
     */
    function setMintETHPrices(uint256[] memory _prices) external onlyOwner {
        require(
            _prices.length == MINT_ETH_PRICES.length,
            "Invalid input parameter"
        );
        for (uint8 i = 0; i < _prices.length; i++) {
            MINT_ETH_PRICES[i] = _prices[i];
        }
    }

    /**
     * @dev set the GOD prices
     * @param _prices the prices array
     */
    function setMintGODPrices(uint256[] memory _prices) external onlyOwner {
        require(
            _prices.length == MINT_GOD_PRICES.length,
            "Invalid input parameter"
        );
        for (uint8 i = 0; i < _prices.length; i++) {
            MINT_GOD_PRICES[i] = _prices[i];
        }
    }

    /**
     * @dev set the ETH percent
     * @param _percent the percent of ETH
     */
    function setEthSoldPercent(uint16 _percent) external onlyOwner {
        MAX_TOKENS_ETH_SOLD = _percent;
    }

    /**
     * @dev set the traits values
     * @param maxValues the max values of the traits
     */
    function setMaxTraitValues(uint8[] memory maxValues) external onlyOwner {
        require(
            maxValues.length == MAX_TRAITS.length,
            "Invalid input parameter"
        );
        for (uint8 i = 0; i < maxValues.length; i++) {
            MAX_TRAITS[i] = maxValues[i];
        }
    }

    /**
     * @dev set the max dwarfs per city
     * @param maxValues the max dwarfs
     */
    function setMaxDwarfsPerCity(uint16[] memory maxValues) external onlyOwner {
        require(
            maxValues.length == MAX_MOBSTERS_CITY.length,
            "Invalid input parameter"
        );

        remainMobstersOfCity = 0;
        for (uint8 i = 0; i < maxValues.length; i++) {
            MAX_MOBSTERS_CITY[i] = maxValues[i];
            remainMobstersOfCity += MAX_MOBSTERS_CITY[i];
        }
    }

    /**
     * @dev get the max number of dwarfs per city
     * @return the number of dwarfs
     */
    function getMaxDwarfsPerCity() external view returns (uint16[] memory) {
        return MAX_MOBSTERS_CITY;
    }

    /**
     * @dev set the traits of boss
     * @param traits the trait of a boss
     * @param index the boss index
     */
    function setBossTraits(DwarfTrait memory traits, uint16 index)
        external
        onlyOwner
    {
        if (index >= bossTraits.length) {
            bossTraits.push(traits);
        } else {
            bossTraits[index] = traits;
        }
    }

    /**
     * @dev set the traits of dwarfather
     * @param traits the trait of a boss
     * @param index the boss index
     */
    function setDwarfatherTraits(DwarfTrait memory traits, uint16 index)
        external
        onlyOwner
    {
        if (index >= dwarfatherTraits.length) {
            dwarfatherTraits.push(traits);
        } else {
            dwarfatherTraits[index] = traits;
        }
    }

    /**
     * @dev enables owner to pause / unpause minting
     * @param _bPaused the flag to pause / unpause
     */
    function setPaused(bool _bPaused) external onlyOwner {
        if (_bPaused) _pause();
        else _unpause();
    }

    /**
     * @dev Internal function to set the base URI for all token IDs. It is
     * automatically added as a prefix to the value returned in {tokenURI},
     * or to the token ID if {tokenURI} is empty.
     * @param _baseURI the base URI string
     */
    function setBaseURI(string memory _baseURI) external onlyOwner {
        baseURI = _baseURI;
    }

    /**
     * @dev Returns the base URI set via {setBaseURI}. This will be
     * automatically added as a prefix in {tokenURI} to each token's URI, or
     * to the token ID if no specific URI is set for that token ID.
     * @return base URI string
     */
    function getBaseURI() external view override returns (string memory) {
        return baseURI;
    }

    /** RENDER */
    /**
     * @dev Returns the token URI. BaseURI will be
     * automatically added as a prefix in {tokenURI} to each token's URI, or
     * to the token ID if no specific URI is set for that token ID.
     * @param tokenId the token id
     * @return token URI string
     */
    function tokenURI(uint32 tokenId) public view returns (string memory) {
        require(
            _exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );

        return nft_traits.tokenURI(tokenId);
    }
}