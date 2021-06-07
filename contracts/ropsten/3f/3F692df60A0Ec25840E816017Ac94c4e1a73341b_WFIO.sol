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
    int pausemapv;
    int upausmapv;

    event unwrapped(string fioaddress, uint256 amount);
    event wrapped(address account, uint256 amount, string obtid);
    event custodian_unregistered(address account, bytes32 eid);
    event custodian_registered(address account, bytes32 eid);
    event oracle_unregistered(address account, bytes32 eid);
    event oracle_registered(address account, bytes32 eid);

    mapping ( address => oracle) oracles;
    address[] oraclelist;
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

    function pause() public custodianOnly whenNotPaused {
      bytes32 id = keccak256(bytes(abi.encodePacked("pause", pausemapv)));
      require(approvals[id].approved[msg.sender] == false,  "msg.sender has already approved this pause");
      int reqcust = ((custodian_count / 3) * 2 + 1);
      if (approvals[id].approvals < reqcust) {
        approvals[id].approvals++;
        approvals[id].approved[msg.sender] = true;
      }
      if (approvals[id].approvals == reqcust){
        delete approvals[id];
        pausemapv++;
        _pause();
      }
    }

    function unpause() public custodianOnly whenPaused {
      bytes32 id = keccak256(bytes(abi.encodePacked("unpause", upausmapv)));
      require(approvals[id].approved[msg.sender] == false,  "msg.sender has already approved this unpause");
      int reqcust = ((custodian_count / 3) * 2 + 1);
      if (approvals[id].approvals < reqcust) {
        approvals[id].approvals++;
        approvals[id].approved[msg.sender] = true;
      }
      if (approvals[id].approvals == reqcust){
        delete approvals[id];
        upausmapv++;
        _unpause();
      }

    }

    function wrap(address account, uint256 amount, string memory obtid) public oracleOnly whenNotPaused{
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

    function unwrap(string memory fioaddress, uint256 amount) public whenNotPaused{
      require(bytes(fioaddress).length > 3 && bytes(fioaddress).length <= 64, "Invalid FIO Address");
      _burn(msg.sender, amount);
      emit unwrapped(fioaddress, amount);
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal override(ERC20, ERC20Pausable) {
        super._beforeTokenTransfer(from, to, amount);
    }

    function getCustodian(address account) public view returns (bool, int) {
      require(account != address(0), "Invalid address");
      return (custodians[account].active, custodian_count);
    }

    function getOracle(address account) public view returns (bool, int) {
      require(account != address(0), "Invalid address");
      return (oracles[account].active, oracle_count);
    }

    function getOracles() public view returns(address[] memory) {
      return oraclelist;
    }

    function getApproval(string memory obtid) public view returns (int, address, uint256) {
      require(bytes(obtid).length > 0, "Invalid obtid");
      bytes32 obthash = keccak256(bytes(abi.encodePacked(obtid)));
      return (approvals[obthash].approvals, approvals[obthash].account, approvals[obthash].amount);
    }

    function regoracle(address account) public custodianOnly {
      require(account != address(0), "Invalid address");
      require(account != msg.sender, "Cannot register self");
      require(oracles[account].active == false, "Oracle is already registered");
      bytes32 id = keccak256(bytes(abi.encodePacked("ro",account, roracmapv )));
      require(approvals[id].approved[msg.sender] == false,  "msg.sender has already approved this custodian");
      int reqcust = ((custodian_count / 3) * 2 + 1);
      if (approvals[id].approvals < reqcust) {
        approvals[id].approvals++;
        approvals[id].approved[msg.sender] = true;
      }
      if (approvals[id].approvals == reqcust){
        oracles[account].active=true;
        oraclelist.push(account);
        oracle_count++;
        delete approvals[id];
        roracmapv++;
        emit oracle_registered(account, id);
      }
    }

    function unregoracle(address account) public custodianOnly {
      require(account != address(0), "Invalid address");
      require(oracle_count > 0, "No oracles remaining");
      bytes32 id = keccak256(bytes(abi.encodePacked("uo",account, uoracmapv)));
      require(approvals[id].approved[msg.sender] == false,  "msg.sender has already approved this oracle deactivation");
      require(oracles[account].active == true, "Oracle is not registered");
      int reqcust = ((custodian_count / 3) * 2 + 1);
      if (approvals[id].approvals < reqcust) {
        approvals[id].approvals++;
        approvals[id].approved[msg.sender] = true;
      }
      if ( approvals[id].approvals == reqcust) {
          oracles[account].active = false;
          delete oracles[account];
          oracle_count--;
          delete approvals[id];
          uoracmapv++;

          for(uint16 i = 0; i <= oraclelist.length - 1; i++) {
            if(oraclelist[i] == account) {
              oraclelist[i] = oraclelist[oraclelist.length - 1];
              oraclelist.pop();
              break;
            }
          }

          emit oracle_unregistered(account, id);
      }

    } // unregoracle

    function regcust(address account) public custodianOnly {
      require(account != address(0), "Invalid address");
      require(account != msg.sender, "Cannot register self");
      bytes32 id = keccak256(bytes(abi.encodePacked("rc",account, rcustmapv)));
      require(custodians[account].active == false, "Custodian is already registered");
      require(approvals[id].approved[msg.sender] == false,  "msg.sender has already approved this custodian");
      int reqcust = ((custodian_count / 3) * 2 + 1);
      if (approvals[id].approvals < reqcust) {
        approvals[id].approvals++;
        approvals[id].approved[msg.sender] = true;
      }
      if (approvals[id].approvals == reqcust) {
        custodians[account].active = true;
        custodian_count++;
        delete approvals[id];
        rcustmapv++;
        emit custodian_registered(account, id);
      }
    }

    function unregcust(address account) public custodianOnly {
      require(account != address(0), "Invalid address");
      require(custodians[account].active == true, "Custodian is not registered");
      require(custodian_count > 7, "Must contain 7 custodians");
      bytes32 id = keccak256(bytes(abi.encodePacked("uc",account, ucustmapv)));
      require(approvals[id].approved[msg.sender] == false, "msg.sender has already approved this custodian deactivation");
      int reqcust = ((custodian_count / 3) * 2 + 1);
      if (approvals[id].approvals < reqcust) {
        approvals[id].approvals++;
        approvals[id].approved[msg.sender] = true;
      }
      if ( approvals[id].approvals == reqcust) {
          custodians[account].active = false;
          delete custodians[account];
          custodian_count--;
          delete approvals[id];
          ucustmapv++;
          emit custodian_unregistered(account, id);
      }
    } //unregcustodian

    // ------------------------------------------------------------------------
    // Don't accept ETH
    // ------------------------------------------------------------------------
    receive () external payable {
        revert();
    }

}