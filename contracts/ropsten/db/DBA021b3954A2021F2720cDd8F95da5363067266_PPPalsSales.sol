// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

import "@openzeppelin/contracts/access/Ownable.sol";
import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol"; 
import "@openzeppelin/contracts/finance/PaymentSplitter.sol";

contract IPPPals {
    /** ERC-721 INTERFACE */
    function ownerOf(uint256 tokenId) public view virtual returns (address) {}

    /** CUSTOM INTERFACE */
    function nextTokenId() public returns(uint256) {}
    function mintTo(uint256 amount, address _to) external {}
    function burn(uint256 tokenId) external {}
}

contract PPPalsSales is Ownable, PaymentSplitter {
    IPPPals public pppals;

    /** PAYMENT */
    address[] private _team = [0x618364d6041f6705CCcF35c288108a8446DE371D];
    uint256[] private _shares = [100];
    
    /** MINT OPTIONS */
    uint256 public maxSupply = 6363;  
    uint256 public maxMintsPerTx = 30;
    uint256 public minted = 0;

    /** FLAGS */
    bool public isSaleActive = false;
    bool public isFrozen = false;

    /** MAPPINGS  */
    mapping(address => uint256) public mintsPerAddress;

    /** BAMBOO */
    IERC20 public BAMBOO;
    uint256 public BAMBOOPrice = 10 * 10**18;

    /** MODIFIERS */
    modifier onlyHolder(uint256 tokenId) {
        require(pppals.ownerOf(tokenId) == _msgSender(), "SENDER IS NOT OWNER");
        _;
    }

    modifier notFrozen() {
        require(!isFrozen, "CONTRACT FROZEN");
        _;
    }

    modifier checkMintBAMBOO(uint256 amount) {
        require(amount > 0, "HAVE TO BUY AT LEAST 1");
        require(amount <= maxMintsPerTx, "CANNOT MINT MORE PER TX");
        require(minted + amount <= maxSupply, "MAX TOKENS MINTED");
        require(BAMBOO.allowance(msg.sender, address(this)) == BAMBOOPrice * amount, "TOKEN SENT NOT CORRECT");
        _;
    }

    constructor(
        address _pppalsaddress,
        address _BAMBOOAddress
    ) Ownable()
      PaymentSplitter(_team, _shares) {
        pppals = IPPPals(_pppalsaddress);
        BAMBOO = IERC20(_BAMBOOAddress);
    }

    /**
    * @dev override msgSender to allow for meta transactions on OpenSea.
    */
    function _msgSender()
        override
        internal
        view
        returns (address sender)
    {
        if (msg.sender == address(this)) {
            bytes memory array = msg.data;
            uint256 index = msg.data.length;
            assembly {
                // Load the 32 bytes word from memory with the address on the lower 20 bytes, and mask those.
                sender := and(
                    mload(add(array, index)),
                    0xffffffffffffffffffffffffffffffffffffffff
                )
            }
        } else {
            sender = payable(msg.sender);
        }
        return sender;
    }
 
    function mintWithBAMBOO(uint256 amount) external checkMintBAMBOO(amount) {
        minted = minted + amount;
        mintsPerAddress[_msgSender()] = mintsPerAddress[_msgSender()] + amount;
        BAMBOO.transferFrom(msg.sender, address(this), BAMBOOPrice * amount);
        pppals.mintTo(amount, _msgSender());
    }

    /** OWNER */

    function freezeContract() external onlyOwner {
        isFrozen = true;
    }

     /**
     * @dev flips the sale state either
     * allowing or disallowing mints to happen.
     * Only owner can call this function.
     */
    function flipSaleState() external onlyOwner notFrozen {
        isSaleActive = !isSaleActive;
    }

    function setpppals(address _pppalsAddress) external onlyOwner notFrozen {
        pppals = IPPPals(_pppalsAddress);
    }

    function setBAMBOO(address _BAMBOOAddress) external onlyOwner notFrozen {
        BAMBOO = IERC20(_BAMBOOAddress);
    }

    function setMaxSupply(uint256 newMaxSupply) external onlyOwner notFrozen {
        maxSupply = newMaxSupply;
    }

    function setBAMBOOPrice(uint256 newMintPrice) external onlyOwner notFrozen {
        BAMBOOPrice = newMintPrice;
    }  

    /**
     * @dev allows the owner of the sales contract or the owner
     * of the pppals to burn their pppals.
     */
    function burn(uint256 tokenId) external onlyOwner {
        pppals.burn(tokenId);
    }

    function withdrawAll() external onlyOwner {
        release(payable(_team[0]));
    }

    function withdrawAllBAMBOO() external onlyOwner {
        release(BAMBOO, _team[0]);
    }
}