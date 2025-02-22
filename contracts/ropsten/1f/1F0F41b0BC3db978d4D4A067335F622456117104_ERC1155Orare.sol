// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;
pragma experimental ABIEncoderV2;
import "./openzeppelin/token/ERC1155/ERC1155Pausable.sol";
import "./openzeppelin/access/Ownable.sol";

/**
 * @title ERC1155Orare- ERC1155 contract for Orare
 */

contract ERC1155Orare is ERC1155Pausable, Ownable {
    using SafeMath for uint256;

    mapping(uint256 => uint256) private tokenSupply;

    mapping(uint256 => string) private _tokenURIs;

    uint256 public _currentTokenID = 0;

    mapping(address => bool) isMinterContract;

    event TokenCreated(
        address indexed to,
        uint256 id,
        uint256 initialSupply,
        string uri,
        bytes data
    );

    event TokenMinted(
        address indexed to,
        uint256 id,
        uint256 value,
        bytes data
    );

    constructor(string memory uri, address owner) ERC1155(uri) Ownable() {}

    function setURI(string memory newuri) public onlyOwner {
        _setURI(newuri);
    }

    /**
    * @dev Creates a new token type and assigns _initialSupply to an address
    * NOTE: remove onlyOwner if you want third parties to create new tokens on your contract (which may change your IDs)
    * @param _to which account NFT to be minted
    * @param _initialSupply amount to supply the first owner
    * @param _Uri Optional URI for this token type
    * @param _data Data to pass if receiver is contract
    
    * @return The newly created token ID
    */
    function create(
        address _to,
        uint256 _initialSupply,
        string calldata _Uri,
        bytes calldata _data
    ) external onlyGameContract returns (uint256) {
        uint256 _id = _getNextTokenID();
        _incrementTokenTypeId();

        if (bytes(_Uri).length > 0) {
            emit URI(_Uri, _id);
        }

        _mint(_to, _id, _initialSupply, _data);
        tokenSupply[_id] = _initialSupply;
        //set token uri
        _setTokenUri(_id, _Uri);

        emit TokenCreated(_to, _id, _initialSupply, _Uri, _data);
        return _id;
    }

    //set contract account that can mint & burn
    function setContract(address _GameContract)
        external
        onlyOwner
        returns (bool)
    {
        isMinterContract[_GameContract] = true;
        return true;
    }

    function mint(
        address to,
        uint256 id,
        uint256 value,
        bytes memory data
    ) public onlyGameContract returns (bool) {
        _mint(to, id, value, data);
        tokenSupply[id] = tokenSupply[id].add(value);
        emit TokenMinted(to, id, value, data);
        return true;
    }

    function mintBatch(
        address to,
        uint256[] memory ids,
        uint256[] memory values,
        bytes memory data
    ) public onlyGameContract returns (bool) {
        _mintBatch(to, ids, values, data);
        for (uint256 i = 0; i < ids.length; i++) {
            tokenSupply[ids[i]] = tokenSupply[ids[i]].add(values[i]);
            emit TokenMinted(to, ids[i], values[i], data);
        }
        return true;
    }

    function burn(
        address owner,
        uint256 id,
        uint256 value
    ) public returns (bool) {
        require(
            owner == _msgSender() || isApprovedForAll(owner, _msgSender()),
            "ERC1155: caller is not owner nor approved"
        );
        _burn(owner, id, value);
        tokenSupply[id] = tokenSupply[id].sub(value);

        return true;
    }

    function burnBatch(
        address owner,
        uint256[] memory ids,
        uint256[] memory values
    ) public returns (bool) {
        require(
            owner == _msgSender() || isApprovedForAll(owner, _msgSender()),
            "ERC1155: caller is not owner nor approved"
        );
        _burnBatch(owner, ids, values);

        for (uint256 i = 0; i < ids.length; i++) {
            tokenSupply[ids[i]] = tokenSupply[ids[i]].sub(values[i]);
        }
        return true;
    }

    function _getNextTokenID() private view returns (uint256) {
        return _currentTokenID.add(1);
    }

    function totalIDs() external view returns (uint256) {
        return _currentTokenID;
    }

    /**
     * @dev increments the value of _currentTokenID
     */
    function _incrementTokenTypeId() private {
        _currentTokenID++;
    }

    /**
     * @dev Throws if called by any account other than the minter.
     */
    modifier onlyGameContract() {
        require(
            isGameContract() || _msgSender() == owner(),
            "caller is not the Game contract"
        );
        _;
    }

    /**
     * @dev Returns true if the caller is the current minter.
     */
    function isGameContract() private view returns (bool) {
        return isMinterContract[_msgSender()];
    }

    /**
     * @dev Returns the total quantity for a token ID
     * @param _id uint256 ID of the token to query
     * @return amount of token in existence
     */
    function totalSupply(uint256 _id) public view returns (uint256) {
        return tokenSupply[_id];
    }

    /**
     * @dev Returns the balances of all tokens owned by the sender
     * @return result returns Array of Ids of tokens owned by the sender
     */
    function getAllTokensOwned(address senderAddr)
        public
        view
        returns (uint256[] memory)
    {
        uint256 currIndx = 0;
        uint256[] memory result = new uint256[](_currentTokenID);
        for (uint256 count = 1; count <= _currentTokenID; count++) {
            uint256 balance = balanceOf(senderAddr, count);
            if (balance > 0) {
                result[currIndx] = count;
                currIndx++;
            }
        }
        uint256[] memory trimmedResult = new uint256[](currIndx);
        for (uint256 j = 0; j < trimmedResult.length; j++) {
            trimmedResult[j] = result[j];
        }
        return trimmedResult;
    }

    function _setTokenUri(uint256 _tokenId, string memory _tokenUri)
        internal
        virtual
    {
        require(_exists(_tokenId), "Setting URI for non-existent token");
        _tokenURIs[_tokenId] = _tokenUri;
    }

    function _exists(uint256 _tokenId) internal view virtual returns (bool) {
        return _tokenId == _currentTokenID;
    }

    function getTokenUri(uint256 _tokenId) public view returns (string memory) {
        return _tokenId <= _currentTokenID ? _tokenURIs[_tokenId] : "";
    }
}