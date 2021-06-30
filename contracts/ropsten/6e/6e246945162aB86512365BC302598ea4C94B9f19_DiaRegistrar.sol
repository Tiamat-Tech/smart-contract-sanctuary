pragma solidity ^0.8.4;

// DIA Registrar is owner of dia registry ens domain
// Reposibilities include, CRUD operations of oracle

//BaseRegistrarImplementation = 0x57f1887a8BF19b14fC0dF6Fd9B2acc9Af147eA85

import "./interface/ENSInterface.sol";
import "./interface/Resolver.sol";
import "./interface/ERC721Interface.sol";

import "@ensdomains/ens/contracts/Deed.sol";
import "@ensdomains/ens/contracts/Registrar.sol";

contract DiaRegistrar {
    // namehash('eth')

    Resolver private resolver =
        Resolver(0xf6305c19e814d2a75429Fd637d01F7ee0E77d615);

    // https://rinkeby.etherscan.io/address/0x57f1887a8bf19b14fc0df6fd9b2acc9af147ea85#code
    //BaseRegistrarImplementation
    IERC721 private erc721 =
        IERC721(0x57f1887a8BF19b14fC0dF6Fd9B2acc9Af147eA85);

    bytes32 public constant TLD_NODE =
        0x93cdeb708b7545dc668eb9280176169d1c33cfd8ed6f04690a0bcc88a93fc4ae; //eth

    bool public stopped = false;
    address public registrarOwner;
    address public migration;

    address public registrar;

    ENS public ens;

    event DomainTransferred(bytes32 indexed label, string name);

    modifier owner_only(bytes32 label) {
        require(owner(label) == msg.sender);
        _;
    }

    modifier not_stopped() {
        require(!stopped);
        _;
    }

    modifier registrar_owner_only() {
        require(
            msg.sender == registrarOwner,
            "Only owner can call this function."
        );
        _;
    }

    constructor(ENS _ens) {
        ens = _ens;
        registrarOwner = msg.sender;
    }

    modifier new_registrar() {
        require(ens.owner(TLD_NODE) != address(registrar));
        _;
    }

    function doRegistration(
        bytes32 node,
        bytes32 label,
        address subdomainOwner
    ) public registrar_owner_only {
        // Get the subdomain so we can configure it
        ens.setSubnodeOwner(node, label, address(this));

        bytes32 subnode = keccak256(abi.encodePacked(node, label));
        // Set the subdomain's resolver
        ens.setResolver(subnode, address(resolver));

        // Set the address record on the resolver
        resolver.setAddr(subnode, subdomainOwner);

        // Pass ownership of the new subdomain to the registrant
        ens.setOwner(subnode, subdomainOwner);
    }

    function setAddr(
        bytes32 node,
        bytes32 label,
        address oracleaddr
    ) public registrar_owner_only {
        // Get the subdomain so we can configure it
        ens.setSubnodeOwner(node, label, address(this));

        bytes32 subnode = keccak256(abi.encodePacked(node, label));
        // Set the subdomain's resolver
        ens.setResolver(subnode, address(resolver));

        // Set the address record on the resolver
        resolver.setAddr(subnode, oracleaddr);

        // Pass ownership of the new subdomain to the registrant
    }

    function supportsInterface(bytes4 interfaceID) public pure returns (bool) {
        return ((interfaceID == 0x01ffc9a7) || (interfaceID == 0xc1b15f5a)); // supportsInterface(bytes4) // RegistrarInterface
    }

    function setResolver(string memory name, address _resolver)
        public
        registrar_owner_only
    {
        bytes32 label = keccak256(bytes(name));
        bytes32 node = keccak256(abi.encodePacked(TLD_NODE, label));
        ens.setResolver(node, _resolver);
    }

    function transferOwnership(address newOwner) public registrar_owner_only {
        registrarOwner = newOwner;
    }

    function transferENS(address newOwner, uint256 tokenId)
        public
        registrar_owner_only
    {
        erc721.transferFrom(address(this), newOwner, tokenId);
    }

    function owner(bytes32 label) public view returns (address) {
        Deed domainDeed = deed(label);
        if (domainDeed.owner() != address(this)) {
            return address(0x0);
        }

        return domainDeed.previousOwner();
    }

    function deed(bytes32 label) internal view returns (Deed) {
        (, address deedAddress, , , ) = Registrar(registrar).entries(label);
        return Deed(deedAddress);
    }

    // function transfer(){
    //     address ierc = IERC721("0x57f1887a8BF19b14fC0dF6Fd9B2acc9Af147eA85");
    //     ierc.safeTransferFrom();

    // }
}