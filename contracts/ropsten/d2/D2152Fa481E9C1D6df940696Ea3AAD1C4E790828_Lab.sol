pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

import "./FlorToken.sol";
import "./EvaPerfumes.sol";
import "./EvaFlowers.sol";
import "./Chemist.sol";
import "./Store.sol";

contract Lab is Ownable, IERC721Receiver, Pausable {
    uint256 public totalFlowerStaked;
    uint256 public totalPerfumesStaked;
    uint256 public constant MINT_WITH_STAKE_PRICE = .0005 ether; //TBD
    uint256 public constant MINT_WITHOUT_STAKE_PRICE = .0004 ether; //TBD
    uint256 public MAX_MINTABLE_TOKENS = 44500; //Max mintable FLOWERS+STORES+PERFUMES
    uint256 public GENESIS_TOKENS = 10000; //Genesis tokens consist of 1k perfume and 9k flowers
    uint256 public MAX_FLOWERS = 40000; //mAX MINTABLE FLOWERS
    uint256 public MAX_PERFUMES = 4000; //MAX MINTABLE PERFUMES
    uint256 public MAX_MINT_STORE = 500; //1% chance to get one of these stores on generation 1-5 mints
    uint256 public MAX_INITIAL_PERFUMES = 1000;
    uint256 public MAX_INITIAL_FLOWERS = 9000;
    uint256 public MAX_MANUFACTURED_PERFUMES = 5000; //Perfumes minted after burning a collection of flowers with the exact total of 100cc
    uint256 public MINTED_TOKENS;
    uint256 public MINTED_FLOWERS;
    uint256 public MINTED_STORES;
    uint256 public MINTED_PERFUMES;
    uint256 public MANUFACTURED_PERFUMES;
    uint256 public BUILT_STORES; //stores minted after burning perfumes

    struct StakedPerfum {
        uint256 tokenId;
        uint256 timeStamp;
        address owner;
    }
    struct StakedFlower {
        uint256 tokenId;
        uint256 timeStamp;
        address owner;
    }
    struct userInfo {
        address account;
        uint256 stakedPerfumes;
        uint256 stakedFlowers;
        uint256 manufacturedPerfumes;
    }

    mapping(uint256 => StakedPerfum) public StakedPerfumes;
    mapping(uint256 => StakedFlower) public StakedFlowers;
    mapping(address => userInfo) public Users;
    uint256 public florPerDay = 6000 ether; //FLOR per day for flower

    FLOR public flor;
    EvaFlowers public flower;
    EvaChemist public chemist;
    EvaPerfumes public perfume;
    EvaStore public store;

    uint256 public florDueToPerfumHolders;
    event TokenStaked(address owner, uint256 tokenId, uint256 value);

    constructor(
        address _flor,
        address _chemist,
        address _perfume,
        address _flower,
        address _store
    ) {
        flor = FLOR(_flor);
        chemist = EvaChemist(_chemist);
        perfume = EvaPerfumes(_perfume);
        flower = EvaFlowers(_flower);
        store = EvaStore(_store);
    }

    function mint(uint256 amount, bool stakeTokens)
        public
        payable
        whenNotPaused
    {
        require(tx.origin == msg.sender, "Only EOA");
        require(MINTED_TOKENS + amount <= MAX_MINTABLE_TOKENS, "Mint ended");

        if (MINTED_TOKENS < GENESIS_TOKENS) {
            require(
                MINTED_TOKENS + amount <= GENESIS_TOKENS,
                "All tokens on-sale already sold"
            );

            if (msg.sender == owner()) {
                require(msg.value == 0);
            } else {
                if (stakeTokens) {
                    require(
                        amount * MINT_WITH_STAKE_PRICE == msg.value,
                        "Invalid amount"
                    );
                } else {
                    require(
                        amount * MINT_WITHOUT_STAKE_PRICE == msg.value,
                        "Invalid amount"
                    );
                }
            }

            _mintGenesisTokens(amount, stakeTokens);
        } else {
            _mintGenerationTokens(amount, stakeTokens);
        }
    }

    function _mintGenerationTokens(uint256 _amount, bool _stake) internal {
        uint256 totalFlorCost = 0;

        for (uint256 i = 0; i < _amount; i++) {
            uint256 luckyNumber = randomNum(100, i);
            if (
                (luckyNumber < 90 && MAX_FLOWERS > MINTED_FLOWERS) ||
                (MAX_PERFUMES == MINTED_PERFUMES &&
                    MAX_FLOWERS > MINTED_FLOWERS)
            ) {
                if (_stake) {
                    flower.mint(address(this));
                    _stakeFlower(msg.sender, MINTED_FLOWERS);
                } else {
                    flower.mint(msg.sender);
                }
                MINTED_FLOWERS++;
            }
            if (
                (luckyNumber >= 90 &&
                    luckyNumber < 99 &&
                    MAX_PERFUMES > MINTED_PERFUMES) ||
                (MAX_FLOWERS == MINTED_FLOWERS &&
                    MAX_PERFUMES > MINTED_PERFUMES)
            ) {
                if (_stake) {
                    perfume.mint(address(this), false, 0);
                    _stakePerfume(msg.sender, MINTED_PERFUMES);
                } else {
                    perfume.mint(msg.sender, false, 0);
                }
                MINTED_PERFUMES++;
            }

            if (
                luckyNumber == 99 ||
                (MAX_PERFUMES == MINTED_PERFUMES &&
                    MAX_FLOWERS == MINTED_FLOWERS &&
                    MINTED_STORES < MAX_MINT_STORE)
            ) {
                store.mint(msg.sender);
                MINTED_STORES++;
            }

            totalFlorCost += mintCost(MINTED_TOKENS);
            MINTED_TOKENS++;
        }

        flor.burn(msg.sender, totalFlorCost);
    }

    /*

     * Mints genesis tokens
     * If user decides to stake tokens are directly minted to the lab contract

     */

    function _mintGenesisTokens(uint256 _amount, bool _stake) internal {
        for (uint256 i = 0; i < _amount; i++) {
            uint256 luckyNumber = randomNum(10, i);
            if (
                (luckyNumber == 1 && MINTED_PERFUMES < MAX_INITIAL_PERFUMES) ||
                (MINTED_FLOWERS == MAX_INITIAL_FLOWERS &&
                    MINTED_PERFUMES < MAX_INITIAL_PERFUMES)
            ) {
                if (_stake) {
                    perfume.mint(address(this), false, 0);

                    _stakePerfume(msg.sender, MINTED_PERFUMES);
                } else {
                    perfume.mint(msg.sender, false, 0);
                }
                MINTED_PERFUMES++;
            }

            if (
                (luckyNumber != 1 && MINTED_FLOWERS < MAX_INITIAL_FLOWERS) ||
                (MINTED_PERFUMES == MAX_INITIAL_PERFUMES &&
                    MINTED_FLOWERS < MAX_INITIAL_FLOWERS)
            ) {
                if (_stake) {
                    flower.mint(address(this));

                    _stakeFlower(msg.sender, MINTED_FLOWERS);
                } else {
                    flower.mint(msg.sender);
                }
                MINTED_FLOWERS++;
            }

            MINTED_TOKENS++;
        }
    }

    /*
    Function called to mint a new Store
    *Burns 100k FLOR 
    *Burns 5 perfumes
    *Mints a new Store
    */

    function buildStore(uint256[] calldata tokenIds) public {
        require(tokenIds.length == 5, "You need 5 perfumes");
        require(BUILT_STORES < 500, "Build ended"); //Max stores to be built is 500

        flor.burn(_msgSender(), 100000 ether); //A store costs 100 000 FLOR to be minted
        perfume.burnBatchPerfumes(tokenIds);
        store.mint(msg.sender);
        BUILT_STORES++;
    }

    /*
    Function called to mint a new chemist
    *Burns 50k FLOR 
    *Mints a new chemist
    */
    function mintChemist() public {
        flor.burn(_msgSender(), 50000 ether); //A Chemist costs 50 000 FLOR to be minted

        chemist.mint(msg.sender);
    }

    /*

    @Dev 
    *Calculates the mint cost depending on the token generation 

    */
    function mintCost(uint256 tokenId) public view returns (uint256) {
        if (tokenId <= 15000 && tokenId >= GENESIS_TOKENS) return 20000 ether; //Generation #1
        if (tokenId <= 20000 && tokenId > 15000) return 25000 ether; //Generation #2
        if (tokenId <= 30000 && tokenId > 20000) return 30000 ether; //Generation #3
        if (tokenId <= 40000 && tokenId > 30000) return 35000 ether; //Generation #4
        if (tokenId <= 44500 && tokenId > 40000) return 40000 ether; //Generation #5
        return 80000 ether; //@TODO: to be decided
    }

    /*

    @Dev 
    Allows players to stake their flowers and perfumes in batch
    @args address of player/holder of tokens 
    @args Array of token ids
    @args type of tokens: flowers or perfumes

    */

    function stake(
        address owner,
        uint256[] calldata tokenIds,
        bool areFlowers
    ) public whenNotPaused {
        if (areFlowers) {
            for (uint256 i = 0; i < tokenIds.length; i++) {
                flower.safeTransferFrom(owner, address(this), tokenIds[i]);
                _stakeFlower(owner, tokenIds[i]);
            }
        } else {
            for (uint256 i = 0; i < tokenIds.length; i++) {
                perfume.safeTransferFrom(owner, address(this), tokenIds[i]);
                _stakePerfume(owner, tokenIds[i]);
            }
        }
    }

    /*

    @Dev 
    Allows players to manufacture their own perfume after staking a decent amount of flowers 
    @args Array of token ids
    */

    function makePerfume(uint256[] calldata tokenIds) public {
        require(
            MANUFACTURED_PERFUMES < MAX_MANUFACTURED_PERFUMES,
            "Making of perfumes ended"
        );
        uint256 totalCC;
        uint256 upgradedCC;
        uint256 life = chemist._getChemistLife(msg.sender); //gets the remaining utility of chemist
        uint256[] memory flowerTraits = new uint256[](tokenIds.length);

        for (uint256 i = 0; i < tokenIds.length; i++) {
            require(
                StakedFlowers[tokenIds[i]].owner == _msgSender(),
                "NOT OWNER"
            );
            totalCC += flower.getFlowerCC(tokenIds[i]); //gets the number of cc that the flower holds
            flowerTraits[i] = flower.getFlowerTraitIndex(tokenIds[i]); //gets the index of the flower trait(ranges from 0-5)
        }

        uint256 traitIndex = getTraitIndex(flowerTraits); //If the input is 8 traits (5 boisés, 3 Floral) the returned trait is: boisés.

        if (totalCC == 100) {
            _mintPerfume(msg.sender, traitIndex); //mints perfume with the most reccurent trait
            flower.burnBatchFlowers(tokenIds); //burns the player's flowers
        }

        if (totalCC != 100 && life > 0) {
            uint256 boostValue = chemist._getChemistBoostValue(msg.sender); //gets chemist boost value
            string memory operator = chemist._getChemistOperator(msg.sender); //gets the chemist operator +/-

            if (
                keccak256(abi.encodePacked((operator))) ==
                keccak256(abi.encodePacked(("+")))
            ) {
                upgradedCC = totalCC + boostValue;
            } else {
                upgradedCC = totalCC - boostValue;
            }

            if (upgradedCC == 100) {
                _mintPerfume(msg.sender, traitIndex);
                flower.burnBatchFlowers(tokenIds);
            } else {
                flower.burnExtraFlower(tokenIds[tokenIds.length - 1]); //Even when you use the chmist and you don't get the exact amount of 100cc you lose your flower!
            }
        }
        if (totalCC != 100 && life == 0) {
            flower.burnExtraFlower(tokenIds[tokenIds.length - 1]); //burn last flower if total cc is different than 100 and user has no chemist insurance
        }
    }

    function _mintPerfume(address _owner, uint256 traitIndex) internal {
        perfume.mint(_owner, true, traitIndex); //mint new perfume with known trait to player
        chemist._updateChemist(_owner); //Decreases number of utility of the chemist
        MANUFACTURED_PERFUMES++; //controle the number of manufactured perfumes which has a limit of 5000
    }

    function _stakePerfume(address account, uint256 tokenId) internal {
        StakedPerfum memory newStaking = StakedPerfum(
            tokenId,
            block.timestamp,
            account
        );
        StakedPerfumes[tokenId] = newStaking;
        Users[msg.sender].stakedPerfumes++;

        emit TokenStaked(account, tokenId, block.timestamp);
    }

    function _stakeFlower(address account, uint256 tokenId) internal {
        StakedFlower memory newStaking = StakedFlower(
            tokenId,
            block.timestamp,
            account
        );
        StakedFlowers[tokenId] = newStaking;
        Users[msg.sender].stakedFlowers++;

        emit TokenStaked(account, tokenId, block.timestamp);
    }

    function claimFlowersFlor(uint256[] calldata tokenIds) public {
        uint256 claimAmount;

        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];
            require(
                StakedFlowers[tokenIds[i]].owner == _msgSender(),
                "NOT OWNER"
            );

            claimAmount +=
                ((block.timestamp - StakedFlowers[tokenId].timeStamp) *
                    florPerDay) /
                1 days;
            StakedFlowers[tokenId].timeStamp = block.timestamp;
        }
        florDueToPerfumHolders += (claimAmount * 2) / 10; // The 20% of total flor claimed goes to perfume holders
        flor.mint(_msgSender(), (claimAmount * 8) / 10); //20% of due Flor goes to Perfume holders
    }

    /*
    @Dev Calling this function allows the user to claim his due Flor that comes from the 20% tax on each flower claiming
    *The amount to be minted depends on the numbe rof the perfumes he staked, if he has staked 50% of all the staked perfumes he gets 50% of all Flor collected from taxes
    */
    function claimFlorForPerfumeHolders() public {
        uint256 userPerfumes = Users[msg.sender].stakedPerfumes;
        uint256 dueAmount = (florDueToPerfumHolders * userPerfumes) /
            totalPerfumesStaked;
        florDueToPerfumHolders -= dueAmount;

        flor.mint(_msgSender(), dueAmount);
    }

    function unstakeFlowers(uint256[] calldata tokenIds) public {
        uint256 dueFlorAmount;

        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];

            require(StakedFlowers[tokenId].owner == _msgSender(), "NOT OWNER"); // the msg sender is the owner of the staked token
            require(
                StakedFlowers[tokenId].timeStamp + 4 days > block.timestamp, //4 * 6000 Flor = 24000 Flor is needed to unstake the flower
                "NOT READY FOR PICKING"
            );

            dueFlorAmount +=
                ((block.timestamp - StakedFlowers[tokenId].timeStamp) *
                    florPerDay) /
                1 days;
            flower.safeTransferFrom(address(this), _msgSender(), tokenId);
            delete StakedFlowers[tokenId];
            totalFlowerStaked -= 1;
        }
        //50% chance to lose your flor when unstaking flowers
        if (randomNum(2, dueFlorAmount) == 1) {
            flor.mint(_msgSender(), (dueFlorAmount * 8) / 10); //Tax of 20% applies for Flor claiming
            florDueToPerfumHolders += (dueFlorAmount * 2) / 10; //Credits perfume holders due amount with 20% tax
        } else {
            florDueToPerfumHolders += dueFlorAmount; //sends all Flor to perfume holders
        }
    }

    /*
    @Dev When unstaking perfumes player gets his perfumes and the due amount of Flor collected from staked flowers
    

    */

    function unstakePerfumes(uint256[] calldata tokenIds) public {
        uint256 dueFlorAmount;

        claimFlorForPerfumeHolders(); //claim taxed flowers FLOR if player didn't claim it
        for (uint256 i = 0; i < tokenIds.length; i++) {
            require(
                StakedPerfumes[tokenIds[i]].owner == _msgSender(),
                "NOT OWNER"
            );

            perfume.safeTransferFrom(address(this), _msgSender(), tokenIds[i]);
            dueFlorAmount +=
                ((block.timestamp - StakedPerfumes[tokenIds[i]].timeStamp) *
                    florPerDay) /
                1 days;
            delete StakedPerfumes[tokenIds[i]];
            totalPerfumesStaked -= 1;
        }
        flor.mint(_msgSender(), dueFlorAmount);
    }

    /*
     * generates a pseudorandom number
     * @param seed a value ensure different outcomes for different sources in the same block
     * @return a pseudorandom value
     */
    function randomNum(uint256 _mod, uint256 _seed)
        public
        view
        returns (uint256)
    {
        uint256 num = uint256(
            keccak256(
                abi.encodePacked(
                    block.timestamp,
                    msg.sender,
                    block.number,
                    _seed
                )
            )
        ) % _mod;
        return num;
    }

    /*
    @dev
    Gets the most frequent element of an array
    @args traits of flowers to be burned
    returns the trait index of the perfume to be minted
    */

    function getTraitIndex(uint256[] memory array)
        public
        pure
        returns (uint256)
    {
        uint256[] memory freq = new uint256[](6); //6: number of flowers traits
        uint256 id;
        uint256 maxIndex = 0;
        uint256 maxFrequence;

        for (uint256 i = 0; i < array.length; i += 1) {
            id = array[i];
            freq[id] = freq[id] + 1;
        }

        for (uint256 i = 0; i < 6; i += 1) {
            if (maxFrequence < freq[i]) {
                maxIndex = i;
                maxFrequence = freq[i];
            }
        }

        return maxIndex;
    }

    function onERC721Received(
        address,
        address from,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        require(from == address(0x0), "Cannot send tokens to lab directly");
        return IERC721Receiver.onERC721Received.selector;
    }

    function withdraw() public payable onlyOwner {
        (bool os, ) = payable(owner()).call{value: address(this).balance}("");
        require(os);
    }
}