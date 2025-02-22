// SPDX-License-Identifier: MIT
// Developed by KG Technologies (https://kgtechnologies.io)

pragma solidity 0.8.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

/**
 * @notice Represents MetaTriad Smart Contract
 */
contract IMetaTriads {
    /** 
     * @dev ERC-721 INTERFACE 
     */
    function ownerOf(uint256 tokenId) public view virtual returns (address) {}

    /** 
     * @dev CUSTOM INTERFACE 
     */
    function mintTo(uint256 amount, address _to) external {}
    function maxMintPerTransaction() public returns (uint256) {}
}

/**
 * @title MetaTriadsTicketContract.
 *
 * @author KG Technologies (https://kgtechnologies.io).
 *
 * @notice This Smart Contract can be used to sell a fixed amount of tickets where some of them are 
 * sold to permissioned wallets and the others are sold to the general public. 
 * The tickets can then be used to mint a corresponding amount of NFTs.
 *
 * @dev The primary mode of verifying permissioned actions is through Merkle Proofs
 * which are generated off-chain.
 */
contract MetaTriadsTicketContract is Ownable {

    /** 
     * @notice The Smart Contract of MetaTriad 
     * @dev ERC-721 Smart Contract 
     */
    IMetaTriads public immutable nft;
    
    /** 
     * @dev MINT DATA 
     */
    uint256 public maxSupplyPermissioned = 3000;
    uint256 public boughtPermissioned = 0;
    uint256 public pricePermissioned = 0.2 ether;

    uint256 public phaseOneStartTime = 1;
    uint256 public phaseOneDuration = 100 * 365 days;
    uint256 public phaseTwoStartTime = 1;
    uint256 public phaseTwoDuration = 100 * 365 days;

    uint256 public maxSupplyOpen = 3000;
    uint256 public boughtOpen = 0;
    uint256 public limitOpen = 10;
    uint256 public priceOpen = 0.3 ether;
    uint256 public startTimeOpen = 1;
    
    mapping(address => uint256) public addressToTicketsOpen;
    mapping(address => mapping(uint256 => uint256)) public addressToTicketsPermissioned;
    mapping(address => uint256) public addressToMints;    

    /// @dev Initial value is randomly generated from https://www.random.org/
    bytes32 public merkleRoot = 0xe788a23866da0e903934d723c44efe9da3f7265d053a8fed5c1036a78665f9c1;

    /**
     * @dev GIVEAWAY 
     */
    uint256 public maxSupplyGiveaway = 50;
    uint256 public giveAwayRedeemed = 1;
    mapping(address => uint256) public addressToGiveawayRedeemed;
    bytes32 public giveAwayMerkleRoot = "";

    /**
     * @dev Events
     */
    event ReceivedEther(address indexed sender, uint256 indexed amount);
    event Purchase(address indexed buyer, uint256 indexed amount, bool indexed permissioned);
    event RedeemTickets(address indexed redeemer, uint256 amount);
    event RedeemGiveAway(address indexed redeemer, uint256 amount);
    event setMaxSupplyPermissionedEvent(uint256 indexed maxSupply);
    event setMaxSupplyOpenEvent(uint256 indexed maxSupply);
    event setLimitOpenEvent(uint256 indexed limit);
    event setPriceOpenEvent(uint256 indexed price);
    event setMerkleRootEvent(bytes32 indexed merkleRoot);
    event setGiveAwayMerkleRootEvent(bytes32 indexed merkleRoot);
    event setGiveAwayMaxSupplyEvent(uint256 indexed newSupply);
    event setPublicSaleStateEvent(bool indexed newState);
    event setPricePermissionedEvent(uint256 indexed price);
    event setPhaseOneStartTimeEvent(uint256 indexed time);
    event setPhaseOneDurationEvent(uint256 indexed time);
    event setPhaseTwoStartTimeEvent(uint256 indexed time);
    event setPhaseTwoDurationEvent(uint256 indexed time);
    event setStartTimeOpenEvent(uint256 indexed time);
    event WithdrawAllEvent(address indexed to, uint256 amount);

    constructor(
        address _metaTriadsAddress
    ) Ownable() {
        nft = IMetaTriads(_metaTriadsAddress);
    }
 
    /**
     * @dev SALE
     */

    /**
     * @notice Validates the sale data for each phase per user
     *
     * @dev For each phase validates that the time is correct,
     * that the ether supplied is correct and that the purchase 
     * amount doesn't exceed the max amount
     *
     * @param amount. The amount the user want's to purchase
     * @param phase. The sale phase of the user
     */
    function validatePhaseSpecificPurchase(uint256 amount, uint256 phase) internal {
        if (phase == 1) {
            require(block.timestamp >= phaseOneStartTime, "PHASE ONE SALE HASN'T STARTED YET");
            require(block.timestamp < phaseOneStartTime + phaseOneDuration, "PHASE ONE SALE IS CLOSED");    
            require(msg.value >= pricePermissioned * amount, "ETHER SENT NOT CORRECT");
            require(boughtPermissioned + amount - 1 <= maxSupplyPermissioned, "BUY AMOUNT GOES OVER MAX SUPPLY");

        } else if (phase == 2) {
            require(block.timestamp >= phaseTwoStartTime, "PHASE TWO SALE HASN'T STARTED YET");
            require(block.timestamp < phaseTwoStartTime + phaseTwoDuration, "PHASE TWO SALE IS CLOSED");    
            require(msg.value >= pricePermissioned * amount, "ETHER SENT NOT CORRECT");
            require(boughtPermissioned + amount - 1 <= maxSupplyPermissioned, "BUY AMOUNT GOES OVER MAX SUPPLY");

        } else if (phase == 3) {
            require(block.timestamp >= startTimeOpen, "PHASE ONE SALE HASN'T STARTED YET"); 
            require(msg.value >= priceOpen * amount, "ETHER SENT NOT CORRECT");
            require(boughtOpen + amount - 1 <= maxSupplyOpen, "BUY AMOUNT GOES OVER MAX SUPPLY");

        } else {
            revert("INCORRECT PHASE");
        }
    }

    /**
     * @notice Function to buy one or more tickets.
     * @dev First the Merkle Proof is verified.
     * Then the buy is verified with the data embedded in the Merkle Proof.
     * Finally the tickets are bought to the user's wallet.
     *
     * @param amount. The amount of tickets to buy.     
     * @param buyMaxAmount. The max amount the user can buy.
     * @param phase. The permissioned sale phase.
     * @param proof. The Merkle Proof of the user.
     */
    function buyPermissioned(uint256 amount, uint256 buyMaxAmount, uint256 phase, bytes32[] calldata proof) 
        external 
        payable {

        /// @dev Verifies Merkle Proof submitted by user.
        /// @dev All mint data is embedded in the merkle proof.

        bytes32 leaf = keccak256(abi.encodePacked(msg.sender, buyMaxAmount, phase));
        require(MerkleProof.verify(proof, merkleRoot, leaf), "INVALID PROOF");

        /// @dev Verify that user can perform permissioned sale based on the provided parameters.

        require(address(nft) != address(0), "METATRIAD NFT SMART CONTRACT NOT SET");
        require(merkleRoot != "", "PERMISSIONED SALE CLOSED");
        require(phase > 0 && phase < 4, "INCORRECT PHASE SUPPLIED");
        
        require(amount > 0, "HAVE TO BUY AT LEAST 1");
        require(addressToTicketsPermissioned[msg.sender][phase] + amount <= buyMaxAmount, "BUY AMOUNT EXCEEDS MAX FOR USER");            

        /// @dev verify that user can perform permissioned sale based on phase of user
        validatePhaseSpecificPurchase(amount, phase);

        /// @dev update pre-sales and whale-sales seperately
        if (phase < 3) {            
            boughtPermissioned += amount;
        }            
        else {            
            boughtOpen += amount;
        }            
        
        addressToTicketsPermissioned[msg.sender][phase] += amount;
        emit Purchase(msg.sender, amount, true);
    }

    /**
     * @notice Function to buy one or more tickets.
     *
     * @param amount. The amount of tickets to buy.
     */
    function buyOpen(uint256 amount) 
        external 
        payable {
        
        /// @dev Verifies that user can perform open sale based on the provided parameters.

        require(address(nft) != address(0), "METATRIAD NFT SMART CONTRACT NOT SET");
        require(block.timestamp >= startTimeOpen, "OPEN SALE CLOSED");

        require(amount > 0, "HAVE TO BUY AT LEAST 1");

        require(addressToTicketsOpen[msg.sender] + amount <= limitOpen, "BUY AMOUNT EXCEEDS MAX FOR USER");
        require(boughtOpen + amount - 1 <= maxSupplyOpen, "BUY AMOUNT GOES OVER MAX SUPPLY");
        require(msg.value >= priceOpen * amount, "ETHER SENT NOT CORRECT");

        /// @dev Updates contract variables and buys `amount` tickets to users wallet

        boughtOpen += amount;
        addressToTicketsOpen[msg.sender] += amount;

        emit Purchase(msg.sender, amount, false);
    }

    /**
     * @dev MINTING 
     */

    /**
     * @notice Allows users to redeem their tickets for NFTs.
     *
     */
    function redeemTickets() external {
        uint256 ticketsOfSender = 
            addressToTicketsPermissioned[msg.sender][1] + 
            addressToTicketsPermissioned[msg.sender][2] + 
            addressToTicketsPermissioned[msg.sender][3] +
            addressToTicketsOpen[msg.sender];
        uint256 mintsOfSender = addressToMints[msg.sender];
        uint256 mintable = ticketsOfSender - mintsOfSender;

        require(mintable > 0, "NO MINTABLE TICKETS");

        uint256 maxMintPerTx = nft.maxMintPerTransaction();
        uint256 toMint = mintable > maxMintPerTx ? maxMintPerTx : mintable;
        
        addressToMints[msg.sender] = addressToMints[msg.sender] + toMint;

        nft.mintTo(toMint, msg.sender);
        emit RedeemTickets(msg.sender, toMint);
    }

    /**
     * @notice Function to redeem giveaway.
     * @dev First the Merkle Proof is verified.
     * Then the redeem is verified with the data embedded in the Merkle Proof.
     * Finally the metatriads are minted to the user's wallet.
     *
     * @param redeemAmount. The amount to redeem.
     * @param proof. The Merkle Proof of the user.
     */
    function redeemGiveAway(uint256 redeemAmount, bytes32[] calldata proof) external {
        /// @dev Verifies Merkle Proof submitted by user.
        /// @dev All giveaway data is embedded in the merkle proof.

        bytes32 leaf = keccak256(abi.encodePacked(msg.sender, redeemAmount));
        require(MerkleProof.verify(proof, giveAwayMerkleRoot, leaf), "INVALID PROOF");

        /// @dev Verifies that user can perform giveaway based on the provided parameters.

        require(address(nft) != address(0), "METATRIAD NFT SMART CONTRACT NOT SET");
        require(giveAwayMerkleRoot != "", "GIVEAWAY CLOSED");

        require(redeemAmount > 0, "HAVE TO REDEEM AT LEAST 1");

        require(addressToGiveawayRedeemed[msg.sender] == 0, "GIVEAWAY ALREADY REDEEMED");
        require(giveAwayRedeemed + redeemAmount - 1 <= maxSupplyGiveaway, "GIVEAWAY AMOUNT GOES OVER MAX SUPPLY");

        /// @dev Updates contract variables and mints `redeemAmount` metatriads to users wallet

        giveAwayRedeemed += redeemAmount;
        addressToGiveawayRedeemed[msg.sender] = 1;

        nft.mintTo(redeemAmount, msg.sender);
        emit RedeemGiveAway(msg.sender, redeemAmount);
    }

    /** 
     * @dev OWNER ONLY 
     */

    /**
     * @notice Change the maximum supply of tickets that are for sale in permissioned sale.
     *
     * @param newMaxSupply. The new max supply.
     */
    function setMaxSupplyPermissioned(uint256 newMaxSupply) external onlyOwner {
        maxSupplyPermissioned = newMaxSupply;
        emit setMaxSupplyPermissionedEvent(newMaxSupply);
    }

    /**
     * @notice Change the maximum supply of tickets that are for sale in open sale.
     *
     * @param newMaxSupply. The new max supply.
     */
    function setMaxSupplyOpen(uint256 newMaxSupply) external onlyOwner {
        maxSupplyOpen = newMaxSupply;
        emit setMaxSupplyOpenEvent(newMaxSupply);
    }

    /**
     * @notice Change the limit of tickets per wallet in open sale.
     *
     * @param newLimitOpen. The new max supply.
     */
    function setLimitOpen(uint256 newLimitOpen) external onlyOwner {
        limitOpen = newLimitOpen;
        emit setLimitOpenEvent(newLimitOpen);
    }

    /**
     * @notice Change the price of tickets that are for sale in open sale.
     *
     * @param newPriceOpen. The new price.
     */
    function setPriceOpen(uint256 newPriceOpen) external onlyOwner {
        priceOpen = newPriceOpen;
        emit setPriceOpenEvent(newPriceOpen);
    }

    /**
     * @notice Change the price of tickets that are for sale in permissioned sale.
     *
     * @param newPricePermissioned. The new price.
     */
    function setPricePermissioned(uint256 newPricePermissioned) external onlyOwner {
        pricePermissioned = newPricePermissioned;
        emit setPricePermissionedEvent(newPricePermissioned);
    }

    /**
     * @notice Change the merkleRoot of the sale.
     *
     * @param newRoot. The new merkleRoot.
     */
    function setMerkleRoot(bytes32 newRoot) external onlyOwner {
        merkleRoot = newRoot;
        emit setMerkleRootEvent(newRoot);
    }

    /**
     * @notice Delete the merkleRoot of the sale.
     */
    function deleteMerkleRoot() external onlyOwner {
        merkleRoot = "";
        emit setMerkleRootEvent(merkleRoot);
    }

    /**
     * @notice Change the merkleRoot of the giveaway.
     *
     * @param newRoot. The new merkleRoot.
     */
    function setGiveAwayMerkleRoot(bytes32 newRoot) external onlyOwner {
        giveAwayMerkleRoot = newRoot;
        emit setGiveAwayMerkleRootEvent(newRoot);
    }

    /**
     * @notice Change the max supply for the giveaway.
     *
     * @param newSupply. The new giveaway max supply.
     */
    function setGiveAwayMaxSupply(uint256 newSupply) external onlyOwner {
        maxSupplyGiveaway = newSupply;
        emit setGiveAwayMaxSupplyEvent(newSupply);
    }    

    /**
     * @notice Change start time of the Phase One permissioned sale.
     *
     * @param newTime. The new time.
     */
    function setPhaseOneStartTime(uint256 newTime) external onlyOwner {
        phaseOneStartTime = newTime;
        emit setPhaseOneStartTimeEvent(newTime);
    }

    /**
     * @notice Change duration of the Phase One permissioned sale.
     *
     * @param newDuration. The new duration.
     */
    function setPhaseOneDuration(uint256 newDuration) external onlyOwner {
        phaseOneDuration = newDuration;
        emit setPhaseOneDurationEvent(newDuration);
    }

    /**
     * @notice Change start time of the Phase Two permissioned sale.
     *
     * @param newTime. The new time.
     */
    function setPhaseTwoStartTime(uint256 newTime) external onlyOwner {
        phaseTwoStartTime = newTime;
        emit setPhaseTwoStartTimeEvent(newTime);
    }

    /**
     * @notice Change duration of the Phase One permissioned sale.
     *
     * @param newDuration. The new duration.
     */
    function setPhaseTwoDuration(uint256 newDuration) external onlyOwner {
        phaseTwoDuration = newDuration;
        emit setPhaseTwoDurationEvent(newDuration);
    }

    /**
     * @notice Change start time of the open sale.
     *
     * @param newTime. The new time.
     */
    function setStartTimeOpen(uint256 newTime) external onlyOwner {
        startTimeOpen = newTime;
        emit setStartTimeOpenEvent(newTime);
    }

    /**
     * @dev FINANCE
     */

    /**
     * @notice Allows owner to withdraw funds generated from sale.
     *
     * @param _to. The address to send the funds to.
     */
    function withdrawAll(address _to) external onlyOwner {
        require(_to != address(0), "CANNOT WITHDRAW TO ZERO ADDRESS");

        uint256 contractBalance = address(this).balance;

        require(contractBalance > 0, "NO ETHER TO WITHDRAW");

        payable(_to).transfer(contractBalance);

        emit WithdrawAllEvent(_to, contractBalance);
    }

    /**
     * @dev Fallback function for receiving Ether
     */
    receive() external payable {
        emit ReceivedEther(msg.sender, msg.value);
    }
}