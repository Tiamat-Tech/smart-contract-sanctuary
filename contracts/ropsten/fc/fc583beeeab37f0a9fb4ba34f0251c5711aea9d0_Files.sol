// SPDX-License-Identifier: MIT
pragma experimental ABIEncoderV2;
pragma solidity ^0.6.2;

import "./verifyIPFS.sol";
import "./Utils.sol";

contract Files {

    struct Metadata {
		bytes8 separator;
        bytes32 file_number;
		bytes32 title;
		bytes32 album;
		bytes32 website;
		bytes32 ipfs_hash;
		bytes32 comment;
		bytes32 copyright;
        bytes8 submission_date;
		bytes8 blockchain_date;
        bytes32 md_hash;
    }


    uint256 size;

    mapping(uint256 => Metadata) filesMetadata;


    constructor() public{
        size = 0;
    }

    function addFile(string[] memory _metadata) public returns (uint256){

       /*  Calculate Block Date */
        // (uint year, uint month, uint day) = Utils.timestampToDate(block.timestamp);
        // bytes8  _block_date = Utils.dataConvert8( Utils.concat(Utils.convertVaalue(day), ".",  Utils.convertVaalue(month), ".", Utils.convertVaalue(year)) );

        
        /* Convert IPFS Hash to bs56 encoding */

        bytes32 _ipfs_hash = Utils.dataConvert(string(verifyIPFS.toBase58(bytes(_metadata[5]))));

        filesMetadata[size].separator = Utils.dataConvert8(_metadata[0]);
        filesMetadata[size].file_number = Utils.dataConvert(_metadata[1]);
        filesMetadata[size].title = Utils.dataConvert(_metadata[2]);
        filesMetadata[size].album = Utils.dataConvert(_metadata[3]);
        filesMetadata[size].website = Utils.dataConvert(_metadata[4]);
        filesMetadata[size].ipfs_hash = _ipfs_hash;
        filesMetadata[size].comment = Utils.dataConvert(_metadata[6]);
        filesMetadata[size].copyright = Utils.dataConvert(_metadata[7]);
        filesMetadata[size].submission_date = Utils.dataConvert8(_metadata[8]);
        filesMetadata[size].blockchain_date = Utils.dataConvert8(_metadata[9]);
        filesMetadata[size].md_hash = Utils.dataConvert(_metadata[10]);

        size = size + 1;

        return size;

    }

    function decodeIPFS(string memory _data) public pure returns (string memory){
        return string(verifyIPFS.toBase58(bytes(_data)));
    }


    function getDate(uint256 _index) public view returns (string memory){
        return Utils.dataOutput8(filesMetadata[_index].blockchain_date);
    }

}