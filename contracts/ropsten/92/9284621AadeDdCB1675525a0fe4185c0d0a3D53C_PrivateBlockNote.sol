pragma solidity ^0.8.0;


import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
 
import "@openzeppelin/contracts/access/AccessControl.sol";

import "@openzeppelin/contracts/security/Pausable.sol";

import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract PrivateBlockNote is  ERC20Capped, Pausable, AccessControl {
  
      using SafeERC20 for IERC20;
      using SafeMath for uint;
      using SafeMath for uint256;
      
      bytes32 public constant CREATOR = DEFAULT_ADMIN_ROLE;
      bytes32 public constant ADMIN = keccak256("ADMIN");
      
      
      bool public ICOActivated = false;

      uint256 public rate = 200000;
      uint256 constant public tokencap = 10**26; 
      uint256 public weiRaised = 0;


      address public creator;

      struct UltraPrivateNote{
          uint creationDate;
          address recipient;
          string content;
          bool exists;
      }

      struct PrivateNote{
        string content;
        bytes32 hashedKey;
      }
    
      mapping (uint => PrivateNote) public privateNotes;

      mapping (address => UltraPrivateNote[]) public ultraPrivateNotes;

      mapping (address => uint) public accountToNumberOfUltraSecureNotes;
      
      event TokenPurchase(address indexed _from, uint256 _weiRaised, uint256 _wei, uint256 _tokens);

      modifier onlyCreator(){
        require(hasRole(CREATOR, msg.sender));
        _;
      }

      modifier onlyAdmin(){
        require(hasRole(ADMIN, msg.sender) || hasRole(CREATOR, msg.sender));
        _;
      }

      constructor() ERC20Capped() ERC20("PrivateBlockNote", "PBN") {
          creator = msg.sender;
          _mint(msg.sender, tokencap/2);
          _setRoleAdmin(ADMIN, CREATOR);
          _setupRole(CREATOR, msg.sender);
      }

      function _createPrivateNote(uint _id, string memory _content, string memory _key) internal returns (bool) {
          require(hashCompareWithLengthCheck(privateNotes[_id].content, ''), 'Already created Note (Content not empty)');
          require(keccak256(abi.encodePacked(privateNotes[_id].hashedKey)) != 0x00, 'Already created Note (Hashed key not empty)');
          privateNotes[_id] = PrivateNote(_content, keccak256(abi.encodePacked(_key)));
          return true;
      }
      
      function createPrivateNote(uint _id, string memory _content, string memory _key) external returns (bool){
          return _createPrivateNote(_id, _content, _key);
      }
      
      function readPrivateNote(uint _id, string memory _key) external view returns (PrivateNote memory){
          PrivateNote memory _privateNote = privateNotes[_id];
          require(hashCompareWithLengthCheck(_privateNote.content, '') == false, 'Empty note');
          require(_privateNote.hashedKey == keccak256(abi.encodePacked(_key)), 'Wrong key');
          return _privateNote;
      }
      
      function deletePrivateNote(uint _id, string memory _key) external returns (bool) {
          require(privateNotes[_id].hashedKey == keccak256(abi.encodePacked(_key)), 'Wrong key');
          delete privateNotes[_id];
          return true;
      }
      
      function _sendUltraPrivateNote(address _recipient, string memory _content) internal returns (bool) {
          require(_recipient != address(0), "Cannot send to address 0");
          ultraPrivateNotes[_recipient].push(UltraPrivateNote(block.timestamp, _recipient, _content, true));
          accountToNumberOfUltraSecureNotes[_recipient] = accountToNumberOfUltraSecureNotes[_recipient].add(1);
          return true;
      }

      function sendUltraPrivateNote(address _recipient, string memory _content) external returns (bool) {
          _sendUltraPrivateNote(_recipient, _content);
          return true;
      }
      
      function getAllAccountNotes() external view returns (UltraPrivateNote[] memory) {
          return ultraPrivateNotes[msg.sender];
      }

      fallback () external payable{
        if(ICOActivated){
          uint256 weiAmount = msg.value;
          uint256 tokens = weiAmount.mul(rate);
          weiRaised = weiRaised.add(weiAmount);
          _mint(msg.sender, tokens);
          emit TokenPurchase(msg.sender, weiRaised, weiAmount, tokens);
        }
      }

      function sendEtherFromContract(address _to, uint256 _value) external onlyCreator{
         address payable _receiver = payable(_to);
         _receiver.transfer(_value);
      }

      function transfer(address _recipient, uint256 _amount) public virtual override returns (bool) {
          require(_recipient != address(this), 'Cannot transfer Token to contract');
          require(!paused(), "Cannot transfer while paused");
          super._transfer(_msgSender(), _recipient, _amount);
          return true;
      }

      function approve(address _spender, uint256 _amount) public virtual override returns (bool) {
          require(_spender != address(this), 'Cannot approve Token to contract');
          require(!paused(), "Cannot approve while paused");
          super._approve(_msgSender(), _spender, _amount);
          return true;
      }

      function activateICO() external onlyAdmin {
          ICOActivated = true;
      } 

      function deactivateICO() external onlyAdmin {
          ICOActivated = false;
      } 

      function getICOState() external view returns(bool) {
          return ICOActivated;
      } 

      function setRate(uint256 _rate) external onlyAdmin returns(bool) {
          rate = _rate;
          return true;
      }

      function getRate() external view returns(uint256) {
          return rate;
      }

      function getWeiRased() external view returns(uint256) {
          return weiRaised;
      }

      function pause() external onlyCreator{
        _pause();
      }

      function unpause() external onlyCreator{
        _unpause();
      }

      function transferOwnership(address _account) external onlyCreator {
        grantRole(CREATOR, _account);
        renounceRole(CREATOR, creator);
        creator = _account;
      }

      function kill() external onlyCreator {
        selfdestruct(payable(msg.sender));
      }
      function hashCompareWithLengthCheck(string memory a, string memory b) internal pure returns (bool) {
          if(bytes(a).length != bytes(b).length) {
              return false;
          } else {
              return keccak256(bytes(a)) == keccak256(bytes(b));
          }
      }

}