// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./SafeMath.sol";
import "./IERC20.sol";
import "./GratiaERC721.sol";

/**
 * @title Gratia NFT contract
 * @dev Extends GratiaERC721 Non-Fungible Token Standard basic implementation
 */

contract Gratia is GratiaERC721 {
    using SafeMath for uint256;
    using Address for address;

    // Public variables

    // This is SHA256 hash of the provenance record of all Gratia artworks
    // It is derived by hashing every individual NFT's picture, and then concatenating all those hash, deriving yet another SHA256 from that.
    string public GRATIA_PROVENANCE = "";

    uint256 public constant SALE_START_TIMESTAMP = 1626104202;
    uint256 public constant REVEAL_TIMESTAMP = SALE_START_TIMESTAMP + (7 days);
    uint256 public constant MAX_GRATIA_SUPPLY = 10000;
    uint256 public GRATIA_MINT_COUNT_LIMIT = 30;

    uint256 public constant REFERRAL_REWARD_PERCENT = 1000; // 10%
    uint256 public constant LIQUIDITY_FUND_PERCENT = 1000;  // 10%

    bool public saleIsActive = false;
    uint256 public startingIndexBlock;
    uint256 public startingIndex;
    uint256 public mintPrice = 69000000000000000; // 0.069 ETH
    uint256 public ggrtReward = 10000000000000000000; // (10% of GGRT totalSupply) / 10000

    // Mapping from token ID to puzzle
    mapping (uint256 => uint256) public puzzles;

    // Referral management
    uint256 public totalReferralRewardAmount;
    uint256 public distributedReferralRewardAmount;
    mapping(address => uint256) public referralRewards;
    mapping(address => mapping(address => bool)) public referralStatus;

    address payable public constant liquidityFundAddress = payable(
        0x917BcA0BB7275F93167425c3e6e61261e6D46D08
    );
    address payable public constant treasuryFundAddress = payable(
        0xBF1aFb3Eaf4895cED2ad492361373433a4C47A2D
    );

    /*
     *     bytes4(keccak256('balanceOf(address)')) == 0x70a08231
     *     bytes4(keccak256('ownerOf(uint256)')) == 0x6352211e
     *     bytes4(keccak256('approve(address,uint256)')) == 0x095ea7b3
     *     bytes4(keccak256('getApproved(uint256)')) == 0x081812fc
     *     bytes4(keccak256('setApprovalForAll(address,bool)')) == 0xa22cb465
     *     bytes4(keccak256('isApprovedForAll(address,address)')) == 0xe985e9c5
     *     bytes4(keccak256('transferFrom(address,address,uint256)')) == 0x23b872dd
     *     bytes4(keccak256('safeTransferFrom(address,address,uint256)')) == 0x42842e0e
     *     bytes4(keccak256('safeTransferFrom(address,address,uint256,bytes)')) == 0xb88d4fde
     *
     *     => 0x70a08231 ^ 0x6352211e ^ 0x095ea7b3 ^ 0x081812fc ^
     *        0xa22cb465 ^ 0xe985e9c5 ^ 0x23b872dd ^ 0x42842e0e ^ 0xb88d4fde == 0x80ac58cd
     */
    bytes4 private constant _INTERFACE_ID_ERC721 = 0x80ac58cd;

    /*
     *     bytes4(keccak256('name()')) == 0x06fdde03
     *     bytes4(keccak256('symbol()')) == 0x95d89b41
     *     bytes4(keccak256('tokenURI(uint256)')) == 0xc87b56dd
     *
     *     => 0x06fdde03 ^ 0x95d89b41 == 0x93254542
     *     => 0x06fdde03 ^ 0x95d89b41 ^ 0xc87b56dd == 0x5b5e139f
     */
    bytes4 private constant _INTERFACE_ID_ERC721_METADATA = 0x5b5e139f;

    /*
     *     bytes4(keccak256('totalSupply()')) == 0x18160ddd
     *     bytes4(keccak256('tokenOfOwnerByIndex(address,uint256)')) == 0x2f745c59
     *     bytes4(keccak256('tokenByIndex(uint256)')) == 0x4f6ccce7
     *
     *     => 0x18160ddd ^ 0x2f745c59 ^ 0x4f6ccce7 == 0x780e9d63
     */
    bytes4 private constant _INTERFACE_ID_ERC721_ENUMERABLE = 0x780e9d63;

    // Events
    event DistributeReferralRewards (uint256 indexed gratiaIndex, uint256 amount);
    event EarnReferralReward (address indexed account, uint256 amount);
    event WithdrawFund (uint256 liquidityFund, uint256 treasuryFund);

    /**
     * @dev Initializes the contract by setting a `name` and a `symbol` to the token collection.
     */
    constructor (string memory name_, string memory symbol_, address ggrt, address nyg) GratiaERC721(name_, symbol_) {
        ggrtToken = ggrt;
        nygToken = nyg;

        // register the supported interfaces to conform to GratiaERC721 via ERC165
        _registerInterface(_INTERFACE_ID_ERC721);
        _registerInterface(_INTERFACE_ID_ERC721_METADATA);
        _registerInterface(_INTERFACE_ID_ERC721_ENUMERABLE);
    }

    function mintGratia(uint256 count, address referrer) public payable {
        require(block.timestamp >= SALE_START_TIMESTAMP, "Sale has not started");
        require(saleIsActive, "Sale must be active to mint");
        require(totalSupply() < MAX_GRATIA_SUPPLY, "Sale has already ended");
        require(count > 0, "count cannot be 0");
        require(count <= GRATIA_MINT_COUNT_LIMIT, "Exceeds mint count limit");
        require(totalSupply().add(count) <= MAX_GRATIA_SUPPLY, "Exceeds max supply");
        require(mintPrice.mul(count) <= msg.value, "Ether value sent is not correct");

        IERC20(ggrtToken).transfer(_msgSender(), ggrtReward.mul(count));

        for (uint256 i = 0; i < count; i++) {
            uint256 mintIndex = totalSupply();
            if (block.timestamp < REVEAL_TIMESTAMP) {
                _mintedBeforeReveal[mintIndex] = true;
            }
            puzzles[mintIndex] = getRandomNumber(type(uint256).min, type(uint256).max.sub(1));
            _safeMint(_msgSender(), mintIndex);
        }

        if (referrer != address(0) && referrer != _msgSender()) {
            _rewardReferral(referrer, _msgSender(), msg.value);
        }

        /**
        * Source of randomness. Theoretical miner withhold manipulation possible but should be sufficient in a pragmatic sense
        */
        if (startingIndexBlock == 0 && (totalSupply() == MAX_GRATIA_SUPPLY || block.timestamp >= REVEAL_TIMESTAMP)) {
            startingIndexBlock = block.number;
        }
    }

    /**
     * Set price to mint a Gratia.
     */
    function setMintPrice(uint256 _price) external onlyOwner {
        mintPrice = _price;
    }

    /**
     * Set maximum count to mint per once.
     */
    function setMintCountLimit(uint256 count) external onlyOwner {
        GRATIA_MINT_COUNT_LIMIT = count;
    }

    /**
     * Set GGRT reward amount to mint a Gratia.
     */
    function setGGRTReward(uint256 _ggrtReward) external onlyOwner {
        ggrtReward = _ggrtReward;
    }

    /**
     * Mint Gratias by owner
     */
    function reserveGratias(address to, uint256 count) external onlyOwner {
        require(to != address(0), "Invalid address to reserve.");
        uint256 supply = totalSupply();
        uint256 i;
        
        for (i = 0; i < count; i++) {
            _safeMint(to, supply + i);
        }
    }

    /*     
    * Set provenance once it's calculated
    */
    function setProvenanceHash(string memory _provenanceHash) external onlyOwner {
        GRATIA_PROVENANCE = _provenanceHash;
    }

    /*
    * Pause sale if active, make active if paused
    */
    function setSaleState() external onlyOwner {
        saleIsActive = !saleIsActive;
    }

    /**
     * @dev Finalize starting index
     */
    function finalizeStartingIndex() public virtual {
        require(startingIndex == 0, "Starting index is already set");
        require(startingIndexBlock != 0, "Starting index block must be set");

        startingIndex = uint(blockhash(startingIndexBlock)) % MAX_GRATIA_SUPPLY;
        // Just a sanity case in the worst case if this function is called late (EVM only stores last 256 block hashes)
        if (block.number.sub(startingIndexBlock) > 255) {
            startingIndex = uint(blockhash(block.number-1)) % MAX_GRATIA_SUPPLY;
        }
        // Prevent default sequence
        if (startingIndex == 0) {
            startingIndex = startingIndex.add(1);
        }
    }

    /**
     * @dev Withdraws liquidity and treasury fund.
     */
    function withdrawFund() external {
        uint256 fund = address(this).balance.sub(totalReferralRewardAmount).add(distributedReferralRewardAmount);
        uint256 liquidityFund = _percent(fund, LIQUIDITY_FUND_PERCENT);
        liquidityFundAddress.transfer(liquidityFund);
        uint256 treasuryFund = fund.sub(liquidityFund);
        treasuryFundAddress.transfer(treasuryFund);
        emit WithdrawFund(liquidityFund, treasuryFund);
    }

    /**
     * @dev Withdraws GGRT to treasury if GGRT after sale ended
     */
    function withdrawFreeToken(address token) public onlyOwner {	
        if (token == ggrtToken) {	
            require(totalSupply() >= MAX_GRATIA_SUPPLY, "Sale has not ended");	
        }	
        	
        IERC20(token).transfer(treasuryFundAddress, IERC20(token).balanceOf(address(this)));	
    }
    
    function _rewardReferral(address referrer, address referee, uint256 referralAmount) internal {
        uint256 referrerBalance = GratiaERC721.balanceOf(referrer);
        bool status = referralStatus[referrer][referee];
        uint256 rewardAmount = _percent(referralAmount, REFERRAL_REWARD_PERCENT);

        if (referrerBalance != 0 && rewardAmount != 0 && !status) {
            referralRewards[referrer] = referralRewards[referrer].add(rewardAmount);
            totalReferralRewardAmount = totalReferralRewardAmount.add(rewardAmount);
            emit EarnReferralReward(referrer, rewardAmount);
            referralRewards[referee] = referralRewards[referee].add(rewardAmount);
            totalReferralRewardAmount = totalReferralRewardAmount.add(rewardAmount);
            emit EarnReferralReward(referee, rewardAmount);
            referralStatus[referrer][referee] = true;
        }
    }

    function distributeReferralRewards(uint256 startGratiaId, uint256 endGratiaId) external onlyOwner {
        require(block.timestamp > SALE_START_TIMESTAMP, "Sale has not started");
        require(startGratiaId < totalSupply(), "Index is out of range");

        if (endGratiaId >= totalSupply()) {
            endGratiaId = totalSupply().sub(1);
        }
        
        for (uint256 i = startGratiaId; i <= endGratiaId; i++) {
            address owner = ownerOf(i);
            uint256 amount = referralRewards[owner];
            if (amount > 0) {
                gratiaWallet.depositETH{ value: amount }(address(this), i, amount);                
                distributedReferralRewardAmount = distributedReferralRewardAmount.add(amount);
                delete referralRewards[owner];
                emit DistributeReferralRewards(i, amount);
            }
        }
    }

    /**
     * Set the starting index block for the collection, essentially unblocking
     * setting starting index
     */
    function emergencySetStartingIndexBlock() external onlyOwner {
        require(startingIndex == 0, "Starting index is already set");
        
        startingIndexBlock = block.number;
    }
    
    function withdraw() external onlyOwner {
        treasuryFundAddress.transfer(address(this).balance);
    }
}