pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract main is ERC721 {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIds;

    constructor() public ERC721("test university", "tu") {}

    struct person {
        address Address;
        uint256[] id;
    }

    mapping(uint256 => person) internal personDetails; // stores the persons address with all the ids allocated to it, referenced by registration number

    mapping(string => uint8) internal hashes; //ipfs url of the file, to prevent same file beingd used twice

    mapping(uint256 => string) public tokenId; //maps tokenid with metadata

    mapping(uint256 => uint256) public tokenIdt; //TOKEN TIMESTAMP, to allow recover if something went worng when uploading

    function addItem(
        uint256 rn,
        address recipient,
        string memory hash,
        string memory metadata
    ) public returns (uint256) {
        require(hashes[hash] != 1, "Files already assigned");
        hashes[hash] = 1;
        _tokenIds.increment();
        uint256 newItemId = _tokenIds.current();
        _mint(recipient, newItemId); //assigns an id with an address
        tokenId[newItemId] = metadata; // sets the tokenid to json file containg the metadata and file link
        tokenIdt[newItemId] = block.timestamp;
        personDetails[rn].id.push(newItemId);
        return newItemId;
    }

    function EditData(
        uint256 id,
        string memory metadata //This functions allows to edit a token ID if found with wrong data and can be changed with
    ) public {
        uint256 limit = tokenIdt[id] + 60;
        require(
            tokenIdt[id] != 0 && block.timestamp < limit,
            "Id not created or the time to edit is over"
        );
        tokenId[id] = metadata;
    }

    function getIdLenght(uint256 rn) public view returns (uint256) {
        //will get he total number of ids hold by a address
        return personDetails[rn].id.length;
    }

    function getId(uint256 rn, uint256 d) public view returns (uint256) {
        //after getting the lenght of ids stored by an address, this can called by running an array to get all the allocated ids
        return personDetails[rn].id[d];
    }
}