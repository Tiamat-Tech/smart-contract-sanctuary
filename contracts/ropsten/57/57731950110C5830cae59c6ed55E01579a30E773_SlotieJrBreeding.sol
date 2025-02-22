// SPDX-License-Identifier: MIT
// Developed by KG Technologies (https://kgtechnologies.io)

pragma solidity 0.8.11;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

/**
 * @notice Represents Slotie Smart Contract
 */
contract ISlotie {
    /** 
     * @dev ERC-721 INTERFACE 
     */
    function ownerOf(uint256 tokenId) public view virtual returns (address) {}

    /** 
     * @dev CUSTOM INTERFACE 
     */
    function mintTo(uint256 amount, address _to) external {}
}

contract ISlotieJr {
    /** 
     * @dev ERC-721 INTERFACE 
     */
    function ownerOf(uint256 tokenId) public view virtual returns (address) {}
    function totalSupply() public view returns (uint256) {}

    /** 
     * @dev CUSTOM INTERFACE 
     */
    function mintTo(uint256 amount, address _to) external {}
    function maxMintPerTransaction() public returns (uint256) {}
}

abstract contract IWatts is IERC20 {
    function burn(address _from, uint256 _amount) external {}
}

/**
 * @title SlotieJrBreeding.
 *
 * @author KG Technologies (https://kgtechnologies.io).
 *
 * @notice This Smart Contract can be used to breed Slotie NFTs.
 *
 * @dev The primary mode of verifying permissioned actions is through Merkle Proofs
 * which are generated off-chain.
 */
