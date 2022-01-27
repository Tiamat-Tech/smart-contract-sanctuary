// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity 0.8.9;
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./GeneralERC721.sol";

// !!! WARNING: TEST CONTRACT !!!
contract GeneralERC721Factory is AccessControl {
    uint256 private _totalDeployed;
    uint256 private _defaultMintingFee;

    mapping (uint256 => address) private _deployedContracts;

    constructor(uint256 defaultMintingFee) {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _defaultMintingFee = defaultMintingFee;
        emit DefaultMintingFeeSet(msg.sender, defaultMintingFee);
    }

    event ContractDeployed (
        address indexed deployer,
        address indexed newContractAddress,
        uint256 indexed index
    );

    event DefaultMintingFeeSet (
        address indexed setBy,
        uint256 defaultMintingFee
    );

    function setMintingFee(uint256 newDefaultMintingFee) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "GeneralERC721Factory: Only admin can alter the fee");
        _defaultMintingFee = newDefaultMintingFee;
        emit DefaultMintingFeeSet(msg.sender, newDefaultMintingFee);
    }

    function deployERC721(string memory name, string memory symbol, string memory baseTokenURI) public returns (address) {
        GeneralERC721 newContract = new GeneralERC721(name, symbol, baseTokenURI, msg.sender, _defaultMintingFee);
        
        _deployedContracts[_totalDeployed] = address(newContract);

        emit ContractDeployed(msg.sender, address(newContract), _totalDeployed);

        _totalDeployed++;
        return address(newContract);
    }

    function totalDeployed() public view returns(uint256) {
        return _totalDeployed;
    }

    // getAddress fetches the deployed contract by deployed index
    function getAddress(uint256 _index) public view returns (address) {
        return _deployedContracts[_index];
    }
}