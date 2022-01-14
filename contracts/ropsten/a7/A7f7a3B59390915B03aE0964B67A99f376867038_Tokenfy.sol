// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "./ERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// .___________.  ______    __  ___  _______ .__   __.  ___________    ____ 
// |           | /  __  \  |  |/  / |   ____||  \ |  | |   ____\   \  /   / 
// `---|  |----`|  |  |  | |  '  /  |  |__   |   \|  | |  |__   \   \/   /  
//     |  |     |  |  |  | |    <   |   __|  |  . `  | |   __|   \_    _/   
//     |  |     |  `--'  | |  .  \  |  |____ |  |\   | |  |        |  |     
//     |__|      \______/  |__|\__\ |_______||__| \__| |__|        |__|     

contract Tokenfy is ERC20, EIP712, Ownable {
    
    // initial max supply
    uint256 public constant INITIAL_MAX_SUPPLY = uint256(1e9 ether);

    // for staking
    uint256 public constant STAKING_AMOUNT = INITIAL_MAX_SUPPLY / 100 * 20;
    address public constant STAKING_ADDRESS = 0xE11F399Ee8C7788B5B1E25E3762cf073594663FE;

    // for LP
    uint256 public constant LP_AMOUNT = INITIAL_MAX_SUPPLY / 100 * 10;
    address public constant LP_ADDRESS = 0xFe41F9C3FbEdD9c91aA3a832Daa0523B4c0E9eB3;

    // for platform development and marketing
    uint256 public constant TREASURY_AMOUNT = INITIAL_MAX_SUPPLY / 100 * 5;
    address public constant TREASURY_ADDRESS = 0xb8C94Ec82b5A2E004d34C7Cb7b2A657D8118E496;

    // for team
    uint256 public constant TEAM_AMOUNT = INITIAL_MAX_SUPPLY / 100 * 5;
    address public constant TEAM_ADDRESS = 0x9c3154807Df6a66FEa8518580DF68d468ffc0155;

    // for advisors
    uint256 public constant ADVISORS_AMOUNT = INITIAL_MAX_SUPPLY / 100 * 5;
    address public constant ADVISORS_ADDRESS = 0x6c35BBAD5254765BbE7E3bce116531b3BDAC7927;

    // for referrals
    uint256 public constant REFERRALS_AMOUNT = INITIAL_MAX_SUPPLY / 100 * 5;

    // for free claim
    uint256 public constant AIRDROP_AMOUNT = INITIAL_MAX_SUPPLY - (STAKING_AMOUNT + LP_AMOUNT + TREASURY_AMOUNT + TEAM_AMOUNT + ADVISORS_AMOUNT + REFERRALS_AMOUNT);

    // current max token supply
    uint256 public maxSupply = INITIAL_MAX_SUPPLY;

    // claimed airdrop statuses
    mapping (address => bool) public claimed;

    // amount signer
    address public immutable signerAddress;

    // is free claim now live
    bool public claimLive = false;
    uint256 public claimedAmount = 0;
    uint256 public rewardsAmount = 0;

    // has minted to incubator fund
    bool public incubatorMint = false;

    bytes32 constant public MINT_CALL_HASH_TYPE = keccak256("mint(address receiver,uint256 amount)");

    constructor(
        string memory _name, 
        string memory _symbol, 
        address _signerAddress,
        address stakingFeeAddress_,
        address LPFeeAddress_,
        address DAOFeeAddess_,
        address operationsFeeAddress_
    ) ERC20(_name, _symbol, stakingFeeAddress_, LPFeeAddress_, DAOFeeAddess_, operationsFeeAddress_) EIP712("Tokenfy", "1") {
        _mint(STAKING_ADDRESS, STAKING_AMOUNT);
        _mint(LP_ADDRESS, LP_AMOUNT);
        _mint(TREASURY_ADDRESS, TREASURY_AMOUNT);
        _mint(TEAM_ADDRESS, TEAM_AMOUNT);
        _mint(ADVISORS_ADDRESS, ADVISORS_AMOUNT);
        
        signerAddress = _signerAddress;
    }

    /**
    * @dev mints free claim tokens and referral rewards
    * Referrals must claim to receive rewards from invitees
    */
    function claim(uint256 amountV, bytes32 r, bytes32 s, address referral) external {
        require(claimLive, "Tokenfy: claim is not live");

        uint256 amount = uint248(amountV);
        uint8 v = uint8(amountV >> 248);
        uint256 total = totalSupply() + amount;
        require(total <= maxSupply, "Tokenfy: > max supply");
        require(!claimed[msg.sender], "Tokenfy: Already claimed");
        require(signerValid(v, r, s, msg.sender, amount, referral), "Tokenfy: Invalid signer");
        
        claimed[msg.sender] = true;
        _mint(msg.sender, amount);
        claimedAmount += amount;

        if (referral != address(0) && claimed[referral]) {
            uint256 reward = amount / 10;
            _mint(referral, reward);
            rewardsAmount += reward;
        }
    }

    /**
    * @dev checks signature validity
    */
    function signerValid(uint8 v, bytes32 r, bytes32 s, address sender, uint256 amount, address referral) private view returns (bool) {
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19Ethereum Signed Message:\n32", 
                keccak256(
                    abi.encode(
                        ECDSA.toTypedDataHash(
                            _domainSeparatorV4(),
                            keccak256(
                                abi.encode(MINT_CALL_HASH_TYPE, sender, amount)
                            )
                        )
                )
            ), referral)
        );
        return ecrecover(digest, v, r, s) == signerAddress;
    }

    /**
    * @dev decreases max supply of the token
    */
    function decreaseMaxSupply(uint256 newSupply) external onlyOwner {
        require(newSupply >= totalSupply(), "Tokenfy: < total supply");
        require(newSupply < maxSupply, "Tokenfy: >= max supply");

        maxSupply = newSupply;
    }

    /**
    * @dev starts/stops free claim
    */
    function setClaimLive(bool live) external onlyOwner {
        claimLive = live;
    }

    /**
    * @dev changes addresses that receive fees on transfer
    */
    function setTransferFeesAddresses(
        address stakingAddress_,
        address LPAddress_,
        address DAOAddess_,
        address operationsAddress_
    ) external onlyOwner {
        _stakingAddress = stakingAddress_;
        _LPAddress = LPAddress_;
        _DAOAddess = DAOAddess_;
        _operationsAddress = operationsAddress_;
    }

    /**
    * @dev transfers unclaimed tokens to the incubation fund
    */
    function transferToIncubationFund(address fund) external onlyOwner {
        require(!claimLive, "Tokenfy: claim is live");
        require(!incubatorMint, "Tokenfy: already transferred");
        uint256 remainingTokens = AIRDROP_AMOUNT + REFERRALS_AMOUNT - claimedAmount - rewardsAmount;

        _mint(fund, remainingTokens);
        incubatorMint = true;
    }

}