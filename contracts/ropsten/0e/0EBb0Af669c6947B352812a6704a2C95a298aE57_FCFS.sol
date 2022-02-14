pragma solidity 0.8.4;

import '@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol';

import '@openzeppelin/contracts/token/ERC1155/IERC1155.sol';
import '@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol';

import '@openzeppelin/contracts/access/Ownable.sol';

// TODO fix amount exceeding
contract FCFS is ERC1155Holder, Ownable {
    IERC20 public erc20;

    uint256 public constant ONE_TOKEN_IN_WEI = 1e18;
    bytes private constant DEF_DATA = '';

    enum Tier {
        TIER1,
        TIER2,
        TIER3
    }

    enum Protocol {
        NOT_SPECIFIED,
        ERC1155,
        ERC721
    }

    uint256 public lotsCounter = 0;
    uint256 public stakeCounter = 0;

    uint256 public feeNuminator = 145;
    uint256 public feeDenuminator = 1000;

    address public addressToSendFee;

    struct Stake {
        uint256 lotId;
        uint256 amount;
        bool claimed;
        address better;
    }

    struct Lot {
        uint256 lotId;
        uint256 tokenId;
        uint256 amount;
        uint256 pricePerOne;
        uint256 start;
        uint256 period;
        Tier[] allowedTiers;
        uint256[] stakeIds;
        address owner;
        address contractAddr;
        bool status;
    }

    mapping(address => Protocol) public assetsTypes;

    mapping(address => Tier) public tiers;

    mapping(uint256 => Lot) public lots;
    mapping(uint256 => Stake) public stakes;
    mapping(address => uint256[]) public betsOfAUser;

    event StakeCreation(uint256 indexed lotId, uint256 indexed amount);

    event Claim(uint256 indexed lotId, uint256 indexed stakeId);

    constructor(address TOKEN20, address wallet) {
        erc20 = IERC20(TOKEN20);
        addressToSendFee = wallet;

        transferOwnership(msg.sender);
    }

    function placeALot(
        uint256 tokenId,
        uint256 amount,
        uint256 pricePerOne,
        uint256 period,
        Tier[] calldata allowedTiers,
        Protocol protocol,
        address contractAddr
    ) external onlyOwner {
        IERC1155 erc1155 = IERC1155(contractAddr);

        require(
            erc1155.balanceOf(msg.sender, tokenId) >= amount,
            "You don't have enough tokens"
        );
        //todo check if it's nedeed
        require(amount > 0, 'Amount must be greater than zero');

        erc1155.safeTransferFrom(msg.sender, address(this), tokenId, amount, DEF_DATA);

        _createALot(tokenId, amount, pricePerOne, period, allowedTiers, contractAddr);

        if (assetsTypes[contractAddr] == Protocol.NOT_SPECIFIED) {
            _setAssetProtocol(contractAddr, protocol);
        }
    }

    function stake(uint256 lotId, uint256 amount) external {
        require(
            erc20.balanceOf(msg.sender) >= lots[lotId].pricePerOne * amount,
            "You don't have enough money to stake"
        );

        require(
            tiers[msg.sender] == lots[lotId].allowedTiers[0] ||
                tiers[msg.sender] == lots[lotId].allowedTiers[1] ||
                tiers[msg.sender] == lots[lotId].allowedTiers[2],
            "You're not in the required tier"
        );

        require(lots[lotId].amount > 0, 'You were too late, the NFTs are over');
        require(lots[lotId].amount > amount, 'This amount exceeds allocation');

        erc20.transferFrom(msg.sender, address(this), lots[lotId].pricePerOne * amount);

        stakeCounter += 1;
        lots[lotId].amount -= amount;
        lots[lotId].stakeIds.push(stakeCounter);

        stakes[stakeCounter] = Stake({
            lotId: lotId,
            amount: amount,
            claimed: false,
            better: msg.sender
        });

        emit StakeCreation(lotId, amount);
    }

    function claim(uint256 stakeId) public {
        uint256 lotId = stakes[stakeId].lotId;
        require(
            lots[lotId].start + lots[lotId].period <= block.timestamp,
            'The FCFS in not over yet'
        );
        require(!stakes[stakeId].claimed, 'You have already claimed your earnings');

        IERC1155 erc1155 = IERC1155(lots[lotId].contractAddr);

        erc1155.safeTransferFrom(
            address(this),
            msg.sender,
            lotId,
            lots[lotId].amount,
            DEF_DATA
        );

        stakes[stakeId].claimed = true;
        emit Claim(lotId, stakeId);
    }

    function addUserToTier(address user, Tier tier) external onlyOwner {
        tiers[user] = tier;
    }

    function _setAssetProtocol(address contractAddr, Protocol protocol)
        internal
    {
        assetsTypes[contractAddr] = protocol;
    }

    function _createALot(
        uint256 tokenId,
        uint256 amount,
        uint256 pricePerOne,
        uint256 period,
        Tier[] memory allowedTiers,
        address contractAddr
    ) internal {
        lotsCounter += 1;
        stakeCounter += 1;

        uint256[] memory stakeIds;

        lots[lotsCounter] = Lot({
            lotId: lotsCounter,
            tokenId: tokenId,
            amount: amount,
            pricePerOne: pricePerOne,
            start: block.timestamp,
            period: period,
            allowedTiers: allowedTiers,
            stakeIds: stakeIds,
            owner: msg.sender,
            contractAddr: contractAddr,
            status: true
        });
    }

    function _calculateFee(uint256 bet) internal view returns (uint256 fee) {
        fee = (bet * feeNuminator) / feeDenuminator;

        return fee;
    }

    function getAllLots() external view returns (Lot[] memory lots_) {
        lots_ = new Lot[](lotsCounter);

        for (uint256 i = 0; i < lotsCounter; i++) {
            lots_[i] = lots[i];
        }
    }

    function getAllStakesForALot(uint256 lotId)
        external
        view
        returns (Stake[] memory stakes_, uint256[] memory ids)
    {
        ids = lots[lotId].stakeIds;
        stakes_ = new Stake[]((lots[lotId].stakeIds).length);

        for (uint256 i = 0; i < (lots[lotId].stakeIds).length; i++) {
            stakes_[i] = stakes[i];
        }
    }

    function getAllStakesForAUser(address user)
        external
        view
        returns (Stake[] memory stakes_)
    {
        uint256 usersStakesAmount = 0;

        for (uint256 i = 0; i < stakeCounter; i++) {
            if (stakes[i].better == user) {
                usersStakesAmount++;
            }
        }

        stakes_ = new Stake[](usersStakesAmount);

        uint256 j = 0;
        for (uint256 i = 0; i < stakeCounter; i++) {
            if (stakes[i].better == user) {
                stakes_[j] = stakes[i];
                j++;
            }
        }
    }
}