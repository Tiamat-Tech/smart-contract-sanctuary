//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title ERC1155DataStorage
 * @author gotbit
 */

import './ERC1155Extended.sol';

contract ERC1155DataStorage is ERC1155Extended {
    struct Data {
        string name_;
        address artist;
        uint256 grade;
        uint256 power;
        string rarity;
        uint256 nftPrice;
    }

    constructor(
        string memory name_,
        string memory symbol_,
        address owner_
    ) ERC1155Extended(name_, symbol_, owner_) {}

    mapping(uint256 => Data) public datas;

    event UpdatedTokenData(uint256 indexed id, Data data_);

    /// @dev creates new id of token
    function create(string memory uri_, Data memory data_)
        external
        onlyRole(CREATOR_ROLE)
        returns (uint256 id)
    {
        emit Created(msg.sender, idCounter);
        idCounter++;

        setTokenURI(idCounter - 1, uri_);
        setTokenData(idCounter - 1, data_);
        return idCounter - 1;
    }

    function setTokenData(uint256 id, Data memory data_)
        public
        exist(id)
        onlyRole(CREATOR_ROLE)
    {
        datas[id] = data_;
        emit UpdatedTokenData(id, data_);
    }

    function data(uint256 id) external view exist(id) returns (Data memory data_) {
        return datas[id];
    }

    function infoBundleForTokenData(uint256 id)
        external
        view
        returns (string memory uri_, Data memory data_)
    {
        return (uri(id), datas[id]);
    }

    struct InfoUserData {
        uint256 id;
        uint256 balance;
        string uri;
        Data data;
    }

    function infoBundleForUserData(address user)
        external
        view
        returns (InfoUserData[] memory infoUserData)
    {
        InfoUserData[] memory infoUserData_ = new InfoUserData[](idCounter);
        for (uint256 id = 0; id < idCounter; id++) {
            infoUserData_[id] = InfoUserData({
                id: id,
                balance: balanceOf(user, id),
                uri: uri(id),
                data: datas[id]
            });
        }
        return infoUserData_;
    }
}