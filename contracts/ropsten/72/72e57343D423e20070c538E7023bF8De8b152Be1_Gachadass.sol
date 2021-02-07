// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.7.6;
pragma abicoder v2;

import "../node_modules/@openzeppelin/contracts/token/ERC721/ERC721Pausable.sol";
import "../node_modules/@openzeppelin/contracts/access/Ownable.sol";

contract Gachadass is ERC721Pausable, Ownable {
  using SafeMath for uint256;

  event Item_Changed(
      uint256 index
  );

  event Assortment_Changed(
      uint256 index
  );

  event Gacha_Changed(
      uint256 index
  );

  event Config_Changed(
      uint16 gacha_data_length,
      uint16 items_length,
      uint16 assortments_length,
      uint72 free_gift
  );

  struct Gacha_Data {
      uint8[] rates;
      uint32[] common_items;
      uint32[] uncommon_items;
      uint32[] rare_items;
      uint72 price;
      bool released;
  }

  struct Token_Data {
      uint32 image;
      uint144 value;
  }

  struct Item {
      uint32 image;
      uint144 value;
      uint72 price;
      uint8 gacha_id;
  }

  struct Assortment {
      uint16 start;
      uint8 length;
      uint72 price;
      bytes20 hash;
  }

  struct Config {
      uint16 gacha_data_length;
      uint16 items_length;
      uint16 assortments_length;
      uint72 free_gift;
  }

  struct Event_Token {
      uint256 id;
      Token_Data data;
      address owner;
  }

  struct Event_Assortment {
      Assortment assortment;
      Item[] items;
  }

  mapping (uint256 => Token_Data) private token_data;
  mapping (uint256 => Gacha_Data) private gacha_data;
  mapping (uint256 => Item) private items;
  mapping (uint256 => Assortment) private assortments;
  mapping (address => uint256) private coins;

  Config private config;
  address private minter;

  constructor() ERC721("Gachadass", "GACHA") {}

  function mint(address to, uint32 image, uint144 v) private {
      require(image > 0);
      uint256 id = totalSupply();
      _mint(to, id);
      token_data[id]=Token_Data(
          image,
          v
      );
  }

  function mint_by_owner(address to, uint32 image, uint144 v) external {
      require(msg.sender == owner() || msg.sender == minter);
      mint(to, image, v);
  }

  function set_minter(address minter_) external onlyOwner {
      minter = minter_;
  }

  function sendEtherToOwner(uint256 amount) external onlyOwner {
      require(address(this).balance >= amount);
      msg.sender.transfer(amount);
  }

  function set_token_uri(uint256 id, string calldata uri) external {
      require(msg.sender == owner() || msg.sender == minter);
      _setTokenURI(id, uri);
  }

  function set_base_uri(string calldata uri) external {
      require(msg.sender == owner() || msg.sender == minter);
      _setBaseURI(uri);
  }

  function add_coins(address to, uint256 amount) external {
      require(msg.sender == owner() || msg.sender == minter);
      coins[to] = coins[to].add(amount);
  }

  function gacha(uint256 index, uint256 random) public view returns(uint32, uint144) {
      uint32 image;
      uint144 r;
      assembly {
        let freemem_pointer := mload(0x40)
        mstore(freemem_pointer, random)
        mstore(add(freemem_pointer, 0x20), timestamp())
        mstore(add(freemem_pointer, 0x40), difficulty())
        r := keccak256(freemem_pointer, 0x60)

        mstore(freemem_pointer, index) // mapping key
        mstore(add(freemem_pointer, 0x20), gacha_data.slot) // mapping slot
        mstore(freemem_pointer, keccak256(freemem_pointer, 0x40)) // gacha_data position
        mstore(add(freemem_pointer, 0x20), add(mload(freemem_pointer), 0)) // rates position
        mstore(add(freemem_pointer, 0x40), sload(keccak256(add(freemem_pointer, 0x20), 0x20))) // rates data

        switch lt(mod(byte(30, r), 100), byte(31, mload(add(freemem_pointer, 0x40))))
        case 1 { // レア
          mstore(add(freemem_pointer, 0x60), add(mload(freemem_pointer), 3)) //　rare position
        }
        default {
          switch lt(mod(byte(30, r), 100), byte(30, mload(add(freemem_pointer, 0x40))))
          case 1 { // アンコモン
            mstore(add(freemem_pointer, 0x60), add(mload(freemem_pointer), 2)) //　uncommon position
          }
          default { // コモン
            mstore(add(freemem_pointer, 0x60), add(mload(freemem_pointer), 1)) //　common position
          }
        }
        mstore(add(freemem_pointer, 0x80), sload(mload(add(freemem_pointer, 0x60)))) // length
        mstore(add(freemem_pointer, 0xA0), mod(byte(29, r), mload(add(freemem_pointer, 0x80)))) // item index
        mstore(add(freemem_pointer, 0xC0), sload(add(keccak256(add(freemem_pointer, 0x60), 0x20), div(mload(add(freemem_pointer, 0xA0)), 8))))
        image :=  and(mload(sub(add(freemem_pointer, 0xC0), mul(0x4, mod(mload(add(freemem_pointer, 0xA0)), 8)))), 0xffffffff)
      }
      return (image, r);
  }

  function shop(uint256 index, uint32 img, uint256 v) payable whenNotPaused external {
      require(config.items_length > index);

      uint32 image = items[index].image;
      uint144 value = items[index].value;
      uint72 price = items[index].price;

      require(price > 0);
      require(value == v);
      require(image == img);
      require(price == msg.value);

      mint(msg.sender, image, value);
      coins[msg.sender] = coins[msg.sender].add(msg.value.div(config.free_gift));
      update_item(index);
  }

  function shop(uint256 index, bytes32 hash_) payable whenNotPaused external {
      require(config.assortments_length > index);

      uint16 start = assortments[index].start;
      uint8 length = assortments[index].length;
      uint72 price = assortments[index].price;
      bytes20 hash = assortments[index].hash;
      bool del;

      require(price > 0);
      require(price == msg.value);
      require(length > 0);
      require(hash == hash_);

      for (uint256 i = 0; i < length; i++){
          mint(msg.sender, items[i + start].image, items[i + start].value);
          if (update_item(i + start) && !del){
              del = true;
          }
      }
      coins[msg.sender] = coins[msg.sender].add(msg.value.div(config.free_gift));
      if (del){
          delete assortments[index];
      }
      else{
          assortments[index].hash = assortment_hash(start, length);
      }
      emit Assortment_Changed(index);
  }

  function set_item(uint256 index, uint32 image, uint144 value, uint72 price, uint8 gacha_id) external onlyOwner {
      items[index] = Item(image, value, price, gacha_id);
      emit Item_Changed(index);
  }

  function set_items(uint256 index, Item[] memory items_) external onlyOwner {
    for (uint256 i = 0; i < items_.length; i++){
        items[index + i] = items_[i];
        emit Item_Changed(index + i);
    }
  }

  function update_item(uint256 index) private returns(bool) {
      uint32 image = items[index].image;
      uint144 value = items[index].value;
      uint72 price = items[index].price;
      uint8 gacha_id = items[index].gacha_id;
      bool del;
      if (gacha_id == 255){
          bytes32 hash = keccak256(abi.encodePacked(
                  value,
                  block.timestamp,
                  block.difficulty
          ));
          items[index].value = uint144(uint256(hash));
      }
      else if (gacha_data[gacha_id].released == true){
          (image, value) = gacha(gacha_id, value);
          items[index] = Item(image, value, price, gacha_id);
      }
      else{
          delete items[index];
          del = true;
      }
      if (index < config.items_length){
          emit Item_Changed(index);
      }
      return del;
  }

  function assortment_hash(uint256 start, uint256 length) private view returns(bytes20) {
      bytes32 hash;
      uint256 assortment_length = length + start;
      for (uint256 i = start; i < assortment_length; i++){
          hash = keccak256(abi.encodePacked(
              hash,
              items[i].value
          ));
      }
      return bytes20(hash);
  }

  function set_assortment(
        uint256 index,
        uint16 start,
        uint8 length,
        uint72 price,
        Item[] calldata items_
  )
        external onlyOwner
  {
      for (uint256 i = 0; i < items_.length; i++){
          items[start + i] = items_[i];
      }
      assortments[index] = Assortment(
          start,
          length,
          price,
          assortment_hash(start, length)
      );
      emit Assortment_Changed(index);
  }

  function set_config(
      uint16 gacha_data_length,
      uint16 items_length,
      uint16 assortments_length,
      uint72 free_gift
  )
      external onlyOwner
  {
      config = Config(
          gacha_data_length,
          items_length,
          assortments_length,
          free_gift
      );
      emit Config_Changed(
          gacha_data_length,
          items_length,
          assortments_length,
          free_gift
      );
  }

  function bonus_gacha(uint256 index) whenNotPaused external {
      require (gacha_data[index].released == true);
      require (config.gacha_data_length > index);
      require (gacha_data[index].price > 0);
      require (coins[msg.sender] >= gacha_data[index].price);
      coins[msg.sender] = coins[msg.sender].sub(gacha_data[index].price);
      uint32 image;
      uint144 r;
      uint256 i = totalSupply();
      (image, r) = gacha(
          index,
          token_data[i - 1].value + token_data[i - 2].value
      );
      mint(msg.sender, image, r);
  }

  function set_gacha_data(
      uint256 index,
      Gacha_Data calldata gacha_data_
  )
      external
      onlyOwner
  {
      gacha_data[index] = gacha_data_;
      emit Gacha_Changed(index);
  }

  function release(uint256 index) public onlyOwner {
      gacha_data[index].released = true;
      emit Gacha_Changed(index);
  }

  function unrelease(uint256 index) public onlyOwner {
      gacha_data[index].released = false;
      emit Gacha_Changed(index);
  }

  function pause() external onlyOwner {
      _pause();
  }

  function unpause() external onlyOwner {
      _unpause();
  }

  receive() external payable {}

  fallback() external payable {}

  function get_minter() external view returns(address) {
      return minter;
  }

  function get_data_all() external view returns(
      Config memory,
      Item[] memory,
      Event_Assortment[] memory,
      Gacha_Data[] memory
  ) {
      return (
          config,
          get_items(),
          get_assortments(),
          get_gacha_data_all()
      );
  }

  function get_item(uint256 index) external view returns(Item memory) {
      return items[index];
  }

  function get_items() public view returns(Item[] memory) {
      uint256 length = config.items_length;
      Item[] memory items_ = new Item[](length);
      for (uint256 i = 0; i < length; i++){
          items_[i] = items[i];
      }
      return (items_);
  }

  function get_assortment(uint256 index) public view returns(Event_Assortment memory) {
    uint16 start = assortments[index].start;
    uint8 length = assortments[index].length;
    Item[] memory items_ = new Item[](length);
    for (uint256 i = 0; i < length; i++){
        items_[i] = items[i + start];
    }
      return Event_Assortment(assortments[index], items_);
  }

  function get_assortments() public view returns(Event_Assortment[] memory) {
      uint256 length = config.assortments_length;
      Event_Assortment[] memory assortments_ = new Event_Assortment[](length);
      for (uint256 i = 0; i < length; i++){
          assortments_[i] = get_assortment(i);
      }
      return (assortments_);
  }

  function get_coins(address user) external view returns(uint256){
      return coins[user];
  }

  function get_tokens(uint256 start, uint256 length) external view returns(Event_Token[] memory) {
      uint256 length_ = totalSupply();
      if (start + length > length_){
          length = length_ - start;
      }
      Event_Token[] memory tokens = new Event_Token[](length);
      for (uint256 i = start; i < length; i++){
          tokens[i] = Event_Token(
            i,
            token_data[i],
            ownerOf(i)
          );
      }
      return (tokens);
  }

  function get_tokens(address user, uint256 start, uint256 length) external view returns(Event_Token[] memory) {
      uint256 length_ = balanceOf(user);
      if (start + length > length_){
          length = length_ - start;
      }
      Event_Token[] memory tokens = new Event_Token[](length);
      uint256 id;
      for (uint256 i = start; i < length; i++){
          id = tokenOfOwnerByIndex(user, i);
          tokens[i] = Event_Token(
            id,
            token_data[id],
            ownerOf(id)
          );
      }
      return (tokens);
  }

  function get_config() external view returns(Config memory) {
      return config;
  }

  function get_gacha_data(uint256 index) external view returns(Gacha_Data memory) {
      return gacha_data[index];
  }

  function get_gacha_data_all() public view returns(Gacha_Data[] memory) {
      uint256 length = config.gacha_data_length;
      Gacha_Data[] memory gacha_data_ = new Gacha_Data[](length);
      for (uint256 i = 0; i < length; i++){
          gacha_data_[i] = gacha_data[i];
      }
      return (gacha_data_);
  }

  function get_token_data(uint256 id) external view returns(Token_Data memory) {
      return token_data[id];
  }

}