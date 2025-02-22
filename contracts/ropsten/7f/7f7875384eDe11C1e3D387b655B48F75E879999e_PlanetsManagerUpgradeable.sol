// SPDX-License-Identifier: UNLICENSED
/*
 *
 * @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
 * @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
 * @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
 * @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
 * @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
 * @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@,@@@@@@@@@@@@@@@@@@@@@@@             %@@@@@@@@@@@@
 * @@@@@@@@@@@@@@@@@@@@@@@@@@@,,,,,,,@@@@@@@@@@@@@                        @@@@@@@@@
 * @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@,@@@@@@@@@@@           @@@@@@@@@@@@@@      @@@@@@@
 * @@@@@@@@@@@@@@   @@@@@@@@@@@@@@@@@@@@/         @@@@@@@@@@@@@@@@@@@@@@    @@@@@@@
 * @@@@@@@@@@@&       @@@@@@@@@@@@@@@        @@@@@@@@@@@@@@@@@@@@@@@@@@@     @@@@@@
 * @@@@@@@@@@           @@@@@@@@@/       @@@@@@@@@@            @@@@@@@@@    @@@@@@@
 * @@@@@@@@@@@@@@   @@@@@@@@@@,       @@@@@@@@*         (@     @@@@@@@@     @@@@@@@
 * @@@@@@@@@@@@@@@ @@@@@@@@@      #@@@@@@@@        @@@@@@     @@@@@@@@     @@@@@@@@
 * @@@@@@@@@@@@@@@@@@@@@@       @@@@@@@@@@@    @@@@@@@@      @@@@@@@@     @@@@@@@@@
 * @@@@@@@@@@@@@@@@@@@@      @@@@@.    @@@@@@@@@@@@@@      @@@@@@@@@     @@@@@@@@@@
 * @@@@@@@@@@@@@@@@@@      @@@@@@       *@@@@@@@@@@      @@@@@@@@@     #@@@@@@@@@@@
 * @@@@@@@@@@@@@@@@     %@@@@@@@@@      @@@@@@@@@      @@@@@@@@@@@    @@@@@@@@@@@@@
 * @@@@@@@@@@@@@@     #@@@@@@@@@@@@@@@@@@@@@@@      &@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
 * @@@@@@@@@@@@      @@@@@@     @@@@@@@@@@@       @@@@@@        &@@@@@@@@@@@@@@@@@@
 * @@@@@@@@@@@     @@@@@@      @@@@@@@@        @@@@@@@            @@@@@@@@@@@@@@@@@
 * @@@@@@@@@@     @@@@@@     @@@@@@&        @@@@@@@@@@            @@@@@@@@@@@@@@@@@
 * @@@@@@@@@    ,@@@@@@    %@@@         @@@@@@@@@@@@@@@          @@@@@@@@@@@@@@@@@@
 * @@@@@@@@     @@@@@@@             @@@@@@@@@@@@@  @@@@@@@@  ,@@@@@@@@@@@@@@@@@@@@@
 * @@@@@@@,    @@@@@@@@@@     @@@@@@@@@@@@@@@,      @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
 * @@@@@@@     @@@@@@@@@@@@@@@@@@@@@@@@@@/        @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
 * @@@@@@@@    @@@@@@@@@@@@@@@@@@@@@@         @@@@@@@ @@@@@@@@@@@@@@@@@@@@@@@@@@@@@
 * @@@@@@@@,     @@@@@@@@@@@@@#           @@@@@@@@       @@@@@@@@@@@@@@@@@@@@@@@@@@
 * @@@@@@@@@@                       [email protected]@@@@@@@@@@@@@@@ @@@@@@@@@@@@@@@@@@@@@@@@@@@@@
 * @@@@@@@@@@@@@@            @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
 * @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
 * @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
 * @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
 *
 *    Web:     https://univ.money
 */

pragma solidity ^0.8.11;

// Optimizations:
// - Cleaner code, uses modifiers instead of repetitive code
// - Properly isolated contracts
// - Uses external instead of public (less gas)
// - Add liquidity once instead of dumping coins constantly (less gas)
// - Accept any amount for node, not just round numbers
// - Safer, using reetrancy protection and more logical-thinking code

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./OwnerRecoveryUpgradeable.sol";
import "./UniverseImplementationPointerUpgradeable.sol";
import "./LiquidityPoolManagerImplementationPointerUpgradeable.sol";

