// SPDX-License-Identifier: MIT

pragma solidity 0.7.6;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../base/governance/Controllable.sol";
import "../base/interface/IBookkeeper.sol";
import "../base/interface/ISmartVault.sol";
import "../base/interface/IContractReader.sol";

contract ContractReader is IContractReader, Initializable, Controllable {

  string public constant VERSION = "0";

  function initialize(address _controller) public initializer {
    Controllable.initializeControllable(_controller);
  }

  function isGovernance(address _contract) external override view returns (bool) {
    return IController(controller()).isGovernance(_contract);
  }

  function vaultNames(address _bookkeeper) public view returns (string[] memory) {
    address[] memory vaults = IBookkeeper(_bookkeeper).vaults();
    string[] memory names = new string[](vaults.length);
    for (uint256 i; i < vaults.length; i++) {
      names[i] = ERC20(vaults[i]).name();
    }
    return names;
  }

  function vaultTvls(address _bookkeeper) public view returns (uint256[] memory) {
    address[] memory vaults = IBookkeeper(_bookkeeper).vaults();
    uint256[] memory result = new uint256[](vaults.length);
    for (uint256 i; i < vaults.length; i++) {
      result[i] = ERC20(vaults[i]).totalSupply();
    }
    return result;
  }

  function vaultDecimals(address _bookkeeper) public view returns (uint256[] memory) {
    address[] memory vaults = IBookkeeper(_bookkeeper).vaults();
    uint256[] memory result = new uint256[](vaults.length);
    for (uint256 i; i < vaults.length; i++) {
      result[i] = uint256(ERC20(vaults[i]).decimals());
    }
    return result;
  }

}