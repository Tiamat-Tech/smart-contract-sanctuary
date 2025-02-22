// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @dao: MEME
/// @author: Wizard

/************************************

      (          )       )           
    )\ )    ( /(    ( /(    *   )  
    (()/(    )\())   )\()) ` )  /(  
    /(_))  ((_)\   ((_)\   ( )(_)) 
    (_))_     ((_)   _((_) (_(_())  
    |   \   / _ \  | \| | |_   _|  
    | |) | | (_) | | .` |   | |    
    |___/   \___/  |_|\_|   |_|    

                    (         )     
      (            )\ )   ( /(     
    ( )\      (   (()/(   )\())    
    )((_)     )\   /(_)) ((_)\     
    ((_)_   _ ((_) (_))    _((_)    
    | _ ) | | | | | _ \  | \| |    
    | _ \ | |_| | |   /  | .` |    
    |___/  \___/  |_|_\  |_|\_|    

      *              *             
    (  `           (  `            
    )\))(    (     )\))(    (      
    ((_)()\   )\   ((_)()\   )\     
    (_()((_) ((_)  (_()((_) ((_)    
    |  \/  | | __| |  \/  | | __|   
    | |\/| | | _|  | |\/| | | _|    
    |_|  |_| |___| |_|  |_| |___|   

************************************/

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

interface IFuelToken {
    function mint(address account) external;
}

contract DontBurnMeme is ERC1155, Ownable {
    using Strings for uint256;
    IFuelToken public fuelToken;

    // Mapping from token ID to media key
    mapping(uint256 => string) private _tokenMedia;
    address public minter;
    string private _contractUri;
    uint256 public unlockFuel;

    constructor(
        address _minter,
        string memory _uri,
        string memory contractUri,
        address _fuelToken
    ) ERC1155(_uri) {
        fuelToken = IFuelToken(_fuelToken);
        minter = _minter;
        _contractUri = contractUri;
    }

    modifier onlyMinter() {
        require(
            owner() == _msgSender() || minter == _msgSender(),
            "must be owner or minter"
        );
        _;
    }

    function contractURI() public view returns (string memory) {
        return _contractUri;
    }

    function symbol() public pure returns (string memory) {
        return "MOON";
    }

    function name() public pure returns (string memory) {
        return "Dont Burn MEME";
    }

    function setUnlockFuel(uint256 tokenId) public virtual onlyOwner {
        unlockFuel = tokenId;
    }

    function setContractUri(string memory _uri) public virtual onlyOwner {
        _contractUri = _uri;
    }

    function setMinter(address _minter) public virtual onlyOwner {
        minter = _minter;
    }

    function setURI(string memory newuri) public virtual onlyOwner {
        _setURI(newuri);
    }

    function setTokenMedia(uint256 id, string memory key)
        public
        virtual
        onlyOwner
    {
        _setTokenMedia(id, key);
    }

    function mint(
        address account,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public onlyMinter {
        if (_isMediaEmpty(_tokenMedia[id]) == true) {
            _setTokenMedia(id, id.toString());
        }
        _mint(account, id, amount, data);
    }

    function uri(uint256 id) public view override returns (string memory) {
        string memory _uri = _tokenMedia[id];
        if (bytes(_uri).length > 0) {
            return string(abi.encodePacked(super.uri(id), _uri));
        } else {
            revert("no uri data set for token id");
        }
    }

    function burn(
        address account,
        uint256 id,
        uint256 value
    ) public virtual {
        require(
            account == _msgSender() || isApprovedForAll(account, _msgSender()),
            "caller is not owner nor approved"
        );

        _burn(account, id, value);
        _afterBurn(account, id, value);
    }

    function burnBatch(
        address account,
        uint256[] memory ids,
        uint256[] memory values
    ) public virtual {
        require(
            account == _msgSender() || isApprovedForAll(account, _msgSender()),
            "caller is not owner nor approved"
        );

        _burnBatch(account, ids, values);
        _afterBurn(account, ids[0], values[0]);
    }

    function _setTokenMedia(uint256 id, string memory key) internal virtual {
        _tokenMedia[id] = key;
    }

    function _afterBurn(
        address account,
        uint256 id,
        uint256 value
    ) internal virtual {
        uint256 nextId = id + 1;
        uint256 mustBurn = id + 1;
        if (value >= mustBurn) {
            if (_isMediaEmpty(_tokenMedia[nextId])) {
                _setTokenMedia(nextId, nextId.toString());
            }
            if (nextId == unlockFuel) {
                fuelToken.mint(account);
            }
            _mint(account, nextId, 1, "");
        }
    }

    function _isMediaEmpty(string memory tokenMedia)
        internal
        virtual
        returns (bool)
    {
        bytes memory mediaToken = bytes(tokenMedia);

        if (mediaToken.length == 0) {
            return true;
        } else {
            return false;
        }
    }
}