pragma solidity ^0.8.0;

// import "hardhat/console.sol";

/*
* @title ERC1155 token for The Nifty Portal
* @author NFTNick.eth
*/

////////////////////////////////////////////////////////////////////////////
//                                                                        //
//    ________   ___  ________ _________    ___    ___                    //
//   |\   ___  \|\  \|\  _____\\___   ___\ |\  \  /  /|                   //
//   \ \  \\ \  \ \  \ \  \__/\|___ \  \_| \ \  \/  / /                   //   
//    \ \  \\ \  \ \  \ \   __\    \ \  \   \ \    / /                    //   
//     \ \  \\ \  \ \  \ \  \_|     \ \  \   \/  /  /                     //  
//      \ \__\\ \__\ \__\ \__\       \ \__\__/  / /                       //  
//       \|__| \|__|\|__|\|__|        \|__|\___/ /                        //     
//                                        \|___|/                         //
//    ________  ________  ________  _________  ________  ___              //
//    |\   __  \|\   __  \|\   __  \|\___   ___\\   __  \|\  \            //
//    \ \  \|\  \ \  \|\  \ \  \|\  \|___ \  \_\ \  \|\  \ \  \           //
//     \ \   ____\ \  \\\  \ \   _  _\   \ \  \ \ \   __  \ \  \          //
//      \ \  \___|\ \  \\\  \ \  \\  \|   \ \  \ \ \  \ \  \ \  \____     //
//       \ \__\    \ \_______\ \__\\ _\    \ \__\ \ \__\ \__\ \_______\   //
//        \|__|     \|_______|\|__|\|__|    \|__|  \|__|\|__|\|_______|   //
//                                                                        //
////////////////////////////////////////////////////////////////////////////

import './utils/ERC1155Bouncer.sol'; // Set up a bouncer at the Portal door for those VIPs!
// import '@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol';
// import '@openzeppelin/contracts/security/Pausable.sol';

contract PortalNft is ERC1155Bouncer {
  uint256 public activelyMintingNft = 0;
  uint256 public maxSupply = 5555;
  uint256 public mintPrice = 0.066 ether;
  uint public maxEarlyMint = 2;

  // Jan 4th, 4:30pm
  uint256 public publicMintTime = 1641349800;

  // Bouncer that only let's in pre-approved members
  string private constant SIGNING_DOMAIN = "TheNifty";
  string private constant SIGNATURE_VERSION = "1";

  // Caps on early mints
  mapping(address => uint256) public walletTxs;

  event Printed(uint256 indexed index, address indexed account, uint256 amount);

  constructor(
    string memory _name,
    string memory _symbol,
    string memory _uri
  ) ERC1155(_uri) EIP712(SIGNING_DOMAIN, SIGNATURE_VERSION) {
    name_ = _name;
    symbol_ = _symbol;

    // Send community NFTs to The Nifty wallet
    _mint(0xb75D95FB8bC0FC8e156a8fd1d9669be94160c11F, 0, 100, "");
  }

  /**
  * @notice edit the mint price
  *
  * @param _mintPrice the new price in wei
  */
  function setPrice(uint256 _mintPrice) external onlyOwner {
      mintPrice = _mintPrice;
  }

  /**
  * @notice edit windows
  *
  * @param _publicMintTime UNIX timestamp for burn window opening time
  */
  function editMintTimes(
      uint256 _publicMintTime
  ) external onlyOwner {
      publicMintTime = _publicMintTime;
      // burnWindowOpens = _burnWindowOpens;
      // burnWindowCloses = _burnWindowCloses;
  }

  /**
  * @notice early minting
  *
  * @param voucher the voucher used to claim this
  * @param numberOfTokens how many they'd like to mint
  */
  function voucherMint(NFTVoucher calldata voucher, uint numberOfTokens) public payable {
    require(walletTxs[msg.sender] < 1 , "You can only early mint once");
    address signer = _verify(voucher);
    require(hasRole(BOUNCER_ROLE, signer), "Signature invalid or unauthorized");
    require(numberOfTokens <= voucher.mintLimit, "Invalid mint count");
    require(msg.sender == voucher.minter, "This voucher is invalid for this address");
    require(totalSupply(0) + numberOfTokens <= voucher.phaseCap, "Max supply minted for this phase.");
    require(block.timestamp >= voucher.start &&  block.timestamp <= voucher.end, "Invalid mint time.");
    
    _issuePortalPasses(numberOfTokens);
  }

  /**
  * @notice special minting method only for contract owner
  *
  * @param addr the address these should be minted to
  * @param numberOfTokens how many to mint
  */
  function ownerMint(address addr, uint numberOfTokens) external onlyOwner {
    _mint(addr, 0, numberOfTokens, "");
    emit Printed(0, addr, numberOfTokens);
  }

  /**
  * @notice public mint phase
  *
  * @param numberOfTokens how many to mint
  */
  function publicMint(uint numberOfTokens) public payable {
    require(block.timestamp >= publicMintTime, "Public mint is not open");
    require(walletTxs[msg.sender] < 2 , "You can only mint twice");
    // TODO: require that the contract is not paused
    require(numberOfTokens > 0 && numberOfTokens <= 10, "Limit of 10 NFTs per transaction");

    _issuePortalPasses(numberOfTokens);
  }

  /**
  * @notice global function for issuing the portal passes (the core minting function)
  *
  * @param amount the amount of tokens to mint
  */
  function _issuePortalPasses(uint256 amount) private {
    require(totalSupply(0) + amount <= maxSupply, "Purchase: Max supply reached");
    require(msg.value == amount * mintPrice, "Purchase: Incorrect payment");

    // Limited transactions per wallet on pre-sale
    walletTxs[msg.sender] += 1;

    _mint(msg.sender, 0, amount, "");
    emit Printed(0, msg.sender, amount);
  }
}