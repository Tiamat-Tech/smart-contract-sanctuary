pragma solidity ^0.8.0;

import "hardhat/console.sol";

/*
* @title ERC1155 token for The Nifty Portal
* @author NFTNick.eth
*/

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                                                                                              //
//   NNNNNNNN        NNNNNNNN   iiii      ffffffffffffffff            tttt                                      //
//   N:::::::N       N::::::N  i::::i    f::::::::::::::::f        ttt:::t                                      //
//   N::::::::N      N::::::N   iiii    f::::::::::::::::::f       t:::::t                                      //
//   N:::::::::N     N::::::N           f::::::fffffff:::::f       t:::::t                                      //
//   N::::::::::N    N::::::N iiiiiii   f:::::f       ffffff ttttttt:::::tttttttyyyyyyy           yyyyyyy       //
//   N:::::::::::N   N::::::N i:::::i   f:::::f              t:::::::::::::::::t y:::::y         y:::::y        //
//   N:::::::N::::N  N::::::N  i::::i  f:::::::ffffff        t:::::::::::::::::t  y:::::y       y:::::y         //
//   N::::::N N::::N N::::::N  i::::i  f::::::::::::f        tttttt:::::::tttttt   y:::::y     y:::::y          //
//   N::::::N  N::::N:::::::N  i::::i  f::::::::::::f              t:::::t          y:::::y   y:::::y           //
//   N::::::N   N:::::::::::N  i::::i  f:::::::ffffff              t:::::t           y:::::y y:::::y            //
//   N::::::N    N::::::::::N  i::::i   f:::::f                    t:::::t            y:::::y:::::y             //
//   N::::::N     N:::::::::N  i::::i   f:::::f                    t:::::t    tttttt   y:::::::::y              //
//   N::::::N      N::::::::N i::::::i f:::::::f                   t::::::tttt:::::t    y:::::::y               //
//   N::::::N       N:::::::N i::::::i f:::::::f                   tt::::::::::::::t     y:::::y                //
//   N::::::N        N::::::N i::::::i f:::::::f                     tt:::::::::::tt    y:::::y                 //
//   NNNNNNNN         NNNNNNN iiiiiiii fffffffff                       ttttttttttt     y:::::y                  //
//                                                                                    y:::::y                   //                                                                                                                                                                                                                                                                                                                                                                                                                                                       
//   PPPPPPPPPPPPPPPPP                                                tttt           y:::::y          lllllll   // 
//   P::::::::::::::::P                                            ttt:::t          y:::::y           l:::::l   // 
//   P::::::PPPPPP:::::P                                           t:::::t         y:::::y            l:::::l   // 
//   PP:::::P     P:::::P                                          t:::::t        yyyyyyy             l:::::l   // 
//     P::::P     P:::::P  ooooooooooo   rrrrr   rrrrrrrrr   ttttttt:::::ttttttt      aaaaaaaaaaaaa    l::::l   // 
//     P::::P     P:::::Poo:::::::::::oo r::::rrr:::::::::r  t:::::::::::::::::t      a::::::::::::a   l::::l   // 
//     P::::PPPPPP:::::Po:::::::::::::::or:::::::::::::::::r t:::::::::::::::::t      aaaaaaaaa:::::a  l::::l   // 
//     P:::::::::::::PP o:::::ooooo:::::orr::::::rrrrr::::::rtttttt:::::::tttttt               a::::a  l::::l   // 
//     P::::PPPPPPPPP   o::::o     o::::o r:::::r     r:::::r      t:::::t              aaaaaaa:::::a  l::::l   // 
//     P::::P           o::::o     o::::o r:::::r     rrrrrrr      t:::::t            aa::::::::::::a  l::::l   // 
//     P::::P           o::::o     o::::o r:::::r                  t:::::t           a::::aaaa::::::a  l::::l   // 
//     P::::P           o::::o     o::::o r:::::r                  t:::::t    tttttta::::a    a:::::a  l::::l   // 
//   PP::::::PP         o:::::ooooo:::::o r:::::r                  t::::::tttt:::::ta::::a    a:::::a l::::::l  //
//   P::::::::P         o:::::::::::::::o r:::::r                  tt::::::::::::::ta:::::aaaa::::::a l::::::l  //
//   P::::::::P          oo:::::::::::oo  r:::::r                    tt:::::::::::tt a::::::::::aa:::al::::::l  //
//   PPPPPPPPPP            ooooooooooo    rrrrrrr                      ttttttttttt    aaaaaaaaaa  aaaallllllll  //
//                                                                                                              //
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////

