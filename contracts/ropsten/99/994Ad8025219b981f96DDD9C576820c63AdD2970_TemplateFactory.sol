/*

          88888888                         88888888
       8888    888888                   888888    8888
     888    88  8888888               8888  8888     888
    888        888888888             888888888888     888
   888        88888888888           8888888888888      888
   888      8888888888888           888888888888       888
    888     888888888888             888888888        888
     888     888  88888      _=_      8888888  88    888
       8888    888888      q(-_-)p      888888    8888
          88888888         '_) (_`         88888888
             88            /__/  /            88
             88          _(<_   / )_          88
            8888        (__/_/_|_/__)        8888

_____ ______   ________  ________   _________  ________  ________          ________ ________  ________ _________  ________  ________      ___    ___ 
|/   _ /  _   /|/   __  /|/   ___  /|/___   ___//   __  /|/   __  /        |/  _____//   __  /|/   ____//___   ___//   __  /|/   __  /    |/  /  /  /|
/ /  ///__/ /  / /  /|/  / /  // /  /|___ /  /_/ /  /|/  / /  /|/  /       / /  /__// /  /|/  / /  /___/|___ /  /_/ /  /|/  / /  /|/  /   / /  //  / /
 / /  //|__| /  / /   __  / /  // /  /   / /  / / /   _  _/ /   __  /       / /   __// /   __  / /  /       / /  / / /  ///  / /   _  _/   / /    / / 
  / /  /    / /  / /  / /  / /  // /  /   / /  / / /  //  // /  / /  /       / /  /_| / /  / /  / /  /____   / /  / / /  ///  / /  //  /|   //  /  /  
   / /__/    / /__/ /__/ /__/ /__// /__/   / /__/ / /__// _// /__/ /__/       / /__/   / /__/ /__/ /_______/  / /__/ / /_______/ /__// _/ __/  / /    
    /|__|     /|__|/|__|/|__|/|__| /|__|    /|__|  /|__|/|__|/|__|/|__|        /|__|    /|__|/|__|/|_______|   /|__|  /|_______|/|__|/|__|/___/ /     
                                                                                                                                         /|___|/      
*/

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";

import "./Deployer.sol";
import "./ITemplateFactory.sol";
import "../SomaNetwork/utils/NetworkAccessUpgradeable.sol";

