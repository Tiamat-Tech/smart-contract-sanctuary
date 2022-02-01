// SPDX-License-Identifier: MIT

pragma solidity 0.7.6;
pragma abicoder v2;

import "../erc-721/ERC721GlipLive.sol";
import "./../@openzeppelin/contracts/proxy/UpgradeableBeacon.sol";
import "./../@openzeppelin/contracts/proxy/BeaconProxy.sol";
import "./../@openzeppelin/contracts/access/Ownable.sol";

/**
 * @dev This contract is for creating proxy to access ERC721GlipLive token.
 *
 * The beacon is initialized in the constructor.
 *
 */
contract ERC721GlipLiveFactoryC2 is Ownable {
    address public beacon;
    address exchangeProxy;
    address defaultMinter;

    event ERC721GlipLiveProxy(address proxy, bool global, address indexed owner);

    // constructor(address implementation_, address _exchangeProxy, address _defaultMinter) {
    //     UpgradeableBeacon _beacon = new UpgradeableBeacon(
    //         implementation_
    //     );
    //     _beacon.transferOwnership(msg.sender);
    //     beacon = address(_beacon);
    //     updateExchangeMinter(_exchangeProxy, _defaultMinter);
    // }

    constructor(address _beacon, address _exchangeProxy, address _defaultMinter) {
        beacon = address(_beacon);
        updateExchangeMinter(_exchangeProxy, _defaultMinter);
    }

    function updateExchangeMinter(address _exchangeProxy, address _defaultMinter ) public onlyOwner {
        exchangeProxy = _exchangeProxy;
        defaultMinter = _defaultMinter;
    }

    function create(address to, string memory _name, string memory _symbol, bool _global, string memory baseURI, string memory contractURI, uint salt) external returns (address) {
        BeaconProxy proxyAddress = new BeaconProxy(beacon, getData(_name,  _symbol,  _global,  baseURI,  contractURI));
        emit ERC721GlipLiveProxy(address(proxyAddress), _global, to);
        return address(proxyAddress);
    }

    function createToken(address to, string memory _name, string memory _symbol, bool _global, string memory baseURI, string memory contractURI, uint salt) external returns (address) {
        address beaconProxy = deployProxy(getData(_name,  _symbol,  _global,  baseURI,  contractURI), salt);
        ERC721GlipLive token = ERC721GlipLive(address(beaconProxy));
        if (to != _msgSender()) token.transferOwnership(to); else token.transferOwnership(_msgSender());
        emit ERC721GlipLiveProxy(beaconProxy, _global, token.owner());
        return beaconProxy;
    }

    //deploying BeaconProxy contract with create2
    function deployProxy(bytes memory data, uint salt) internal returns(address proxy){
        bytes memory bytecode = getCreationBytecode(data);
        assembly {
            proxy := create2(0, add(bytecode, 0x20), mload(bytecode), salt)
            if iszero(extcodesize(proxy)) {
                revert(0, 0)
            }
        }
    }

    //adding constructor arguments to BeaconProxy bytecode
    function getCreationBytecode(bytes memory _data) internal view returns (bytes memory) {
        return abi.encodePacked(type(BeaconProxy).creationCode, abi.encode(beacon, _data));
    }

    //returns address that contract with such arguments will be deployed on
    function getAddress(string memory _name, string memory _symbol, bool _global, string memory baseURI, string memory contractURI, uint salt)
        public
        view
        returns (address)
    {   
        bytes memory bytecode = getCreationBytecode(getData(_name,  _symbol,  _global,  baseURI,  contractURI));

        bytes32 hash = keccak256(
            abi.encodePacked(bytes1(0xff), address(this), salt, keccak256(bytecode))
        );

        return address(uint160(uint(hash)));
    }

    function getData(string memory _name, string memory _symbol, bool _global, string memory baseURI, string memory contractURI) view internal returns(bytes memory){
        return abi.encodeWithSelector(ERC721GlipLive(0).__ERC721GlipLive_init.selector,_name, _symbol, _global, baseURI, contractURI, exchangeProxy, defaultMinter);
    }

}