import './utils/ERC1155Bouncer.sol'; // Set up a bouncer at the Portal door for those VIPs!
// import '@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol';
// import '@openzeppelin/contracts/security/Pausable.sol';

contract PortalNft is ERC1155Bouncer {
  uint256 public activelyMintingNft = 0;
  uint256 public maxSupply = 5555;
  uint256 public mintPrice = 0.066 ether;
  uint public maxEarlyMint = 2;

  // Jan 4th, 10:30am EST -> 15:30 GMT
  uint256 public earlyMintTime = 1641328200;
  // Jan 4th, 12:30pm 
  uint256 public investorMintTime = 1641335400;
  // Jan 4th, 2:30pm
  uint256 public communityMintTime = 1641342600;
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
  * @param _earlyMintTime UNIX timestamp for purchasing window opening time
  * @param _investorMintTime UNIX timestamp for purchasing window close time
  * @param _communityMintTime UNIX timestamp for early access window opening time
  * @param _publicMintTime UNIX timestamp for burn window opening time
  */
  function editMintTimes(
      uint256 _earlyMintTime,
      uint256 _investorMintTime,
      uint256 _communityMintTime,
      uint256 _publicMintTime
  ) external onlyOwner {
      require(
          _investorMintTime > _earlyMintTime &&
          _communityMintTime > _investorMintTime &&
          _publicMintTime > _communityMintTime,
          "invalid mint times"
      );

      earlyMintTime = _earlyMintTime;
      investorMintTime = _investorMintTime;
      communityMintTime = _communityMintTime;
      publicMintTime = _publicMintTime;

      // burnWindowOpens = _burnWindowOpens;
      // burnWindowCloses = _burnWindowCloses;
  }

  /**
  * @notice minting for early community members
  *
  * @param voucher the voucher used to claim this
  * @param numberOfTokens how many they'd like to mint
  */
  function earlyMint(NFTVoucher calldata voucher, uint numberOfTokens) public payable {
    require(totalSupply(0) + numberOfTokens <= 3433, "Early access: max supply reached");
    require(numberOfTokens <= maxEarlyMint, "You are not approved to mint this quantity");
    require(block.timestamp >= earlyMintTime && block.timestamp <= investorMintTime, "Community mint is closed.");
    require(voucher.mintPhase == 0, "You are not permitted during this phase");
    vipMint(voucher, numberOfTokens);
  }

  /**
  * @notice minting for our investors
  *
  * @param voucher the voucher used to claim this
  * @param numberOfTokens how many they'd like to mint
  */
  function investorMint(NFTVoucher calldata voucher, uint numberOfTokens) public payable {
    require(block.timestamp >= investorMintTime && block.timestamp <= communityMintTime, "Investor mint is closed.");
    require(voucher.mintPhase == 1, "You are not permitted during this phase");
    vipMint(voucher, numberOfTokens);
  }

  /**
  * @notice minting for second round of whitelist members
  *
  * @param voucher the voucher used to claim this
  * @param numberOfTokens how many they'd like to mint
  */
  function communityMint(NFTVoucher calldata voucher, uint numberOfTokens) public payable {
    require(totalSupply(0) + numberOfTokens <= maxSupply, "Fully supply minted");
    require(numberOfTokens <= maxEarlyMint, "You are not approved to mint this quantity");
    require(block.timestamp >= communityMintTime && block.timestamp <= publicMintTime, "Community mint is closed.");
    require(voucher.mintPhase == 2, "You are not permitted during this phase");
    vipMint(voucher, numberOfTokens);
  }

  /**
  * @notice minting which requires you to bypass the bouncer...
  *
  * @param voucher the voucher used to claim this
  * @param numberOfTokens how many they'd like to mint
  */
  function vipMint(NFTVoucher calldata voucher, uint numberOfTokens) private {
    require(walletTxs[msg.sender] < 1 , "You can only early mint once");
    address signer = _verify(voucher);
    require(hasRole(BOUNCER_ROLE, signer), "Signature invalid or unauthorized");
    require(msg.sender == voucher.minter, "This voucher is invalid for this address");
    require(numberOfTokens <= voucher.mintLimit, "You are not approved to mint this quantity");

    _issuePortalPasses(numberOfTokens);
    delete signer;
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