contract TemplateFactory is ITemplateFactory, ReentrancyGuardUpgradeable, NetworkAccessUpgradeable {
    using AddressUpgradeable for address;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.Bytes32Set;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;

    // template address => template information
    mapping(bytes32 => Template) private _template;
    mapping(address => DeploymentInfo) private _deployed;

    // a PUBLIC_ROLE will allow anybody access
    bytes32 public constant PUBLIC_ROLE = keccak256("PUBLIC_ROLE");

    bytes32 public constant MANAGE_TEMPLATE_ROLE = keccak256("MANAGE_TEMPLATE_ROLE");
    bytes32 public constant FUNCTION_CALL_ROLE = keccak256("FUNCTION_CALL_ROLE");

    bytes32 public constant override NETWORK_KEY = bytes32("TemplateFactory");

    function initialize(address networkAddress) external override initializer {
        __NetworkAccess_init(networkAddress);
        __ReentrancyGuard_init();
    }

    function version(bytes32 templateId, uint256 _version) external override view returns (Version memory) {
        return _template[templateId].version[_version];
    }

    function latestVersion(bytes32 templateId) public override view returns (uint256) {
        return _template[templateId].latestVersion;
    }

    function templateInstances(bytes32 templateId) external override view returns (address[] memory) {
        return _template[templateId].instances;
    }

    function deploymentInfo(address instance) external view override returns (DeploymentInfo memory) {
        return _deployed[instance];
    }

    function deployedByFactory(address instance) external view override returns (bool) {
        return _deployed[instance].exists;
    }

    function createTemplateVersion(bytes32 templateId, bytes memory creationCode) external override onlyRole(MANAGE_TEMPLATE_ROLE) nonReentrant returns (bool) {
        uint256 _version = _template[templateId].latestVersion + 1;

        require(creationCode.length > 0, 'TemplateFactory: creation code is empty');

        _template[templateId].latestVersion = _version;
        _template[templateId].version[_version].creationCode = creationCode;
        _template[templateId].version[_version].exists = true;

        emit TemplateVersionCreated(templateId, _version, creationCode, _msgSender());

        return true;
    }

    function updateDeployRole(bytes32 templateId, bytes32 deployRole) external override onlyRole(MANAGE_TEMPLATE_ROLE) nonReentrant returns (bool) {
        emit DeployRoleUpdated(templateId, _template[templateId].deployRole, deployRole, _msgSender());
        _template[templateId].deployRole = deployRole;
        return true;
    }

    function disableTemplate(bytes32 templateId) external override onlyRole(MANAGE_TEMPLATE_ROLE) nonReentrant returns (bool) {
        require(!_template[templateId].disabled, 'TemplateFactory: this template is already disabled');
        _template[templateId].disabled = true;

        emit TemplateDisabled(templateId, _msgSender());

        return true;
    }

    function enableTemplate(bytes32 templateId) external override onlyRole(MANAGE_TEMPLATE_ROLE) nonReentrant returns (bool) {
        require(_template[templateId].disabled, 'TemplateFactory: this template is already enabled');
        _template[templateId].disabled = false;

        emit TemplateEnabled(templateId, _msgSender());

        return true;
    }

    function deprecateVersion(bytes32 templateId, uint256 _version) external override onlyRole(MANAGE_TEMPLATE_ROLE) nonReentrant returns (bool) {
        require(_template[templateId].version[_version].exists, 'TemplateFactory: this template version does not exist');
        require(!_template[templateId].version[_version].deprecated, 'TemplateFactory: this template version is already deprecated');

        _template[templateId].version[_version].deprecated = true;

        emit TemplateVersionDeprecated(templateId, _version, _msgSender());

        return true;
    }

    function undeprecateVersion(bytes32 templateId, uint256 _version) external override onlyRole(MANAGE_TEMPLATE_ROLE) returns (bool) {
        require(_template[templateId].version[_version].deprecated, 'TemplateFactory: this template version is not currently deprecated');

        _template[templateId].version[_version].deprecated = false;

        emit TemplateVersionUndeprecated(templateId, _version, _msgSender());

        return true;
    }

    function predictDeployedAddress(bytes32 templateId, uint256 _version, bytes memory args) external override view returns (address) {
        return Deployer.predictAddress(address(this), _deployCode(templateId, _version, args), _salt(templateId, _version));
    }

    function deployTemplateVersionLatest(bytes32 templateId, bytes memory args, bytes[] memory functionCalls) external override returns (address instance) {
        return deployTemplateVersion(templateId, latestVersion(templateId), args, functionCalls);
    }

    function deployTemplateVersion(bytes32 templateId, uint256 _version, bytes memory args, bytes[] memory functionCalls) public override nonReentrant returns (address instance) {

        Template storage tpl = _template[templateId];

        require(!tpl.disabled, 'TemplateFactory: this template has been disabled');
        require(!tpl.version[_version].deprecated, 'TemplateFactory: this template version has been deprecated');

        require(
            tpl.deployRole == PUBLIC_ROLE || hasRole(tpl.deployRole, _msgSender()) || hasRole(MANAGE_TEMPLATE_ROLE, _msgSender()),
            'TemplateFactory: missing required permissions to deploy this template'
        );

        instance = Deployer.deploy(_deployCode(templateId, _version, args), _salt(templateId, _version));

        _template[templateId].instances.push(instance);
        _template[templateId].version[_version].instances.push(instance);

        _deployed[instance].exists = true;
        _deployed[instance].templateId = templateId;
        _deployed[instance].version = _version;

        for (uint i = 0; i < functionCalls.length; i++) {
            instance.functionCall(functionCalls[i]);
        }

        emit TemplateDeployed(instance, templateId, args, functionCalls, _msgSender());
    }

    function functionCall(address target, bytes memory data) external override onlyRole(FUNCTION_CALL_ROLE) nonReentrant returns (bytes memory result) {
        result = target.functionCall(data);
        emit FunctionCalled(target, data, result, _msgSender());
    }

    function _salt(bytes32 templateId, uint256 _version) private view returns (bytes32) {
        return keccak256(abi.encodePacked(templateId, _version, _template[templateId].version[_version].instances.length));
    }

    function _deployCode(bytes32 templateId, uint256 _version, bytes memory args) private view returns (bytes memory) {
        return abi.encodePacked(_template[templateId].version[_version].creationCode, args);
    }
}