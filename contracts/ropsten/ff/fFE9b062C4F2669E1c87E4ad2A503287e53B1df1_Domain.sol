//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./openzeppelin/access/OwnableUpgradeable.sol";
import "./openzeppelin/token/ERC721/ERC721Upgradeable.sol";

contract Domain is ERC721Upgradeable, OwnableUpgradeable {
    /*** proxy logic ***/
    function initialize(string memory _name, string memory _symbol)
        public
        initializer
    {
        __ERC721_init(_name, _symbol);
        __Ownable_init();
        EXPIRATION = 60 * 60 * 24 * 7 * 52;
    }

    struct Record {
        bytes record_value;
        uint64 TTL;
    }

    mapping(bytes => uint256) public domainIdOf;
    mapping(uint256 => bytes) public domainNameOf;
    mapping(uint256 => mapping(bytes => mapping(uint256 => Record)))
        public domainRecords;


        // one year
    uint256 public EXPIRATION;
    mapping(uint256 => uint256) public keepalive;


    uint256 public totalSupply;

    function GetRecordAddress(
        uint256 domain_id,
        uint256 record_type,
        bytes memory name
    ) external view returns (address) {
        return
            bytesToAddress(
                domainRecords[domain_id][name][record_type].record_value
            );
    }

    function GetRecordValue(
        uint256 domain_id,
        uint256 record_type,
        bytes memory name
    ) external view returns (bytes memory) {
        return domainRecords[domain_id][name][record_type].record_value;
    }

    function GetRecordTTL(
        uint256 domain_id,
        uint256 record_type,
        bytes memory name
    ) external view returns (uint64) {
        return domainRecords[domain_id][name][record_type].TTL;
    }

    function SetRecord(
        uint256 domain_id,
        uint256 record_type,
        bytes memory name,
        bytes memory value,
        uint64 TTL,
        bytes memory permission_node
    ) external {
        require(HasPermission(_msgSender(), domain_id, name, permission_node));
        require(VerifyRecordName(name), "invalid name");
        require(record_type < 16, "invalid record type");
        domainRecords[domain_id][name][record_type] = Record(value, TTL);
    }

    function HasPermission(
        address actioner,
        uint256 domain_id,
        bytes memory name,
        bytes memory permission_node
    ) internal view returns (bool) {
        if (_isApprovedOrOwner(actioner, domain_id)) {
            return true;
        }
        for (uint256 i = 0; i < permission_node.length; i++) {
            if (permission_node[i] != name[i]) {
                return false;
            }
        }
        if (
            actioner ==
            bytesToAddress(
                domainRecords[domain_id][permission_node][15].record_value
            )
        ) {
            return true;
        }
        return false;
    }

    function bytesToAddress(bytes memory bys)
        public
        pure
        returns (address addr)
    {
        assembly {
            addr := mload(add(bys, 20))
        }
    }

    function CreateDomain(bytes memory domain_name) public {
        require(VerifyDomainName(domain_name), "invalid name");
        require(domainIdOf[domain_name] == 0, "domain already claimed");
        totalSupply = totalSupply + 1;
        domainNameOf[totalSupply] = domain_name;
        domainIdOf[domain_name] = totalSupply;
        keepalive[totalSupply] = block.timestamp;
        _safeMint(_msgSender(), totalSupply);
    }

    function TouchDomain(uint256 domain_id) public {
        if(_isApprovedOrOwner(_msgSender(), domain_id)) {
            keepalive[domain_id] = block.timestamp;
        }
    }

    function DestroyDomain(uint256 domain_id) public {
        bytes memory name = domainNameOf[domain_id];
        if(_isApprovedOrOwner(_msgSender(), domain_id)) {
            domainIdOf[name] = 0;
            domainNameOf[domain_id] = "";
            _burn(domain_id);
            return;
        }

        if((block.timestamp - keepalive[domain_id]) > EXPIRATION) {
            domainIdOf[name] = 0;
            domainNameOf[domain_id] = "";
            _burn(domain_id);
        }
    }


    function VerifyRecordName(bytes memory record_value)
        public
        pure
        returns (bool)
    {
        if (record_value.length > 256) {
            return false;
        }
        for (uint256 i = 0; i < record_value.length; i++) {
            if ((record_value[i] > 0x25)) {
                return false;
            }
        }
        return true;
    }

    function VerifyDomainName(bytes memory domain_name)
        public
        pure
        returns (bool)
    {
        if (domain_name.length > 63) {
            return false;
        }
        for (uint256 i = 0; i < domain_name.length; i++) {
            if ((domain_name[i] > 0x25) || domain_name[i] == 0x00) {
                // note that the . is not allowed!
                return false;
            }
        }
        return true;
    }
}