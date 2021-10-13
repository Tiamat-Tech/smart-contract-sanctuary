// contracts/MiceForce.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "./IMFMetaVault.sol";
import "./IBrainz.sol";

contract MiceForce is ERC721Enumerable {
    struct Trait {
        string traitName;
        string traitType;
        string pixels;
        uint256 pixelCount;
    }

    //Mappings
    mapping(uint256 => Trait[]) traitTypes;
    mapping(string => bool) hashToMinted;
    mapping(uint256 => string) internal tokenIdToHash;

    //uint256s
    uint256 MAX_SUPPLY = 2500;
    uint giveawayAndTeamMinted;
    uint GIVEAWAY_AND_TEAM_SUPPLY = 500;
    uint256 SEED_NONCE = 0;
    uint256 public BRAINS_MINT_COST=12000000000000000000;

    //uint arrays
    uint16[][8] TIERS;

    //address
    address public _owner;
    address metaVaultAddress;
    address pumpkinJackAddress;
    address brainzAddress;

    constructor() ERC721("MiceForce", "MFORCE") {
        _owner = msg.sender;

        //Declare all the rarity tiers

        //Hat
        TIERS[0] = [17, 49, 66, 99, 131, 164, 197, 296, 394, 1874];
        //Whiskers
        TIERS[1] = [66, 263, 329, 986, 1643];
        //Neck
        TIERS[2] = [99, 263, 296, 329, 2300];
        //Earrings
        TIERS[3] = [16, 66, 99, 99, 3007];
        //Eyes
        TIERS[4] = [17, 34, 131, 148, 164, 230, 592, 657, 657, 657];
        //Mouth
        TIERS[5] = [469, 469, 469, 470, 470, 470, 470];
        //Nose
        TIERS[6] = [657, 658, 657, 658, 657];
        //Character
        TIERS[7] = [7, 23, 237, 329, 380, 394, 427, 471, 507, 512];
    }

    /*
     ______  _            
    |  ___ \(_)      _    
    | | _ | |_ ____ | |_  
    | || || | |  _ \|  _) 
    | || || | | | | | |__ 
    |_||_||_|_|_| |_|\___)       

   */

    /**
     * @dev Converts a digit from 0 - MAX_SUPPLY into its corresponding rarity based on the given rarity tier.
     * @param _randinput The input from 0 - MAX_SUPPLY to use for rarity gen.
     * @param _rarityTier The tier to use.
     */
    function rarityGen(
        uint256 _randinput, 
        uint8 _rarityTier
    )
        internal
        view
        returns (string memory)
    {
        uint16 currentLowerBound = 0;
        for (uint8 i = 0; i < TIERS[_rarityTier].length; i++) {
            uint16 thisPercentage = TIERS[_rarityTier][i];
            if (
                _randinput >= currentLowerBound &&
                _randinput < currentLowerBound + thisPercentage
            ) return _toString(i);
            currentLowerBound = currentLowerBound + thisPercentage;
        }

        revert();
    }

    /**
     * @dev Generates a 9 digit hash from a tokenId, address, and random number.
     * @param _t The token id to be used within the hash.
     * @param _a The address to be used within the hash.
     * @param _c The custom nonce to be used within the hash.
     */
    function hash(
        uint8 _millisci,
        uint256 _t,
        address _a,
        uint256 _c
    ) 
        internal 
        returns (string memory) 
    {
        require(_c < 10);

        // This will generate a 9 character string.
        // The last 8 digits are random, the first is always 0 for normal mice
        string memory currentHash = _toString(_millisci);

        for (uint8 i = 0; i < 8; i++) {
            SEED_NONCE++;
            uint16 _randinput = uint16(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            block.timestamp,
                            block.difficulty,
                            _t,
                            _a,
                            _c,
                            SEED_NONCE
                        )
                    )
                ) % MAX_SUPPLY
            );

            currentHash = string(
                abi.encodePacked(currentHash, rarityGen(_randinput, i))
            );
        }

        if (hashToMinted[currentHash]) return hash(_millisci,_t, _a, _c + 1);

        return currentHash;
    }

    function getPrize(address winner, uint8 amount) external onlyUncleJack {
        uint256 _startMintId = totalSupply();
        require(
            (giveawayAndTeamMinted + amount) <= GIVEAWAY_AND_TEAM_SUPPLY,
            "The amount exceed max supply"
        );

        for (uint i = 0; i < amount; i++) {
            uint8 rand = uint8(uint256(keccak256(abi.encodePacked(winner, amount, block.timestamp, block.difficulty)))%2);
            uint256 _mintId = _startMintId + i;

            tokenIdToHash[_mintId] = hash(rand,_mintId, msg.sender, 0);
            hashToMinted[tokenIdToHash[_mintId]] = true;
            giveawayAndTeamMinted++;
            _mint(msg.sender, _mintId);
        }
        
    }

    function mintMice(uint8 _millisci, uint _num) external {
        require(_millisci<2,"Wrong class chosen");
        uint256 _startMintId = totalSupply();
        require(
            (_startMintId - giveawayAndTeamMinted + _num) <= MAX_SUPPLY,
            "The amount exceed max supply"
        );
        
        IBrainz(brainzAddress).burnFrom(msg.sender, BRAINS_MINT_COST*_num);

        for (uint i = 0; i < _num; i++) {
            uint256 _mintId = _startMintId + i;

            tokenIdToHash[_mintId] = hash(_millisci,_mintId, msg.sender, 0);
            hashToMinted[tokenIdToHash[_mintId]] = true;

            _mint(msg.sender, _mintId);
        }
    }

    /**
     * @dev Mints new token. Available from the Gate contract only.
     */
    function mintMouse(uint8 _millisci) 
        external  
    {
        require(_millisci<2,"Wrong class chosen");
        uint256 _mintId = totalSupply();
        require(_mintId - giveawayAndTeamMinted < MAX_SUPPLY, "No more mice force available");

        IBrainz(brainzAddress).burnFrom(msg.sender, BRAINS_MINT_COST);

        tokenIdToHash[_mintId] = hash(_millisci,_mintId, msg.sender, 0);
        hashToMinted[tokenIdToHash[_mintId]] = true;

        _mint(msg.sender, _mintId);
    }

    /*
     ______                 _     ___                        _                  
    (_____ \               | |   / __)                  _   (_)                 
     _____) ) ____ ____  _ | |  | |__ _   _ ____   ____| |_  _  ___  ____   ___ 
    (_____ ( / _  ) _  |/ || |  |  __) | | |  _ \ / ___)  _)| |/ _ \|  _ \ /___)
        | ( (/ ( ( | ( (_| |  | |  | |_| | | | ( (___| |__| | |_| | | | |___ |
        |_|\____)_||_|\____|  |_|   \____|_| |_|\____)\___)_|\___/|_| |_(___/    

    */

    /**
     * @dev Returns the SVG and metadata for a token Id
     * @param _tokenId The tokenId to return the SVG and metadata for.
     */
    function tokenURI(
        uint256 _tokenId
    )
        public
        view
        override
        returns (string memory)
    {
        require(_exists(_tokenId));
        return IMFMetaVault(metaVaultAddress).getMetadataByHash(_tokenId, tokenIdToHash[_tokenId]);
    }

    /**
     * @dev Returns the wallet of a given wallet. Mainly for ease for frontend devs.
     * @param _wallet The wallet to get the tokens of.
     */
    function walletOfOwner(
        address _wallet
    )
        external
        view
        returns (uint256[] memory)
    {
        uint256 tokenCount = balanceOf(_wallet);

        uint256[] memory tokensId = new uint256[](tokenCount);
        for (uint256 i; i < tokenCount; i++) {
            tokensId[i] = tokenOfOwnerByIndex(_wallet, i);
        }
        return tokensId;
    }

    function setAddress(address _brainzAddress, address _metavaultAddress, address _pumpkinJackAddress) external onlyOwner {
        brainzAddress=_brainzAddress;
        metaVaultAddress=_metavaultAddress;
        pumpkinJackAddress = _pumpkinJackAddress;
    }

    /**
     * @dev Transfers ownership
     * @param _newOwner The new owner
     */
     /*
    function transferOwnership(
        address _newOwner
    ) 
        public 
        onlyOwner 
    {
        _owner = _newOwner;
    }
    */
    //Modifiers

    /**
     * @dev Modifier to only allow owner to call functions
     */
    modifier onlyOwner() {
        require(_owner == msg.sender);
        _;
    }

    // Only uncle Jack can ask for the prizes for zmice fam!
    modifier onlyUncleJack() {
        require(pumpkinJackAddress == msg.sender);
        _;
    }
    
    function _toString(uint256 value) internal pure returns (string memory) 
    {
        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }
}