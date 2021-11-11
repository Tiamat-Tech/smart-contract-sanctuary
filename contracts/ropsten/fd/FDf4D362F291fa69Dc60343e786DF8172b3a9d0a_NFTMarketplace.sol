//SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import "./NFTCreature.sol";

contract NFTMarketplace is Ownable {

  uint256 public offerCount;
  mapping (uint => _Offer) public offers;
  mapping (address => uint) public userFunds;

  uint256 public fee;
  address bank;

  NFTCreature nftCollection;
  
  struct _Offer {
    uint offerId;
    uint tokenId;
    address user;
    uint price;
    bool fulfilled;
    bool cancelled;
  }

  event Offer(uint offerId, uint id, address user, uint price, bool fulfilled, bool cancelled);
  event OfferFilled(uint offerId, uint id, address newOwner);
  event OfferCancelled(uint offerId, uint id, address owner);
  event ClaimFunds(address user, uint amount);
  event ClaimBank(address user, uint amount);

  constructor(address _nftCollection) {
    nftCollection = NFTCreature(_nftCollection);
    fee = 5;
    bank = msg.sender;
  }

  function setFee(uint _fee) public onlyOwner {
    fee = _fee;
  }

  function setBank(address _bank) public onlyOwner {
    bank = _bank;
  }


  function makeOffer(uint _id, uint _price) public {
    nftCollection.transferFrom(msg.sender, address(this), _id);
    offerCount++;
    offers[offerCount] = _Offer(offerCount, _id, msg.sender, _price, false, false);
    emit Offer(offerCount, _id, msg.sender, _price, false, false);
  }

  function fillOffer(uint _offerId) public payable {
    _Offer storage _offer = offers[_offerId];
    require(_offer.offerId == _offerId, 'The offer must exist');
    require(_offer.user != msg.sender, 'The owner of the offer cannot fill it');
    require(!_offer.fulfilled, 'An offer cannot be fulfilled twice');
    require(!_offer.cancelled, 'A cancelled offer cannot be fulfilled');
    require(msg.value == _offer.price, 'The CLO amount should match with the NFT Price');
    nftCollection.transferFrom(address(this), msg.sender, _offer.tokenId);
    uint256 feeAmount = (msg.value/100) * fee;
    uint256 sellerAmount = msg.value - feeAmount;
    userFunds[bank] += feeAmount;
    _offer.fulfilled = true;
    userFunds[_offer.user] += sellerAmount;
    emit OfferFilled(_offerId, _offer.tokenId, msg.sender);
  }

  function cancelOffer(uint _offerId) public {
    _Offer storage _offer = offers[_offerId];
    require(_offer.offerId == _offerId, 'The offer must exist');
    require(_offer.user == msg.sender, 'The offer can only be canceled by the owner');
    require(_offer.fulfilled == false, 'A fulfilled offer cannot be cancelled');
    require(_offer.cancelled == false, 'An offer cannot be cancelled twice');
    nftCollection.transferFrom(address(this), msg.sender, _offer.tokenId);
    _offer.cancelled = true;
    emit OfferCancelled(_offerId, _offer.tokenId, msg.sender);
  }

  function claimBank() public {
    require(userFunds[bank] > 0, 'Bank empty');
    payable(bank).transfer(userFunds[bank]);
    emit ClaimBank(msg.sender, userFunds[bank]);
    userFunds[bank] = 0;    
  }

  function claimFunds() public {
    require(userFunds[msg.sender] > 0, 'This user has no funds to be claimed');
    payable(msg.sender).transfer(userFunds[msg.sender]);
    emit ClaimFunds(msg.sender, userFunds[msg.sender]);
    userFunds[msg.sender] = 0;    
  }

  function rescueNFT(address _nft,uint256 tokenId) public onlyOwner{
        require(_nft != address(nftCollection) , "Can't resque NFTCreature tokens, use cancelOffer");
        ERC721(_nft).transferFrom(address(this), msg.sender, tokenId);
  }

  function rescueToken(address _token, uint256 _amount) public onlyOwner{
        IERC20(_token).transfer(msg.sender, _amount);
  }

  // Fallback: reverts if Ether is sent to this smart-contract by mistake
  fallback () external {
    revert();
  }
}