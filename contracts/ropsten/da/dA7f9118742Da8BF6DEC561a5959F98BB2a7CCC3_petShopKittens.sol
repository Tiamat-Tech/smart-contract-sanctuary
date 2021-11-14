// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract petShopKittens is ERC1155, Ownable {
    mapping(uint256 => string) public _uris;
    using Counters for Counters.Counter;
    Counters.Counter private _catIdCounter;

    // uint public constant kashtan = 0;
    // uint public constant puzatik = 1;
    // uint public constant pepelniy = 2;
    // uint public constant rijik = 3;
    // uint public constant polosatik = 4;
    constructor()
        ERC1155(
            "https://bafybeib2xajvz3dwej3qkr73arr2qs5on5xxuu6ncq34hv72slyertjtv4.ipfs.dweb.link/{id}.json"
        )
    {
        //  _mint(msg.sender, kashtan, 1, "");
        //  _mint(msg.sender, puzatik, 1, "");
        //  _mint(msg.sender, pepelniy, 1, "");
        //  _mint(msg.sender, rijik, 1, "");
        // //  _mint(msg.sender, polosatik, 1, "");
    }

    // function uri( uint256  tokenId) override public view returns(string memory) {
    //     return(string(abi.encodePacked("https://bafybeib2xajvz3dwej3qkr73arr2qs5on5xxuu6ncq34hv72slyertjtv4.ipfs.dweb.link/",Strings.toString(tokenId),".json")));
    // }

    function mint(
        address account,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public onlyOwner {
        _catIdCounter.increment();
        _mint(account, id, amount, data);
    }

    function getLastId() public view onlyOwner returns (uint256) {
        return _catIdCounter.current() - 1;
    }

    function mintBatch(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public onlyOwner {
        _mintBatch(to, ids, amounts, data);
    }

    function uri(uint256 id) public view override returns (string memory) {
        return (_uris[id]);
    }

    function setURI(uint256 id, string memory uri) public onlyOwner {
        require(bytes(_uris[id]).length == 0, "already exists");
        _uris[id] = uri;
    }
}