contract SlotieJrBreeding is Ownable {

    /** 
     * @notice The Smart Contract of Slotie
     * @dev ERC-721 Smart Contract 
     */
    ISlotie public immutable slotie;

    /** 
     * @notice The Smart Contract of Slotie Jr.
     * @dev ERC-721 Smart Contract 
     */
    ISlotieJr public immutable slotiejr;

    /** 
     * @notice The Smart Contract of Watts.
     * @dev ERC-20 Smart Contract 
     */
    IWatts public immutable watts;
    
    /** 
     * @dev BREED DATA 
     */
    uint256 public maxBreedableJuniors = 5000;
    bool public isBreedingStarted = false;
    uint256 public breedPrice = 1800 ether;    
    uint256 public breedCoolDown = 2 * 30 days;
    
    mapping(uint256 => uint256) public slotieToLastBreedTimeStamp;  

    /// @dev Initial value is randomly generated from https://www.random.org/
    bytes32 public merkleRoot = 0xe788a23866da0e903934d723c44efe9da3f7265d053a8fed5c1036a78665f9c1;

    /**
     * @dev TRACKING DATA
     */
    uint256 public bornJuniors;

    /**
     * @dev Events
     */
    event ReceivedEther(address indexed sender, uint256 indexed amount);
    event Bred(address initiator, uint256 indexed father, uint256 indexed mother, uint256 indexed slotieJr);
    event setMerkleRootEvent(bytes32 indexed root);
    event setIsBreedingStartedEvent(bool indexed started);
    event setMaxBreedableJuniorsEvent(uint256 indexed maxMintable);
    event setBreedCoolDownEvent(uint256 indexed coolDown);
    event setBreedPriceEvent(uint256 indexed price);
    event WithdrawAllEvent(address indexed recipient, uint256 amount);

    constructor(
        address slotieAddress,
        address slotieJrAddress,
        address wattsAddress
    ) Ownable() {
        slotie = ISlotie(slotieAddress);
        slotiejr = ISlotieJr(slotieJrAddress);
        watts = IWatts(wattsAddress);
    }
 
    /**
     * @dev BREEDING
     */

    function breed(
        uint256 father, 
        uint256 mother, 
        uint256 fatherStart, 
        uint256 motherStart, 
        bytes32[] calldata fatherProof, 
        bytes32[] calldata motherProof
    ) external {
        require(address(slotie) != address(0), "SLOTIE NFT NOT SET");
        require(address(slotiejr) != address(0), "SLOTIE JR NFT NOT SET");
        require(address(watts) != address(0), "WATTS NOT SET");
        require(bornJuniors < maxBreedableJuniors, "MAX JUNIORS HAVE BEEN BRED");
        require(father != mother, "CANNOT BREED THE SAME SLOTIE");
        require(slotie.ownerOf(father) == msg.sender, "SENDER NOT OWNER OF FATHER");    
        require(slotie.ownerOf(mother) == msg.sender, "SENDER NOT OWNER OF MOTHER");

        uint256 fatherLastBred = slotieToLastBreedTimeStamp[father];
        uint256 motherLastBred = slotieToLastBreedTimeStamp[mother];

        /**
         * @notice Check if father can breed based based on time logic
         *
         * @dev If father hasn't bred before we check the merkle proof to see
         * if it can breed already. If it has bred already we check if it's passed the
         * cooldown period.
         */ 
        if (fatherLastBred == 0) {
            bytes32 leafFather = keccak256(abi.encodePacked(father, fatherStart, fatherLastBred));
            require(MerkleProof.verify(fatherProof, merkleRoot, leafFather), "INVALID PROOF FOR FATHER");
            require(block.timestamp >= fatherStart, "FATHER CANNOT BREED YET");
        } else {
            require(block.timestamp >= fatherLastBred + breedCoolDown, "FATHER IS STILL IN COOLDOWN");
        }

        /// @dev see father.
        if (motherLastBred == 0) {
            bytes32 leafMother = keccak256(abi.encodePacked(mother, motherStart, motherLastBred));
            require(MerkleProof.verify(motherProof, merkleRoot, leafMother), "INVALID PROOF FOR MOTHER"); 
            require(block.timestamp >= motherStart, "MOTHER CANNOT BREED YET");
        } else {
            require(block.timestamp >= motherLastBred + breedCoolDown, "MOTHER IS STILL IN COOLDOWN");
        }

        slotieToLastBreedTimeStamp[father] = block.timestamp;
        slotieToLastBreedTimeStamp[mother] = block.timestamp;
        bornJuniors++;

        require(watts.balanceOf(msg.sender) >= breedPrice, "SENDER DOES NOT HAVE ENOUGH WATTS");        
        watts.burn(msg.sender, breedPrice);

        slotiejr.mintTo(1, msg.sender);
        emit Bred(msg.sender, father, mother, slotiejr.totalSupply());
    }  

    /** 
     * @dev OWNER ONLY 
     */

    /**
     * @notice function to set the merkle root for breeding.
     *
     * @param _merkleRoot. The new merkle root to set.
     */
    function setMerkleRoot(bytes32 _merkleRoot) external onlyOwner {
        merkleRoot = _merkleRoot;
        emit setMerkleRootEvent(_merkleRoot);
    }

    /**
     * @notice function to turn on/off breeding.
     *
     * @param _status. The new state of the breeding.
     */
    function setBreedingStatus(bool _status) external onlyOwner {
        isBreedingStarted = _status;
        emit setIsBreedingStartedEvent(_status);
    }    

    /**
     * @notice function to set the maximum amount of juniors that can be bred.
     *
     * @param max. The new maximum.
     */
    function setMaxBreedableJuniors(uint256 max) external onlyOwner {
        maxBreedableJuniors = max;
        emit setMaxBreedableJuniorsEvent(max);
    }

    /**
     * @notice function to set the cooldown period for breeding a slotie.
     *
     * @param coolDown. The new cooldown period.
     */
    function setBreedCoolDown(uint256 coolDown) external onlyOwner {
        breedCoolDown = coolDown;
        emit setBreedCoolDownEvent(coolDown);
    }

    /**
     * @notice function to set the watts price for breeding two sloties.
     *
     * @param price. The new watts price.
     */
    function setBreedPice(uint256 price) external onlyOwner {
        breedPrice = price;
        emit setBreedPriceEvent(price);
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