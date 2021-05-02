// SPDX-License-Identifier: MIT
// FIO Protocol ERC20 and Oracle Contract
// Adam Androulidakis 2/2021
// Prototype: Do not use in production

pragma solidity ^0.6.0;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Pausable.sol";

contract WFIO is ERC20Burnable, ERC20Pausable {

    address owner;

    uint256 constant MINTABLE = 10000000000000000;

    struct custodian {
      bool active;
    }

    struct oracle {
      bool active;
    }

    struct pending {
      mapping (address => bool) approved;
      int approvals;
      address account;
      uint256 amount;
    }

    int custodian_count;
    int oracle_count;

    int uoracmapv;
    int roracmapv;
    int rcustmapv;
    int ucustmapv;

    event unwrapped(string fioaddress, uint256 amount);
    event wrapped(address ethaddress, uint256 amount, string obtid);
    event custodian_unregistered(address ethaddress, bytes32 eid);
    event custodian_registered(address ethaddress, bytes32 eid);
    event oracle_unregistered(address ethaddress, bytes32 eid);
    event oracle_registered(address ethaddress, bytes32 eid);

    mapping ( address => oracle) oracles;
    mapping ( address => custodian) custodians;
    mapping ( bytes32 => pending) approvals; // bytes32 hash can be any obtid

    constructor(uint256 _initialSupply, address[] memory newcustodians ) public ERC20("FIO Protocol", "wFIO") {
      require(newcustodians.length == 10, "wFIO cannot deploy without 10 custodians");
      _mint(msg.sender, _initialSupply);
      _setupDecimals(9);
      owner = msg.sender;
      for (uint8 i = 0; i < 10; i++ ) {
        require(newcustodians[i] != owner, "Contract owner cannot be custodian");
        custodians[newcustodians[i]].active = true;
      }
      custodian_count = 10;
      oracle_count = 0;
    }

    modifier oracleOnly {
      require(oracles[msg.sender].active == true,
         "Only a wFIO oracle may call this function."
      );
      _;
    }

    modifier custodianOnly {
      require(custodians[msg.sender].active == true,
         "Only a wFIO custodian may call this function."
      );
      _;
    }

    function wrap(address account, uint256 amount, string memory obtid) public oracleOnly {
      require(amount < MINTABLE);
      require(bytes(obtid).length > 0, "Invalid obtid");
      require(account != address(0), "Invalid account");
      require(oracle_count >= 3, "Oracles must be 3 or greater");
      bytes32 obthash = keccak256(bytes(abi.encodePacked(obtid)));
      if (approvals[obthash].approvals < oracle_count) {
        require(approvals[obthash].approved[msg.sender] == false, "oracle has already approved this obtid");
        approvals[obthash].approvals++;
        approvals[obthash].approved[msg.sender] = true;
      }
      if (approvals[obthash].approvals == 1) {
        approvals[obthash].account = account;
        approvals[obthash].amount = amount;
      }
      if (approvals[obthash].approvals > 1) {
        require(approvals[obthash].account == account, "recipient account does not match prior approvals");
        require(approvals[obthash].amount == amount, "amount does not match prior approvals");
      }
      if (approvals[obthash].approvals == oracle_count) {
       require(approvals[obthash].approved[msg.sender] == true, "An approving oracle must execute wrap");
         _mint(account, amount);
         emit wrapped(account, amount, obtid);
        delete approvals[obthash];
      }

    }

    function unwrap(string memory fioaddress, uint256 amount) public {
      require(bytes(fioaddress).length > 3 && bytes(fioaddress).length <= 64, "Invalid FIO Address");
      _burn(msg.sender, amount);
      emit unwrapped(fioaddress, amount);
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal override(ERC20, ERC20Pausable) {
        super._beforeTokenTransfer(from, to, amount);
    }

    function getCustodian(address ethaddress) public view returns (bool, int) {
      require(ethaddress != address(0), "Invalid address");
      return (custodians[ethaddress].active, custodian_count);
    }

    function getOracle(address ethaddress) public view returns (bool, int) {
      require(ethaddress != address(0), "Invalid address");
      return (oracles[ethaddress].active, oracle_count);
    }

    function getApproval(string memory obtid) public view returns (int, address, uint256) {
      require(bytes(obtid).length > 0, "Invalid obtid");
      bytes32 obthash = keccak256(bytes(abi.encodePacked(obtid)));
      return (approvals[obthash].approvals, approvals[obthash].account, approvals[obthash].amount);
    }

    function regoracle(address ethaddress) public custodianOnly {
      require(ethaddress != address(0), "Invalid address");
      require(ethaddress != msg.sender, "Cannot register self");
      require(oracles[ethaddress].active == false, "Oracle is already registered");
      bytes32 id = keccak256(bytes(abi.encodePacked("ro",ethaddress, roracmapv )));
      require(approvals[id].approved[msg.sender] == false,  "msg.sender has already approved this custodian");
      int reqcust = ((custodian_count / 3) * 2 + 1);
      if (approvals[id].approvals < reqcust) {
        approvals[id].approvals++;
        approvals[id].approved[msg.sender] = true;
      }
      if (approvals[id].approvals == reqcust){
        oracles[ethaddress].active=true;
        oracle_count++;
        delete approvals[id];
        roracmapv++;
        emit oracle_registered(ethaddress, id);
      }
    }

    function unregoracle(address ethaddress) public custodianOnly {
      require(ethaddress != address(0), "Invalid address");
      require(oracle_count > 0, "No oracles remaining");
      bytes32 id = keccak256(bytes(abi.encodePacked("uo",ethaddress, uoracmapv)));
      require(oracles[ethaddress].active == true, "Oracle is not registered");
      int reqcust = ((custodian_count / 3) * 2 + 1);
      if (approvals[id].approvals < reqcust) {
        approvals[id].approvals++;
        approvals[id].approved[msg.sender] = true;
      }
      if ( approvals[id].approvals == reqcust) {
          oracles[ethaddress].active = false;
          delete oracles[ethaddress];
          oracle_count--;
          delete approvals[id];
          uoracmapv++;
          emit oracle_unregistered(ethaddress, id);
      }

    } // unregoracle

    function regcust(address ethaddress) public custodianOnly {
      require(ethaddress != address(0), "Invalid address");
      require(ethaddress != msg.sender, "Cannot register self");
      bytes32 id = keccak256(bytes(abi.encodePacked("rc",ethaddress, rcustmapv)));
      require(custodians[ethaddress].active == false, "Custodian is already registered");
      require(approvals[id].approved[msg.sender] == false,  "msg.sender has already approved this custodian");
      int reqcust = ((custodian_count / 3) * 2 + 1);
      if (approvals[id].approvals < reqcust) {
        approvals[id].approvals++;
        approvals[id].approved[msg.sender] = true;
      }
      if (approvals[id].approvals == reqcust) {
        custodians[ethaddress].active = true;
        custodian_count++;
        delete approvals[id];
        rcustmapv++;
        emit custodian_registered(ethaddress, id);
      }
    }

    function unregcust(address ethaddress) public custodianOnly {
      require(ethaddress != address(0), "Invalid address");
      require(custodians[ethaddress].active == true, "Custodian is not registered");
      require(custodian_count > 7, "Must contain 7 custodians");
      bytes32 id = keccak256(bytes(abi.encodePacked("uc",ethaddress, ucustmapv)));
      require(approvals[id].approved[msg.sender] == false, "Cannot unregister custodian again");
      int reqcust = ((custodian_count / 3) * 2 + 1);
      if (approvals[id].approvals < reqcust) {
        approvals[id].approvals++;
        approvals[id].approved[msg.sender] = true;
      }
      if ( approvals[id].approvals == reqcust) {
          custodians[ethaddress].active = false;
          delete custodians[ethaddress];
          custodian_count--;
          delete approvals[id];
          ucustmapv++;
          emit custodian_unregistered(ethaddress, id);
      }
    } //unregcustodian

    // ------------------------------------------------------------------------
    // Don't accept ETH
    // ------------------------------------------------------------------------
    receive () external payable {
        revert();
    }

}