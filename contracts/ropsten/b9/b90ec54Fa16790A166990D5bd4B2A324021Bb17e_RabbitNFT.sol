// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./SignerRole.sol";

contract RabbitNFT is ERC1155, SignerRole {
    using SafeMath for uint256;

    uint256 public constant FEE_MAX_PERCENT = 200;
    string public name;
    bool public isPublic;
    uint256 public items;
    address public owner;

    event ItemAdded(uint256 id, uint256 maxSupply, uint256 supply);

    mapping(uint256 => address) private _creators;
    mapping(uint256 => uint256) private _creatorFee;
    mapping(uint256 => uint256) public totalSupply;
    mapping(uint256 => uint256) public circulatingSupply;

    constructor() ERC1155("") {}

    modifier onlyOwner() {
        require(owner == _msgSender(), "Caller is not the owner");
        _;
    }

    /**
        Derived contract must override function "supportsInterface".
        Two or more base classes define function with same name and parameter types
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC1155, AccessControl) returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    /**
		Initialize from Market contract
	 */
    function initialize(string memory _name, string memory _uri, address creator, bool bPublic) external {
        require(isFactory(creator), "Only for factory");
        _setURI(_uri);
        name = _name;
        owner = creator;
        isPublic = bPublic;

        addSigner(creator);
    }
    /**
        Chanage collection URI
     */
    function setURI(string memory newURI) public onlyOwner {
        _setURI(newURI);
    }
    /**
        Change collection name
    */
    function setName(string memory newName) public onlyOwner {
        name = newName;
    }
    /**
        Change collection as public or not
    */
    function setPublic(bool bPublic) public onlyOwner {
        isPublic = bPublic;
    }
    /**
        Create an Item by Only Signer
    */
    function addItem(uint256 maxSupply, uint256 supply, uint256 _fee) public returns (uint256) {
        require(isSigner(_msgSender()) || isPublic, "Only signer can add item");
        require(maxSupply > 0, "Max supply should be more than 0");
        require(supply < maxSupply, "Supply should be less than Max supply");
        require(_fee < FEE_MAX_PERCENT, "Too big creator fee");

        items = items.add(1);
        totalSupply[items] = maxSupply;
        circulatingSupply[items] = supply;

        _creators[items] = _msgSender();
        _creatorFee[items] = _fee;

        if (supply > 0) {
            _mint(_msgSender(), items, supply, "");
        }
        emit ItemAdded(items, maxSupply, supply);
        return items;
    }
    /**
        Check creator of item
    */
    function creatorOfItem(uint256 id) public view returns (address) {
        return _creators[id];
    }
    /**
        Check fee of item
    */
    function creatorFee(uint256 id) public view returns (uint256) {
        return _creatorFee[id];
    }
    /**
        Mint for only signers or creators
    */
    function mint(address to, uint256 id, uint256 amount) public returns (bool) {
        require(isSigner(_msgSender()) || creatorOfItem(id) == _msgSender(), "Only signer or creator can mint");
        require(circulatingSupply[id].add(amount) <= totalSupply[id], "Total supply reached");
        circulatingSupply[id] = circulatingSupply[id].add(amount);
        _mint(to, id, amount, "");
        return true;
    }
    /**
        Burn - Only Minters or cretors
    */
    function burn(address from, uint256 id, uint256 amount) public returns(bool){
        require(isSigner(_msgSender()) || creatorOfItem(id) == _msgSender(), "Only signer or creator can burn");
        circulatingSupply[id] = circulatingSupply[id].sub(amount);
        _burn(from, id, amount);
        return true;
    }
}