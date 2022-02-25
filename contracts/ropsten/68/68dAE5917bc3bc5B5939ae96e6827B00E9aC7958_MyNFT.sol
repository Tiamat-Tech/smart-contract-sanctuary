//Contract based on https://docs.openzeppelin.com/contracts/3.x/erc721
// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


// POUR POUVOIR PAYER LE NFT DIRECTEMENT DANS LE CONTRAT IL FAUT : 
// //set up transaction parameters
//  const transactionParameters = {
//     to: contractAddress, // Required except during contract publications.
//     from: address, // must match user's active address.
//     data: helloWorldContract.methods.update(message).encodeABI(),
//   };
// 
// //sign the transaction
//   try {
//     const txHash = await window.ethereum.request({
//       method: "eth_sendTransaction",
//       params: [transactionParameters],
//     });


contract MyNFT is ERC721, Ownable {
    address public constant _MAIN_ADDRESS = 0x9C21c877B44eBac7F0E8Ee99dB4ebFD4A9Ac5000;
    uint256 public constant _PRICE = 0.4 ether;
    uint256 public constant _MAX_SUPPLY = 5555;
    uint256 public constant _MAX_HOLDING = 5;
    uint256 public constant _MAX_HOLDING_SEC_MKT = 20;
    address[2] public _TEAM_ADDRESSES = [
        0x9C21c877B44eBac7F0E8Ee99dB4ebFD4A9Ac5000,
        0xDb978Cfc17a3383c033913B945A2501A4C547973
    ];
    // Test Address (from Remix IDE)
    // address[] public _TEAM_ADDRESSES = [
    //     0x5B38Da6a701c568545dCfcB03FcB875f56beddC4,
    //     0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2
    // ];
    mapping(address => bool) _TEAM_ADDRESSES_DICT;

    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    uint256[] private _tokenIdsList;
    mapping (uint256 => string) public _tokenURIs;
    mapping (uint256 => address) private _tokenOwners;
    address[] public holders;
    mapping(string => uint8) public hashes;

    constructor() ERC721("MyNFT", "NFT")
    {
        for (uint256 iAddress = 0; iAddress < _TEAM_ADDRESSES.length; iAddress++)
        {
            address teamAddress = _TEAM_ADDRESSES[iAddress];
            giveaway(teamAddress, "{}");
            _TEAM_ADDRESSES_DICT[teamAddress] = true;
        }
    }

    function mintNFT(address recipient, string memory tokenURI)
        public payable onlyOwner
        returns (uint256)
    {
        require(msg.value >= _PRICE, "Not enough ETH to mint");
        return giveaway(recipient, tokenURI);
    }

    function giveaway(address recipient, string memory tokenURI)
        public onlyOwner
        returns (uint256)
    {
        _tokenIds.increment();
        require(_tokenIds.current() <= _MAX_SUPPLY, "No more NFT to mint");
        require(balanceOf(recipient) < _MAX_HOLDING || _TEAM_ADDRESSES_DICT[recipient], "Max holded NFTs is reached");

        uint256 newItemId = _tokenIds.current();
        _mint(recipient, newItemId);
        _tokenOwners[newItemId] = recipient;
        _tokenIdsList.push(newItemId);
        _setTokenURI(newItemId, tokenURI);
        
        bool add_to_holders = true;
        for (uint256 i = 0; i < holders.length; i++)
        {
            if (holders[i] == recipient)
            {
                add_to_holders = false;
            }
        }
        if (add_to_holders)
        {
            holders.push(recipient);
        }

        return newItemId;
    }

    function burnNFT(uint256 tokenId)
        public onlyOwner
    {
        address owner = _tokenOwners[tokenId];
        _burn(tokenId);
        delete _tokenURIs[tokenId];
        delete _tokenOwners[tokenId];
        delete _tokenIdsList[tokenId];

        uint256 balance_of_owner = balanceOf(owner);
        if (balance_of_owner == 0)
        {
            uint256 idx_to_delete;
            for (uint256 i = 0; i < holders.length; i++)
            {
                if (holders[i] == owner)
                {
                    idx_to_delete = i;
                }
            }
            delete holders[idx_to_delete];
        }

    }

    function transferFrom(address from, address to, uint256 tokenId)
        public
        override
    {
        require(balanceOf(to) < _MAX_HOLDING_SEC_MKT, "Max holding on secondary market has been reached");
        super.transferFrom(from, to, tokenId);
    }

    function _setTokenURI(uint256 tokenId, string memory _tokenURI)
        internal onlyOwner
        // override(ERC721)
    {
        require(_exists(tokenId), "ERC721URIStorage: URI set of nonexistent token");
        _tokenURIs[tokenId] = _tokenURI;
    }

    function getTokenIds()
        public view onlyOwner
        returns (uint256[] memory)
    {
        return _tokenIdsList;
    }
    
    function getTokenIdsOf(address addr)
        public view onlyOwner
        returns (uint256[] memory)
    {
        uint256 count = balanceOf(addr);
        uint256[] memory tokenIds = new uint256[](count);
        uint256 foundTokens = 0;
        for (uint256 i; i < _tokenIdsList.length; i++)
        {
            uint256 tokenId = _tokenIdsList[i];
            if (_tokenOwners[tokenId] == addr)
            {
                tokenIds[foundTokens] = tokenId;
                foundTokens++;
            }
        }
    
        return tokenIds;
    }

    function getCurrentSupply()
        public view
        returns (uint256)
    {
        // return _tokenIds.current();
        return _tokenIdsList.length;
    }

    function getHolders()
        external view
        returns (address[] memory)
    {
        return holders;
    }

    function withdraw()
        public 
        payable
    {
        uint256 amount = address(this).balance;
        bool success = payable(_MAIN_ADDRESS).send(amount);
        require(success, "Failed to withdraw");
    }
}