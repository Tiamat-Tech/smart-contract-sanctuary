// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./ERC20Changeable.sol";

contract TLD is ERC20Changeable {
  using SafeMath for uint256;
  
  address private _owner;
  uint256 private MINT_UNIT = 1;
  uint256 private _basePrice = 0;
  uint256 public payToAdminPart = 0;
  address public admin;
  mapping(address=>uint256) migratedTlds;
  ERC20Changeable public previousTldAddress;
  event Skimmed(address destinationAddress, uint256 amount);
  constructor() ERC20Changeable("Domain Name Community Token", ".TLD") {
    _owner = msg.sender;
    admin = msg.sender;
  }
      
  function unit() public view returns (uint256) {
    return MINT_UNIT.mul(10 ** decimals());
  }
  function owner() public view virtual returns (address) {
    return _owner;
  }
  function payableOwner() public view virtual returns(address payable){
    return payable(_owner);
  }
    
  function decimals() public view virtual override returns (uint8) {
    return 8;
  }
  function totalAvailableEther() public view returns (uint256) {
    return address(this).balance;
  }
  function basePrice() public view returns (uint256){
    return _basePrice;
  }
  /*
    errors: TLD: O - Caller is not owner
  */
  modifier onlyOwner() {
    require(owner() == msg.sender || admin == msg.sender, "TLD: O");
    _;
  }

  function init(uint256 initialSupply, uint256 basePrice_, uint256 payToAdminPart_) public payable onlyOwner{
    _basePrice = basePrice_;
    payToAdminPart = payToAdminPart_;
    _mint(msg.sender, initialSupply);
  }
  function changeSymbol(string memory symbol_) public onlyOwner{
    _symbol = symbol_;
  }
  function changeName(string memory name_) public onlyOwner{
    _name = name_;
  }

  function setAdmin(address _admin) public onlyOwner {
    admin = _admin;
  }
  
  function setToOwnerPart(uint256 _number) public onlyOwner {
    payToAdminPart = _number;
  }
  
  function setPreviousTldAddress(ERC20Changeable _address) public onlyOwner{
    previousTldAddress = _address;
  }
  function setBasePrice(uint256 _price) public onlyOwner {
    _basePrice = _price;
  }
  /*
    Errors: TLD: B1 - not enough payment value sent with the transaction
  */
  function buy(uint256 wholeUnitsAmount) public payable {
    require(msg.value >= basePrice().mul(wholeUnitsAmount), "TLD: B1");
    if(payToAdminPart > 0){
      uint256 amountToAdmin = msg.value.div(payToAdminPart);
      if(amountToAdmin > 0){
        payable(admin).transfer(amountToAdmin);
      }
    }
    _mint(msg.sender, unit().mul(wholeUnitsAmount));
  }
    
  function overflow() public view returns (uint256){
    return address(this).balance;
  }
  /*
    errors:
TLD: TO1 - new owner address must be non zero address
*/
  function transferOwnership(address newOwner) public onlyOwner returns(address){
    require(newOwner != address(0), "TLD: TO1");
    _owner = newOwner;
    return _owner;
  }
  
  function rprice(uint256 reservedId) public view returns(uint256){
    return reservedId.mul(basePrice());
  }
  
  function mint(uint256 reservedId) payable public onlyOwner returns (uint256){
    require(msg.value >= rprice(reservedId), "TLD: MV");
    _mint(msg.sender, unit());
    return unit();
  }

  function burn(uint256 unitsAmount) public returns(uint256){
    _burn(msg.sender, unitsAmount);
    return unitsAmount;
  }
  
  function skim(address destination) public onlyOwner returns (uint256){
      uint256 amountToSkim = overflow();
      if(amountToSkim > 0){
          if(payable(destination).send(amountToSkim)){
              emit Skimmed(destination, amountToSkim);
          }
      }
      return amountToSkim;
  }

  /*
    errors
   TLD: M1 - unknown token address to migrate from
   TLD: M2 - no allowance set from previous token to this contract
   TLD: M3 - no balance to migrate
  */
  function migrate() public {
    require(address(previousTldAddress) != address(0), "TLD: M1");
    require(previousTldAddress.allowance(msg.sender, address(this)) > 0, "TLD: M2");
    require(previousTldAddress.balanceOf(msg.sender) > 0, "TLD: M3");
    uint256 amountToMigrate = previousTldAddress.allowance(msg.sender, address(this));
    if(previousTldAddress.balanceOf(msg.sender) < amountToMigrate){
      amountToMigrate = previousTldAddress.balanceOf(msg.sender);
    }
    if(amountToMigrate > 0){
      previousTldAddress.transferFrom(msg.sender, address(0), amountToMigrate);
      _mint(msg.sender, amountToMigrate);
    }
  }
  
  receive() external payable {
      
  }

}