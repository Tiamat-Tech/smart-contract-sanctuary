// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/MerkleProofUpgradeable.sol";
import "hardhat/console.sol";
import "../Booty.sol";
import "../Errors.sol";
import "./PirateMetadataBuilder.sol";
import "../Random.sol";
import "./TraitSet.sol";

contract Pirate is
    Initializable,
    ERC721Upgradeable,
    ERC721EnumerableUpgradeable,
    PausableUpgradeable,
    OwnableUpgradeable,
    UUPSUpgradeable
{
    using AddressUpgradeable for address payable;
    using CountersUpgradeable for CountersUpgradeable.Counter;

    struct Stake {
        address owner;
        uint64 timestamp;
    }

    struct WeightSet {
        uint112 beard; // Slot 1
        uint112 femaleBody;
        uint32 gender;
        uint176 femaleHat; // Slot 2
        uint80 wing;
        uint96 hairColor; // Slot 3
        uint128 special;
        uint32 unique;
        uint128 maleBody; // Slot 4
        uint128 maleHairs;
        uint256 maleClothing; // Slot 5
        uint240 maleFace; // Slot 6
        uint240 maleHat; // Slot 7
        uint144 femaleClothing; // Slot 8
        uint96 femaleFace;
        uint48 femaleHairs; // Slot 9
    }

    uint16 private _maxSupply;
    uint8 private _totalUniqueSupply;
    uint64 private _mintLaunchDate;
    uint256 private _mintPrice;
    uint256 private _nonce;

    bytes32 private _merkleRoot;

    mapping(uint256 => Stake) private _stakes;
    mapping(uint256 => TraitSet) private _traits;
    mapping(uint256 => bool) private _traitHashes;

    Booty private _booty;
    PirateMetadataBuilder private _metadataBuilder;
    CountersUpgradeable.Counter private _tokenIdCounter;
    WeightSet private _weightPool;

    modifier noContract() {
        address account = _msgSender();
        uint256 size;

        assembly {
            size := extcodesize(account)
        }

        if (size != 0 || account != tx.origin) {
            revert ContractAccountNotAllowed();
        }

        _;

        _nonce = uint256(keccak256(abi.encodePacked(block.timestamp, account, _nonce)));
    }

    function initialize(
        uint16 maxSupply,
        uint256 mintPrice,
        uint64 mintLaunchDate
    ) public initializer {
        __ERC721_init("Pirate", "PIRAT");
        __ERC721Enumerable_init();
        __Pausable_init();
        __Ownable_init();
        __UUPSUpgradeable_init();

        _maxSupply = maxSupply;
        _mintLaunchDate = mintLaunchDate;
        _mintPrice = mintPrice;
        _nonce = uint256(keccak256(abi.encodePacked(block.timestamp, _msgSender())));

        // Beard enum
        _weightPool.beard = 0x05dc_007d0_07d0_07d0_044c_044c_012c;
        // FemaleBody enum
        _weightPool.femaleBody = 0x09c4_09c4_09c4_0320_0320_02ee_0096;
        // FemaleClothing enum
        _weightPool.femaleClothing = 0x0898_0898_0898_0898_012c_012c_012c_0096_0096;
        // FemaleFace enum
        _weightPool.femaleFace = 0x0a8c_07d0_07d0_07d0_03e8_012c;
        // FemaleHairs enum
        _weightPool.femaleHairs = 0x1194_1194_03e8;
        // FemaleHat enum
        _weightPool.femaleHat = 0x05dc_04b0_04b0_04b0_04b0_04b0_015e_015e_012c_0096_0096;
        // Gender enum
        _weightPool.gender = 0x2134_05dc;
        // HairColor enum
        _weightPool.hairColor = 0x09c4_09c4_09c4_044c_044c_012c;
        // MaleBody enum
        _weightPool.maleBody = 0x09c4_09c4_09c4_02ee_02ee_02bc_0096_0096;
        // MaleClothing enum
        _weightPool.maleClothing = 0x0578_0578_0578_0578_0578_0578_0118_0118_0118_0104_0064_0064_0064_0064_0032_0032;
        // MaleFace enum
        _weightPool.maleFace = 0x1770_01f4_01f4_01f4_01f4_01f4_01f4_00e1_00e1_00e1_00e1_0019_0019_0019_0019;
        // MaleHairs enum
        _weightPool.maleHairs = 0x05dc_07d0_07d0_07d0_044c_044c_0096_0096;
        // MaleHat enum
        _weightPool.maleHat = 0x03e8_03e8_03e8_03e8_03e8_03e8_03e8_03e8_0154_0154_0154_0154_0154_0096_0096;
        // Special enum
        _weightPool.special = 0x22c4_00fa_00fa_00fa_00fa_0022_0022_0020;
        // Unique enum
        _weightPool.unique = 0x2690_0080;
        // Wing enum
        _weightPool.wing = 0x2328_012c_012c_012c_0064;
    }

    function mint(address to, uint256 amount) external payable whenNotPaused noContract {
        if (_mintLaunchDate >= block.timestamp) {
            revert MintingNotLaunched();
        }

        if (amount < 1 || amount > 5) {
            revert OutOfRange(1, 5);
        }

        if (amount + _tokenIdCounter.current() > _maxSupply) {
            revert SoldOut();
        }

        _mintCore(to, amount);
    }

    function mintWhitelist(
        address to,
        uint256 amount,
        bytes32[] calldata proof
    ) external payable whenNotPaused noContract {
        if (_mintLaunchDate - 1 days >= block.timestamp) {
            revert MintingNotLaunched();
        }

        if (amount < 1 || amount > 2) {
            revert OutOfRange(1, 2);
        }

        if (!MerkleProofUpgradeable.verify(proof, _merkleRoot, keccak256(abi.encodePacked(to)))) {
            revert InvalidProof();
        }

        if (balanceOf(to) >= 2) {
            revert WhitelistLimitExceeded();
        }

        _mintCore(to, amount);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function reclaim(uint256[] calldata tokenIds) external whenNotPaused noContract {
        uint256 amount;

        for (uint256 i; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];

            if (_msgSender() != _stakes[tokenId].owner) {
                revert Unauthorized();
            }

            amount += bootyFor(tokenId);

            _transfer(address(this), _msgSender(), tokenId);

            delete _stakes[tokenId];
        }

        _booty.mint(_msgSender(), amount);
    }

    function setBooty(address address_) external onlyOwner {
        _booty = Booty(address_);
    }

    function setMerkleRoot(bytes32 value) external onlyOwner {
        _merkleRoot = value;
    }

    function setMetadataBuilder(address address_) external onlyOwner {
        _metadataBuilder = PirateMetadataBuilder(address_);
    }

    function setMintLaunchDate(uint64 time) external onlyOwner {
        _mintLaunchDate = time;
    }

    function stake(uint256[] calldata tokenIds) external whenNotPaused noContract {
        for (uint256 i; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];

            if (_msgSender() != ownerOf(tokenId)) {
                revert Unauthorized();
            }

            _transfer(_msgSender(), address(this), tokenId);

            // solhint-disable-next-line not-rely-on-time
            _stakes[tokenId] = Stake({owner: _msgSender(), timestamp: uint64(block.timestamp)});
        }
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function withdrawBooty(uint256[] calldata tokenIds) external whenNotPaused noContract {
        uint256 amount;

        for (uint256 i; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];

            if (_msgSender() != _stakes[tokenId].owner) {
                revert Unauthorized();
            }

            amount += bootyFor(tokenId);

            // solhint-disable-next-line not-rely-on-time
            _stakes[tokenId].timestamp = uint64(block.timestamp);
        }

        _booty.mint(_msgSender(), amount);
    }

    function withdrawIncome() external onlyOwner {
        payable(_msgSender()).sendValue(address(this).balance);
    }

    function withdrawIncome(address payable to) external onlyOwner {
        to.sendValue(address(this).balance);
    }

    function bootyFor(uint256 tokenId) public view returns (uint256) {
        if (_stakes[tokenId].timestamp == 0) {
            return 0;
        }

        // solhint-disable-next-line not-rely-on-time
        return ((block.timestamp - _stakes[tokenId].timestamp) * 1 ether) / 1 days;
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        TraitSet memory traits = _traits[tokenId];

        return _metadataBuilder.build(tokenId, traits);
    }

    // solhint-disable-next-line no-empty-blocks
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override(ERC721Upgradeable, ERC721EnumerableUpgradeable) whenNotPaused {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function _mintCore(address to, uint256 amount) private {
        if (_msgSender() != owner() && msg.value < _mintPrice * amount) {
            revert InsufficientFunds();
        }

        uint256 t;
        uint256 tokenId;
        TraitSet memory traits;

        for (uint256 i; i < amount; i++) {
            _tokenIdCounter.increment();

            uint256 hash_;
            tokenId = _tokenIdCounter.current();
            t = tokenId;

            do {
                t = uint256(keccak256(abi.encodePacked(t, _nonce)));

                traits = _randomTraits(t);

                if (traits.unique == Unique.None) {
                    hash_ = uint256(
                        keccak256(
                            abi.encodePacked(
                                traits.beard,
                                traits.body,
                                traits.clothing,
                                traits.face,
                                traits.gender,
                                traits.hairColor,
                                traits.hairs,
                                traits.hat,
                                traits.special,
                                traits.wing
                            )
                        )
                    );
                }
            } while (_traitHashes[hash_]);

            if (traits.unique == Unique.None) {
                _traitHashes[hash_] = true;
            } else {
                _totalUniqueSupply++;
            }

            _traits[tokenId] = traits;

            _safeMint(to, tokenId);
        }
    }

    function _randomTraits(uint256 seed) private view returns (TraitSet memory) {
        TraitSet memory traits;

        uint256 unique = _tokenIdCounter.current() / (_maxSupply / 11);

        if ((unique + 1 > _totalUniqueSupply && _totalUniqueSupply < 11)) {
            bool isUnique;

            if (unique == _totalUniqueSupply + 1) {
                isUnique = true;
                unique--;
            } else {
                isUnique = Random.weighted(_weightPool.unique, 2, seed++) == 1;
            }

            if (isUnique) {
                traits.unique = Unique(unique + 1);

                return traits;
            }
        }

        traits.gender = Gender(Random.weighted(_weightPool.gender, 2, seed++));

        if (traits.gender == Gender.Male) {
            Special special = Special(Random.weighted(_weightPool.special, 8, seed++));
            traits.special = special;

            // No body and wings if skeleton
            if (special != Special.Skeleton) {
                traits.body = uint8(Random.weighted(_weightPool.maleBody, 8, seed++) + 1);
                traits.wing = Wing(Random.weighted(_weightPool.wing, 5, seed++));
            }

            MaleFace face = MaleFace(Random.weighted(_weightPool.maleFace, 15, seed++));

            // Clothing if not special
            if (special == Special.None) {
                traits.clothing = uint8(Random.weighted(_weightPool.maleClothing, 16, seed++));
            }
            // Compatible faces only if special
            else {
                MaleFace[5] memory faces = [
                    MaleFace.None,
                    MaleFace.MechanicShades,
                    MaleFace.BlueGoggles,
                    MaleFace.PurpleGoggles,
                    MaleFace.Monocle
                ];
                bool keepFace = false;

                for (uint256 i; i < faces.length; i++) {
                    if (face == faces[i]) {
                        keepFace = true;
                        break;
                    }
                }

                if (keepFace) {
                    traits.face = uint8(face);
                } else {
                    face = MaleFace.None;
                }
            }

            // No hat and hairs if samurai helmet or special knight/ninja
            if (face != MaleFace.SamuraiHelmet && (special == Special.None || special == Special.Skeleton)) {
                MaleHat hat = MaleHat(Random.weighted(_weightPool.maleHat, 15, seed++));
                traits.hat = uint8(hat);

                // No hairs if special
                if (special == Special.None) {
                    // No hairs if crown hat
                    if (hat != MaleHat.Crown && hat != MaleHat.RoyalCrown) {
                        if (
                            (face >= MaleFace.BoneSkullMask && face <= MaleFace.SurgicalMask) ||
                            face == MaleFace.OniMask ||
                            face == MaleFace.GoldSkullMask
                        ) {
                            // Drop the last 2 items (words)
                            traits.hairs = uint8(Random.weighted(_weightPool.maleHairs >> 32, 6, seed++));
                        } else {
                            traits.hairs = uint8(Random.weighted(_weightPool.maleHairs, 8, seed++));
                        }
                    }

                    // Beard only if no face
                    if (face == MaleFace.None) {
                        traits.beard = Beard(Random.weighted(_weightPool.beard, 7, seed++));
                    }
                }
            }

            // Set hair color only if has either hairs or beard
            if (MaleHairs(traits.hairs) != MaleHairs.None || traits.beard != Beard.None) {
                traits.hairColor = HairColor(Random.weighted(_weightPool.hairColor, 6, seed++) + 1);
            }
        } else if (traits.gender == Gender.Female) {
            traits.body = uint8(Random.weighted(_weightPool.femaleBody, 7, seed++));
            traits.clothing = uint8(Random.weighted(_weightPool.femaleClothing, 9, seed++));
            traits.face = uint8(Random.weighted(_weightPool.femaleFace, 6, seed++));
            traits.hairColor = HairColor(Random.weighted(_weightPool.hairColor, 6, seed++) + 1);
            traits.hairs = uint8(Random.weighted(_weightPool.femaleHairs, 3, seed++));
            traits.hat = uint8(Random.weighted(_weightPool.femaleHat, 11, seed++));
            traits.wing = Wing(Random.weighted(_weightPool.wing, 5, seed++));
        }

        return traits;
    }
}