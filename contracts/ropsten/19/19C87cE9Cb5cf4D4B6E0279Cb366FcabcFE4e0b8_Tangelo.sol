pragma solidity 0.8.0;

//SPDX-License-Identifier: MIT
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "hardhat/console.sol";
import "@openzeppelin/contracts/access/Ownable.sol"; //https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol

contract Tangelo is ERC20, IERC721Receiver, Ownable {


  uint256 vaultCap = 500 ether;
  uint256 loanDuration = 7 days; 
  uint256 pricePerShare = 1 ether; // ETH per Tangelo LP Share
  uint256 vaultBalance;
  uint256 vaultBalanceAvailable;

  struct NFTLoan {
    address nftOwner;
    uint256 loanPrincipal;
    uint256 loanInterestAmount;
    uint256 dueDate;
  }

  mapping (address => uint256) collectionLendingPrice; // Enabled collections map address to price
  mapping (address => uint256) collectionInterestRate; // Interest rate per 7 day lending period, 100 represents 1% interest
  mapping (address => mapping (uint256 => NFTLoan)) lockedNFTs; // Map the NFT collection address to token ID to the owner 
  mapping (address => uint256) outstandingLoans; // Maps borrower to outstanding balance
  mapping(address => uint256) deposits; // Map lender to amount
  address[] depositors;
  address[] borrowers;
  address[] collections; // whitelisted NFT collections
  address foreclosureContract;


    constructor() ERC20("TANGELOLP", "TLP") public {
      
    }

  // Borrower functions -----
  function takeLoan(address nftContractAddress, uint256 tokenId) public {
    IERC721 nftContract = IERC721(nftContractAddress);
    require(collectionLendingPrice[nftContractAddress] > 0, "NFT collection not supported yet");
    uint loanPrincipal = getLoanAmountForCollection(nftContractAddress);
    uint loanInterest = getInterestAmountForCollection(nftContractAddress);
    require(loanPrincipal <= vaultBalanceAvailable, "Not enough funds in vault to cover this loan");
    nftContract.safeTransferFrom(msg.sender, address(this), tokenId);
    lockedNFTs[nftContractAddress][tokenId] = NFTLoan(msg.sender, loanPrincipal, loanInterest, block.timestamp + loanDuration);
    borrowers.push(msg.sender);
    vaultBalanceAvailable = vaultBalanceAvailable - loanPrincipal;
    payable(msg.sender).transfer(loanPrincipal);
  }

  function repayLoanForNFT(address nftContractAddress, uint256 tokenId) payable public {
      // repay loan and get NFT back if fully repaid
      IERC721 nftContract = IERC721(nftContractAddress);
      NFTLoan memory loan = lockedNFTs[nftContractAddress][tokenId];
      require(loan.nftOwner == msg.sender, "Caller must be the one who deposited this NFT");
      require(msg.value == loan.loanPrincipal + loan.loanInterestAmount, "Send the correct amount");
      pricePerShare = pricePerShare + pricePerShare * loan.loanInterestAmount / vaultBalance;
      vaultBalance = vaultBalance + loan.loanInterestAmount;
      vaultBalanceAvailable = vaultBalanceAvailable + loan.loanPrincipal + loan.loanInterestAmount;
      nftContract.safeTransferFrom(address(this), msg.sender, tokenId);
      delete lockedNFTs[nftContractAddress][tokenId];
  }

  // Lender vault functions -----
  function depositFunds() payable public {
    require(msg.value > 0, "Must deposit positive amount");
    require(msg.value + vaultBalance <= vaultCap, "Vault cap exceeded");
    depositors.push(msg.sender);
    vaultBalance = vaultBalance + msg.value;
    vaultBalanceAvailable = vaultBalanceAvailable + msg.value;
    uint256 shares = 1 ether * msg.value / pricePerShare ;
    _mint(msg.sender, shares);
  }

  function withdrawFunds(uint amountRequested) public {
    uint256 amountAvailableForUser = getAmountAvailableToWithdraw(msg.sender);
    require(amountRequested <= amountAvailableForUser, "Not enough funds to withdraw");
    require(amountRequested <= vaultBalance, "Vault out of money");
    uint256 shares = 1 ether * amountRequested / pricePerShare;
    _burn(msg.sender, shares);
    vaultBalance = vaultBalance - amountRequested;
    vaultBalanceAvailable = vaultBalanceAvailable - amountRequested;
    
    payable(msg.sender).transfer(amountRequested);
  }
  
  // Admin functions ----
  function setCap(uint cap) public onlyOwner {
    vaultCap = cap;
  }
  function setLoanDuration(uint duration) public onlyOwner {
    loanDuration = duration;
  } 
  function setForeclosureContract(address foreclosureContract) public onlyOwner {
    foreclosureContract = foreclosureContract;
  }
  function whitelistCollection(address collectionAddress, uint lendingPrice, uint interestRatePercent) public onlyOwner {
    collections.push(collectionAddress);
    collectionLendingPrice[collectionAddress] = lendingPrice;
    collectionInterestRate[collectionAddress] = interestRatePercent;
  }
  function foreclose(address nftContractAddress, uint256 tokenId, address foreclosureHandler)  public onlyOwner {
    NFTLoan memory loan = lockedNFTs[nftContractAddress][tokenId];
    require(lockedNFTs[nftContractAddress][tokenId].dueDate < block.timestamp, "Cannot foreclose yet");
    IERC721 nftContract = IERC721(nftContractAddress);
    nftContract.safeTransferFrom(address(this), foreclosureHandler, tokenId);
    pricePerShare = pricePerShare - (pricePerShare * loan.loanPrincipal / vaultBalance);
    vaultBalance = vaultBalance - loan.loanPrincipal;
    delete lockedNFTs[nftContractAddress][tokenId];
  }
  function setPricePerShare(uint256 price) public onlyOwner {
    pricePerShare = price;
  }
  // End admin functions ----

  // Getters -----
  function getWhitelistedCollections() public view returns (address[] memory) {
    return collections;
  }
  function getLoanAmountForCollection(address collectionAddress) public view returns (uint256) {
    return collectionLendingPrice[collectionAddress];
  }
  function getInterestRateForCollection(address collectionAddress) public view returns (uint256) {
    return collectionInterestRate[collectionAddress];
  }
   function getInterestAmountForCollection(address nftContractAddress) public returns (uint256) {
    return uint256(getLoanAmountForCollection(nftContractAddress) * collectionInterestRate[nftContractAddress] / 10000);
  }
  function getAllDepositors() public view returns (address[] memory) {
    return depositors;
  }
  function getDepositsForLender(address lender) public view returns (uint256) {
    return deposits[lender];
  }
  function getVaultCap() public view returns (uint256) {
    return vaultCap;
  }
  function getVaultBalance() public view returns (uint256) {
    return vaultBalance;
  }
  function getOwnerForLockedNFT(address nftContractAddress, uint256 tokenId) public view returns (address) {
    return lockedNFTs[nftContractAddress][tokenId].nftOwner;
  }
  function getLoanDueDateforLockedNFT(address nftContractAddress, uint256 tokenId) public view returns (uint256) {
    return lockedNFTs[nftContractAddress][tokenId].dueDate;
  }
  function getLoanAmountForLockedNFT(address nftContractAddress, uint256 tokenId) public view returns (uint256) {
    return lockedNFTs[nftContractAddress][tokenId].loanPrincipal;
  }
   function getLoanInterestAmountForLockedNFT(address nftContractAddress, uint256 tokenId) public view returns (uint256) {
    return lockedNFTs[nftContractAddress][tokenId].loanInterestAmount;
  }
  function getPricePerShare() public view returns (uint256) {
    return pricePerShare;
  }
  function getAmountAvailableToWithdraw(address addr) public view returns (uint256) {
    return balanceOf(addr) * pricePerShare / 1 ether;
  }
  // Override functions -----
    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data) external override returns (bytes4) {
      return bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"));
    }
}