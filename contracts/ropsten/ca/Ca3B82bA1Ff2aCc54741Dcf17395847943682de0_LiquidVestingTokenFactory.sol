// SPDX-License-Identifier: MIT
pragma solidity =0.7.4;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./LiquidVestingTokenFactory.sol";

contract LiquidVestingToken is ERC20Upgradeable, OwnableUpgradeable {
  using SafeMathUpgradeable for uint256;

  bytes32 public DOMAIN_SEPARATOR;

  enum AddType { MerkleTree, Airdrop }

  bytes32[] public merkleRoot;
  IERC20 public redeemToken;
  uint256 public overridenFee;
  uint256 public activationTimestamp;
  uint256 public redeemTimestamp;
  AddType public addRecipientsType;
  address public factory;

  event Redeemed(address indexed to, uint256 amount);

  modifier inType(AddType _type) {
    require(addRecipientsType == _type, "Types do not match");
    _;
  }

  function initialize(
    string memory _name,
    string memory _symbol,
    address _owner,
    address _factory,
    address _redeemToken,
    uint256 _activationTimestamp,
    uint256 _redeemTimestamp,
    AddType _type
  ) public initializer {
    __Ownable_init();
    transferOwnership(_owner);

    __ERC20_init(_name, _symbol);

    uint256 chainId;
    assembly {
      chainId := chainid()
    }
    DOMAIN_SEPARATOR = keccak256(
      abi.encode(
        keccak256(
          "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
        ),
        keccak256(bytes(_name)),
        keccak256(bytes("1")),
        chainId,
        address(this)
      )
    );

    factory = _factory;
    redeemToken = IERC20(_redeemToken);
    addRecipientsType = _type;
    activationTimestamp = _activationTimestamp;
    redeemTimestamp = _redeemTimestamp;
  }

  function overrideFee(uint256 _newFee) external onlyOwner {
    require(_newFee >= 0 && _newFee <= 5000, "Fee goes beyond rank");

    overridenFee = _newFee;
  }

  function addRecipient(address _recipient, uint256 _amount)
    public
    inType(AddType.Airdrop)
  {
    require(_recipient != address(0), "Recipient cannot be zero address");

    redeemToken.transferFrom(_msgSender(), address(this), _amount);

    mintTokens(_recipient, _amount);
  }

  function addRecipients(
    address[] memory _recipients,
    uint256[] memory _amounts
  ) external onlyOwner inType(AddType.Airdrop) {
    require(
      _recipients.length == _amounts.length,
      "Recipients should be the same length with amounts"
    );
    uint256 totalAmount;

    for (uint256 i = 0; i < _recipients.length; i++) {
      totalAmount = totalAmount.add(_amounts[i]);
      mintTokens(_recipients[i], _amounts[i]);
    }
    redeemToken.transferFrom(_msgSender(), address(this), totalAmount);
  }

  function addMerkleRoot(
    bytes32 _merkleRoot,
    uint256 _totalAmount,
    uint8 _v,
    bytes32 _r,
    bytes32 _s
  ) external onlyOwner inType(AddType.MerkleTree) {
    bytes32 digest =
      keccak256(
        abi.encodePacked(
          "\x19\x01",
          DOMAIN_SEPARATOR,
          keccak256(abi.encode(_merkleRoot, _totalAmount))
        )
      );

    address recoveredAddress = ecrecover(digest, _v, _r, _s);

    require(
      recoveredAddress != address(0) &&
        recoveredAddress == LiquidVestingTokenFactory(factory).merkleRootSigner(),
      "Invalid signature"
    );

    redeemToken.transferFrom(_msgSender(), address(this), _totalAmount);

    merkleRoot.push(_merkleRoot);
  }

  function claimTokensByMerkleProof(
    bytes32[] memory _proof,
    uint256 rootId,
    address _recipient,
    uint256 _amount
  ) external inType(AddType.MerkleTree) {
    require(_recipient != address(0), "Recipient cannot be zero address");

    require(
      checkProof(
        _proof,
        leafFromAddressAndNumTokens(_recipient, _amount),
        rootId
      ),
      "Invalid proof"
    );

    mintTokens(_recipient, _amount);

    if (block.timestamp >= redeemTimestamp) {
      redeem(_recipient, _amount);
    }
  }

  function claimProjectTokensByFeeCollector() external {
    uint256 timestampForClaiming = 365 days;
    require(
      block.timestamp >= redeemTimestamp.add(timestampForClaiming),
      "Cannot claim project tokens before allowed date"
    );
    require(
      _msgSender() == LiquidVestingTokenFactory(factory).feeCollector(),
      "Cannot claim project tokens if caller is not fee collector"
    );

    uint256 amount = redeemToken.balanceOf(address(this));
    redeemToken.transfer(LiquidVestingTokenFactory(factory).feeCollector(), amount);
  }

  function redeem(address _recipient, uint256 _amount) public {
    require(
      block.timestamp >= redeemTimestamp,
      "Cannot redeem tokens before unlock timestamp"
    );
    require(_recipient != address(0), "Recipient cannot be zero address");
    require(_amount > 0, "Amount should be more than 0");

    uint256 amount = IERC20(address(this)).balanceOf(_recipient);
    require(_amount <= amount, "Cannot burn more than available amount tokens");

    _burn(_recipient, _amount);

    redeemToken.transfer(_recipient, _amount);

    emit Redeemed(_recipient, _amount);
  }

  function mintTokens(address _recipient, uint256 _amount) internal {
    require(_amount > 0, "Amount should be more than 0");

    _mint(_recipient, _amount);
  }

  function checkProof(
    bytes32[] memory proof,
    bytes32 hash,
    uint256 rootId
  ) internal view returns (bool) {
    bytes32 el;
    bytes32 h = hash;

    for (uint256 i = 0; i <= proof.length - 1; i += 1) {
      el = proof[i];

      if (h < el) {
        h = keccak256(abi.encodePacked(h, el));
      } else {
        h = keccak256(abi.encodePacked(el, h));
      }
    }
    return h == merkleRoot[rootId];
  }

  function leafFromAddressAndNumTokens(address _a, uint256 _n)
    internal
    pure
    returns (bytes32)
  {
    string memory prefix = "0x";
    string memory space = " ";

    bytes memory _ba = bytes(prefix);
    bytes memory _bb = bytes(addressToAsciiString(_a));
    bytes memory _bc = bytes(space);
    bytes memory _bd = bytes(uintToStr(_n));
    string memory abcde =
      new string(_ba.length + _bb.length + _bc.length + _bd.length);
    bytes memory babcde = bytes(abcde);
    uint256 k = 0;
    for (uint256 i = 0; i < _ba.length; i++) babcde[k++] = _ba[i];
    for (uint256 i = 0; i < _bb.length; i++) babcde[k++] = _bb[i];
    for (uint256 i = 0; i < _bc.length; i++) babcde[k++] = _bc[i];
    for (uint256 i = 0; i < _bd.length; i++) babcde[k++] = _bd[i];

    return bytes32(keccak256(abi.encodePacked(abcde)));
  }

  function addressToAsciiString(address x)
    internal
    pure
    returns (string memory)
  {
    bytes memory s = new bytes(40);
    for (uint256 i = 0; i < 20; i++) {
      bytes1 b = bytes1(uint8(uint256(uint160(x)) / (2**(8 * (19 - i)))));
      bytes1 hi = bytes1(uint8(b) / 16);
      bytes1 lo = bytes1(uint8(b) - 16 * uint8(hi));
      s[2 * i] = char(hi);
      s[2 * i + 1] = char(lo);
    }
    return string(s);
  }

  function char(bytes1 b) internal pure returns (bytes1 c) {
    if (uint8(b) < 10) return bytes1(uint8(b) + 0x30);
    else return bytes1(uint8(b) + 0x57);
  }

  function uintToStr(uint256 i) internal pure returns (string memory) {
    if (i == 0) return "0";
    uint256 j = i;
    uint256 length;
    while (j != 0) {
      length++;
      j /= 10;
    }
    bytes memory bstr = new bytes(length);
    uint256 k = length - 1;
    while (i != 0) {
      bstr[k--] = bytes1(uint8(48 + (i % 10)));
      i /= 10;
    }
    return string(bstr);
  }

  function transfer(address recipient, uint256 amount)
    public
    override
    returns (bool)
  {
    uint256 feeFromAmount;

    if (overridenFee == 0) {
      feeFromAmount = amount.mul(LiquidVestingTokenFactory(factory).fee()).div(100000);
    } else {
      feeFromAmount = amount.mul(overridenFee).div(100000);
    }

    super.transfer(LiquidVestingTokenFactory(factory).feeCollector(), feeFromAmount);
    super.transfer(recipient, amount.sub(feeFromAmount));
    return true;
  }

  function transferFrom(address sender, address recipient, uint256 amount)
    public
    override
    returns (bool)
  {
    uint256 feeFromAmount;

    if (overridenFee == 0) {
      feeFromAmount = amount.mul(LiquidVestingTokenFactory(factory).fee()).div(100000);
    } else {
      feeFromAmount = amount.mul(overridenFee).div(100000);
    }

    super.transferFrom(sender, LiquidVestingTokenFactory(factory).feeCollector(), feeFromAmount);
    super.transferFrom(sender, recipient, amount.sub(feeFromAmount));
    return true;
  }

  function _beforeTokenTransfer(
    address from,
    address to,
    uint256 amount
  ) internal override {
    require(
      block.timestamp >= activationTimestamp,
      "Cannot transfer before activation timestamp"
    );
    super._beforeTokenTransfer(from, to, amount);
  }
}