contract PlanetsManagerUpgradeable is
    Initializable,
    ERC721Upgradeable,
    ERC721EnumerableUpgradeable,
    ERC721URIStorageUpgradeable,
    PausableUpgradeable,
    OwnableUpgradeable,
    OwnerRecoveryUpgradeable,
    ReentrancyGuardUpgradeable,
    UniverseImplementationPointerUpgradeable,
    LiquidityPoolManagerImplementationPointerUpgradeable
{
    using CountersUpgradeable for CountersUpgradeable.Counter;

    struct PlanetInfoEntity {
        PlanetEntity planet;
        uint256 id;
        uint256 pendingRewards;
        uint256 rewardPerDay;
        uint256 compoundDelay;
    }

    struct PlanetEntity {
        uint256 id;
        string name;
        uint256 creationTime;
        uint256 lastProcessingTimestamp;
        uint256 rewardMult;
        uint256 planetValue;
        uint256 totalClaimed;
        bool exists;
    }

    struct TierStorage {
        uint256 rewardMult;
        uint256 amountLockedInTier;
        bool exists;
    }

    CountersUpgradeable.Counter private _planetCounter;
    mapping(uint256 => PlanetEntity) private _planets;
    mapping(uint256 => TierStorage) private _tierTracking;
    uint256[] _tiersTracked;

    uint256 public rewardPerDay;
    uint256 public creationMinPrice;
    uint256 public compoundDelay;
    uint256 public processingFee;

    uint24[6] public tierLevel;
    uint16[6] public tierSlope;

    uint256 private constant ONE_DAY = 86400;
    uint256 public totalValueLocked;

    modifier onlyPlanetOwner() {
        address sender = _msgSender();
        require(
            sender != address(0),
            "Planets: Cannot be from the zero address"
        );
        require(
            isOwnerOfPlanets(sender),
            "Planets: No Planet owned by this account"
        );
        require(
            !liquidityPoolManager.isFeeReceiver(sender),
            "Planets: Fee receivers cannot own Planets"
        );
        _;
    }

    modifier checkPermissions(uint256 _planetId) {
        address sender = _msgSender();
        require(planetExists(_planetId), "Planets: This planet doesn't exist");
        require(
            isOwnerOfPlanet(sender, _planetId),
            "Planets: You do not control this Planet"
        );
        _;
    }

    modifier universeSet() {
        require(
            address(universe) != address(0),
            "Planets: Universe is not set"
        );
        _;
    }

    event Compound(
        address indexed account,
        uint256 indexed planetId,
        uint256 amountToCompound
    );
    event Cashout(
        address indexed account,
        uint256 indexed planetId,
        uint256 rewardAmount
    );

    event CompoundAll(
        address indexed account,
        uint256[] indexed affectedPlanets,
        uint256 amountToCompound
    );
    event CashoutAll(
        address indexed account,
        uint256[] indexed affectedPlanets,
        uint256 rewardAmount
    );

    event Create(
        address indexed account,
        uint256 indexed newPlanetId,
        uint256 amount
    );

    function initialize() external initializer {
        __ERC721_init("Universe Ecosystem", "PLANET");
        __Ownable_init();
        __ERC721Enumerable_init();
        __ERC721URIStorage_init();
        __ReentrancyGuard_init();
        __Pausable_init();

        // Initialize contract
        changeRewardPerDay(46299); // 4% per day
        changeNodeMinPrice(42_000 * (10**18)); // 42,000 UNIV
        changeCompoundDelay(14400); // 4h
        changeProcessingFee(28); // 28%
        changeTierSystem(
            [100000, 105000, 110000, 120000, 130000, 140000],
            [1000, 500, 100, 50, 10, 0]
        );
    }

    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override(ERC721URIStorageUpgradeable, ERC721Upgradeable)
        returns (string memory)
    {
        // return Strings.strConcat(
        //     _baseTokenURI(),
        //     Strings.uint2str(tokenId)
        // );

        // ToDo: fix this
        // To fix: https://andyhartnett.medium.com/solidity-tutorial-how-to-store-nft-metadata-and-svgs-on-the-blockchain-6df44314406b
        // Base64 support for names coming: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/2884/files
        //string memory tokenURI = "test";
        //_setTokenURI(newPlanetId, tokenURI);

        return ERC721URIStorageUpgradeable.tokenURI(tokenId);
    }

    function createPlanetWithTokens(
        string memory planetName,
        uint256 planetValue
    ) external nonReentrant whenNotPaused universeSet returns (uint256) {
        address sender = _msgSender();

        require(
            bytes(planetName).length > 1 && bytes(planetName).length < 32,
            "Planets: Incorrect name length, must be between 2 to 32"
        );
        require(
            planetValue >= creationMinPrice,
            "Planets: Planet value set below minimum"
        );
        require(
            isNameAvailable(sender, planetName),
            "Planets: Name not available"
        );
        require(
            universe.balanceOf(sender) >= creationMinPrice,
            "Planets: Balance too low for creation"
        );

        // Burn the tokens used to mint the NFT
        universe.accountBurn(sender, planetValue);

        // Send processing fee to liquidity
        (uint256 planetValueTaxed, uint256 feeAmount) = getProcessingFee(
            planetValue
        );
        universe.liquidityReward(feeAmount);

        // Increment the total number of tokens
        _planetCounter.increment();

        uint256 newPlanetId = _planetCounter.current();
        uint256 currentTime = block.timestamp;

        // Add this to the TVL
        totalValueLocked += planetValueTaxed;
        logTier(tierLevel[0], int256(planetValueTaxed));

        // Add Planet
        _planets[newPlanetId] = PlanetEntity({
            id: newPlanetId,
            name: planetName,
            creationTime: currentTime,
            lastProcessingTimestamp: currentTime,
            rewardMult: tierLevel[0],
            planetValue: planetValueTaxed,
            totalClaimed: 0,
            exists: true
        });

        // Assign the Planet to this account
        _mint(sender, newPlanetId);

        emit Create(sender, newPlanetId, planetValueTaxed);

        return newPlanetId;
    }

    function cashoutReward(uint256 _planetId)
        external
        nonReentrant
        onlyPlanetOwner
        checkPermissions(_planetId)
        whenNotPaused
        universeSet
    {
        address account = _msgSender();
        uint256 reward = _getPlanetCashoutRewards(_planetId);
        _cashoutReward(reward);

        emit Cashout(account, _planetId, reward);
    }

    function cashoutAll()
        external
        nonReentrant
        onlyPlanetOwner
        whenNotPaused
        universeSet
    {
        address account = _msgSender();
        uint256 rewardsTotal = 0;

        uint256[] memory planetsOwned = getPlanetIdsOf(account);
        for (uint256 i = 0; i < planetsOwned.length; i++) {
            rewardsTotal += _getPlanetCashoutRewards(planetsOwned[i]);
        }
        _cashoutReward(rewardsTotal);

        emit CashoutAll(account, planetsOwned, rewardsTotal);
    }

    function compoundReward(uint256 _planetId)
        external
        nonReentrant
        onlyPlanetOwner
        checkPermissions(_planetId)
        whenNotPaused
        universeSet
    {
        address account = _msgSender();

        (
            uint256 amountToCompound,
            uint256 feeAmount
        ) = _getPlanetCompoundRewards(_planetId);
        require(
            amountToCompound > 0,
            "Planets: You must wait until you can compound again"
        );
        if (feeAmount > 0) {
            universe.liquidityReward(feeAmount);
        }

        emit Compound(account, _planetId, amountToCompound);
    }

    function compoundAll()
        external
        nonReentrant
        onlyPlanetOwner
        whenNotPaused
        universeSet
    {
        address account = _msgSender();
        uint256 feesAmount = 0;
        uint256 amountsToCompound = 0;
        uint256[] memory planetsOwned = getPlanetIdsOf(account);
        uint256[] memory planetsAffected = new uint256[](planetsOwned.length);

        for (uint256 i = 0; i < planetsOwned.length; i++) {
            (
                uint256 amountToCompound,
                uint256 feeAmount
            ) = _getPlanetCompoundRewards(planetsOwned[i]);
            if (amountToCompound > 0) {
                planetsAffected[i] = planetsOwned[i];
                feesAmount += feeAmount;
                amountsToCompound += amountToCompound;
            } else {
                delete planetsAffected[i];
            }
        }

        require(amountsToCompound > 0, "Planets: No rewards to compound");
        if (feesAmount > 0) {
            universe.liquidityReward(feesAmount);
        }

        emit CompoundAll(account, planetsAffected, amountsToCompound);
    }

    // Private reward functions

    function _getPlanetCashoutRewards(uint256 _planetId)
        private
        returns (uint256)
    {
        PlanetEntity storage planet = _planets[_planetId];

        if (!isProcessable(planet)) {
            return 0;
        }

        uint256 reward = calculateReward(planet);
        planet.totalClaimed += reward;

        if (planet.rewardMult != tierLevel[0]) {
            logTier(planet.rewardMult, -int256(planet.planetValue));
            logTier(tierLevel[0], int256(planet.planetValue));
        }

        planet.rewardMult = tierLevel[0];
        planet.lastProcessingTimestamp = block.timestamp;
        return reward;
    }

    function _getPlanetCompoundRewards(uint256 _planetId)
        private
        returns (uint256, uint256)
    {
        PlanetEntity storage planet = _planets[_planetId];

        if (!isProcessable(planet)) {
            return (0, 0);
        }

        uint256 reward = calculateReward(planet);
        if (reward > 0) {
            (uint256 amountToCompound, uint256 feeAmount) = getProcessingFee(
                reward
            );
            totalValueLocked += amountToCompound;

            logTier(planet.rewardMult, -int256(planet.planetValue));

            planet.lastProcessingTimestamp = block.timestamp;
            planet.planetValue += amountToCompound;
            planet.rewardMult += increaseMultiplier(planet.rewardMult);

            logTier(planet.rewardMult, int256(planet.planetValue));

            return (amountToCompound, feeAmount);
        }

        return (0, 0);
    }

    function _cashoutReward(uint256 amount) private {
        require(
            amount > 0,
            "Planets: You don't have enough reward to cash out"
        );
        address to = _msgSender();
        (uint256 amountToReward, uint256 feeAmount) = getProcessingFee(amount);
        universe.accountReward(to, amountToReward);
        // Send the fee to the contract where liquidity will be added later on
        universe.liquidityReward(feeAmount);
    }

    function logTier(uint256 mult, int256 amount) private {
        TierStorage storage tierStorage = _tierTracking[mult];
        if (tierStorage.exists) {
            require(
                tierStorage.rewardMult == mult,
                "Planets: rewardMult does not match in TierStorage"
            );
            uint256 amountLockedInTier = uint256(
                int256(tierStorage.amountLockedInTier) + amount
            );
            require(
                amountLockedInTier >= 0,
                "Planets: amountLockedInTier cannot underflow"
            );
            tierStorage.amountLockedInTier = amountLockedInTier;
        } else {
            // Tier isn't registered exist, register it
            require(
                amount > 0,
                "Planets: Fatal error while creating new TierStorage. Amount cannot be below zero."
            );
            _tierTracking[mult] = TierStorage({
                rewardMult: mult,
                amountLockedInTier: uint256(amount),
                exists: true
            });
            _tiersTracked.push(mult);
        }
    }

    // Private view functions

    function getProcessingFee(uint256 rewardAmount)
        private
        view
        returns (uint256, uint256)
    {
        uint256 feeAmount = 0;
        if (processingFee > 0) {
            feeAmount = (rewardAmount * processingFee) / 100;
        }
        return (rewardAmount - feeAmount, feeAmount);
    }

    function increaseMultiplier(uint256 prevMult)
        private
        view
        returns (uint256)
    {
        if (prevMult >= tierLevel[5]) {
            return tierSlope[5];
        } else if (prevMult >= tierLevel[4]) {
            return tierSlope[4];
        } else if (prevMult >= tierLevel[3]) {
            return tierSlope[2];
        } else if (prevMult >= tierLevel[2]) {
            return tierSlope[2];
        } else if (prevMult >= tierLevel[1]) {
            return tierSlope[1];
        } else {
            return tierSlope[0];
        }
    }

    function isProcessable(PlanetEntity memory planet)
        private
        view
        returns (bool)
    {
        return
            block.timestamp >= planet.lastProcessingTimestamp + compoundDelay;
    }

    function calculateReward(PlanetEntity memory planet)
        private
        view
        returns (uint256)
    {
        return
            _calculateRewardsFromValue(
                planet.planetValue,
                planet.rewardMult,
                block.timestamp - planet.lastProcessingTimestamp,
                rewardPerDay
            );
    }

    function rewardPerDayFor(PlanetEntity memory planet)
        private
        view
        returns (uint256)
    {
        return
            _calculateRewardsFromValue(
                planet.planetValue,
                planet.rewardMult,
                ONE_DAY,
                rewardPerDay
            );
    }

    function _calculateRewardsFromValue(
        uint256 _planetValue,
        uint256 _rewardMult,
        uint256 _timeRewards,
        uint256 _rewardPerDay
    ) private pure returns (uint256) {
        uint256 rewards = (_timeRewards * _rewardPerDay) / 1000000;
        uint256 rewardsMultiplicated = (rewards * _rewardMult) / 100000;
        return (rewardsMultiplicated * _planetValue) / 100000;
    }

    function planetExists(uint256 _planetId) private view returns (bool) {
        require(_planetId > 0, "Planets: Id must be higher than zero");
        PlanetEntity memory planet = _planets[_planetId];
        if (planet.exists) {
            return true;
        }
        return false;
    }

    // Public view functions

    function calculateTotalDailyEmission() external view returns (uint256) {
        uint256 dailyEmission = 0;
        for (uint256 i = 0; i < _tiersTracked.length; i++) {
            TierStorage memory tierStorage = _tierTracking[_tiersTracked[i]];
            dailyEmission += _calculateRewardsFromValue(
                tierStorage.amountLockedInTier,
                tierStorage.rewardMult,
                ONE_DAY,
                rewardPerDay
            );
        }
        return dailyEmission;
    }

    function isNameAvailable(address account, string memory planetName)
        public
        view
        returns (bool)
    {
        uint256[] memory planetsOwned = getPlanetIdsOf(account);
        for (uint256 i = 0; i < planetsOwned.length; i++) {
            PlanetEntity memory planet = _planets[planetsOwned[i]];
            if (keccak256(bytes(planet.name)) == keccak256(bytes(planetName))) {
                return false;
            }
        }
        return true;
    }

    function isOwnerOfPlanets(address account) public view returns (bool) {
        return balanceOf(account) > 0;
    }

    function isOwnerOfPlanet(address account, uint256 _planetId)
        public
        view
        returns (bool)
    {
        uint256[] memory planetIdsOf = getPlanetIdsOf(account);
        for (uint256 i = 0; i < planetIdsOf.length; i++) {
            if (planetIdsOf[i] == _planetId) {
                return true;
            }
        }
        return false;
    }

    function getPlanetIdsOf(address account)
        public
        view
        returns (uint256[] memory)
    {
        uint256 numberOfPlanets = balanceOf(account);
        uint256[] memory planetIds = new uint256[](numberOfPlanets);
        for (uint256 i = 0; i < numberOfPlanets; i++) {
            uint256 planetId = tokenOfOwnerByIndex(account, i);
            require(
                planetExists(planetId),
                "Planets: This planet doesn't exist"
            );
            planetIds[i] = planetId;
        }
        return planetIds;
    }

    function getPlanetsByIds(uint256[] memory _planetIds)
        external
        view
        returns (PlanetInfoEntity[] memory)
    {
        PlanetInfoEntity[] memory planetsInfo = new PlanetInfoEntity[](
            _planetIds.length
        );
        for (uint256 i = 0; i < _planetIds.length; i++) {
            uint256 planetId = _planetIds[i];
            PlanetEntity memory planet = _planets[planetId];
            planetsInfo[i] = PlanetInfoEntity(
                planet,
                planetId,
                calculateReward(planet),
                rewardPerDayFor(planet),
                compoundDelay
            );
        }
        return planetsInfo;
    }

    // Owner functions

    function changeNodeMinPrice(uint256 _creationMinPrice) public onlyOwner {
        require(
            _creationMinPrice > 0,
            "Planets: Minimum price to create a Planet must be above 0"
        );
        creationMinPrice = _creationMinPrice;
    }

    function changeCompoundDelay(uint256 _compoundDelay) public onlyOwner {
        require(
            _compoundDelay > 0,
            "Planets: compoundDelay must be greater than 0"
        );
        compoundDelay = _compoundDelay;
    }

    function changeRewardPerDay(uint256 _rewardPerDay) public onlyOwner {
        require(
            _rewardPerDay > 0,
            "Planets: rewardPerDay must be greater than 0"
        );
        rewardPerDay = _rewardPerDay;
    }

    function changeTierSystem(
        uint24[6] memory _tierLevel,
        uint16[6] memory _tierSlope
    ) public onlyOwner {
        require(
            _tierLevel.length == 6,
            "Planets: newTierLevels length has to be 6"
        );
        require(
            _tierSlope.length == 6,
            "Planets: newTierSlopes length has to be 6"
        );
        tierLevel = _tierLevel;
        tierSlope = _tierSlope;
    }

    function changeProcessingFee(uint8 _processingFee) public onlyOwner {
        require(_processingFee <= 30, "Cashout fee can never exceed 30%");
        processingFee = _processingFee;
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    // Mandatory overrides

    function _burn(uint256 tokenId)
        internal
        override(ERC721URIStorageUpgradeable, ERC721Upgradeable)
    {
        ERC721Upgradeable._burn(tokenId);
        ERC721URIStorageUpgradeable._burn(tokenId);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    )
        internal
        virtual
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable)
        whenNotPaused
    {
        super._beforeTokenTransfer(from, to, amount);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}