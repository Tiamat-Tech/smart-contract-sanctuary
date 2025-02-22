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

contract PortalNft is ERC1155Bouncer {
  uint256 public activelyMintingNft = 0;
  uint256 public maxSupply = 7777;
  uint256 public mintPrice = 0.069 ether; // 420

  // Jan 4th, 4:30pm
  uint256 public publicMintTime = 1641349800;

  // Bouncer that only let's in pre-approved members
  string private constant SIGNING_DOMAIN = "TheNifty";
  string private constant SIGNATURE_VERSION = "1";

  // Caps on mints
  mapping(uint256 => mapping(address => uint256)) public premintTxs;
  mapping(uint256 => mapping(address => uint256)) public walletTxs;

  event Printed(uint256 indexed index, address indexed account, uint256 amount);

  constructor(
    string memory _name,
    string memory _symbol,
    string memory _uri
  ) ERC1155(_uri) EIP712(SIGNING_DOMAIN, SIGNATURE_VERSION) {
    name_ = _name;
    symbol_ = _symbol;

    // Send community & team NFTs to The Nifty NFT wallet
    _mint(0xb75D95FB8bC0FC8e156a8fd1d9669be94160c11F, 0, 100, "");
  }

  /**
  * @notice withdraw balance
  *
  * @param _addr the address we are sending the CAYYYYYYUSH to
  */
  function withdraw(address _addr) external onlyOwner {
    uint256 balance = address(this).balance;
    (bool sent, bytes memory data) = _addr.call{value: balance}("");
    require(sent, "Failed to send Ether");
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
  }

  /**
  * @notice early minting
  *
  * @param voucher the voucher used to claim
  * @param numberOfTokens how many they'd like to mint
  */
  function voucherMint(NFTVoucher calldata voucher, uint numberOfTokens) external payable {
    require(premintTxs[activelyMintingNft][msg.sender] < 1 , "wallet mint limit");
    address signer = _verify(voucher);
    require(hasRole(BOUNCER_ROLE, signer), "signature invalid");
    require(numberOfTokens <= voucher.mintLimit, "invalid mint count");
    require(msg.sender == voucher.minter, "invalid voucher");
    require(totalSupply(activelyMintingNft) + numberOfTokens <= maxSupply, "supply exceeded");
    require(block.timestamp >= voucher.start, "invalid mint time");
    
    premintTxs[activelyMintingNft][msg.sender] += 1;
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
  function publicMint(uint numberOfTokens) external payable {
    require(block.timestamp >= publicMintTime, "public mint close");
    require(walletTxs[activelyMintingNft][msg.sender] < 2 , "wallet mint limit");
    // TODO: require that the contract is not paused
    require(numberOfTokens > 0 && numberOfTokens <= 10, "max 10 nfts per txn");

    // Limited transactions per wallet on public mint
    walletTxs[activelyMintingNft][msg.sender] += 1;
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

    _mint(msg.sender, 0, amount, "");
    emit Printed(0, msg.sender, amount);
  }
}