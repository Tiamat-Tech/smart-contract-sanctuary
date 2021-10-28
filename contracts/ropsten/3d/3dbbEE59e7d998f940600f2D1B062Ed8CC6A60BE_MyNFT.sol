//Contract based on https://docs.openzeppelin.com/contracts/3.x/erc721
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract MyNFT is ERC721, Ownable {
    uint256 private totalNumberOfItems = 6000;
    uint256[6000] private _availableTokens;
    uint256 private _numAvailableTokens = 6000;

    uint256 public mintPrice;
    string private baseURI;

    constructor() public ERC721("MyNFT", "NFT") {
        baseURI = "https://my-json-server.typicode.com/Tarekka/demo/posts/";
        mintPrice = 0.0024 ether;
    }

    function baseTokenURI() public view returns (string memory) {
        return _baseURI();
    }

    // Testing ether functions//
    //function deposit() public payable {}

    // Function to withdraw all Ether from this contract.
    function withdraw() public {
        uint256 amount = address(this).balance;
        (bool success, ) = owner().call{value: amount}("");
        require(success, "Failed to send Ether");
    }

    function mintNFT(uint256 itemsToMint) public payable {
        require(
            _numAvailableTokens >= itemsToMint,
            "Number exceeds available items"
        );
        require((mintPrice * itemsToMint) <= msg.value, "Sent less than price");
        //require(_numAvailableTokens >= 1, "Number exceeds available items");
        //require(mintPrice <= msg.value, "Sent less than price");
        //uint256 newItemId = useRandomAvailableToken(1, 1);
        //_safeMint(msg.sender, newItemId);
        //uint256 updatedNumAvailableTokens = _numAvailableTokens;
        for (uint256 i = 0; i < itemsToMint; i++) {
            uint256 newItemId = useRandomAvailableToken(itemsToMint, i);
            _safeMint(msg.sender, newItemId);
            //updatedNumAvailableTokens--;
        }
        //_numAvailableTokens = updatedNumAvailableTokens;

        //uint256 newItemId = useRandomAvailableToken(1, 1);
        //_mint(recipient, newItemId);
        //_setTokenURI(newItemId, newItemId);

        //return newItemId;
    }

    function useRandomAvailableToken(uint256 _numToFetch, uint256 _i)
        internal
        returns (uint256)
    {
        uint256 randomNum = uint256(
            keccak256(
                abi.encode(
                    msg.sender,
                    tx.gasprice,
                    block.number,
                    block.timestamp,
                    blockhash(block.number - 1),
                    _numToFetch,
                    _i
                )
            )
        );
        uint256 randomIndex = randomNum % _numAvailableTokens;
        return useAvailableTokenAtIndex(randomIndex);
    }

    function useAvailableTokenAtIndex(uint256 indexToUse)
        internal
        returns (uint256)
    {
        uint256 valAtIndex = _availableTokens[indexToUse];
        uint256 result;
        if (valAtIndex == 0) {
            // This means the index itself is still an available token
            result = indexToUse;
        } else {
            // This means the index itself is not an available token, but the val at that index is.
            result = valAtIndex;
        }

        uint256 lastIndex = _numAvailableTokens - 1;
        if (indexToUse != lastIndex) {
            // Replace the value at indexToUse, now that it's been used.
            // Replace it with the data from the last index in the array, since we are going to decrease the array size afterwards.
            uint256 lastValInArray = _availableTokens[lastIndex];
            if (lastValInArray == 0) {
                // This means the index itself is still an available token
                _availableTokens[indexToUse] = lastIndex;
            } else {
                // This means the index itself is not an available token, but the val at that index is.
                _availableTokens[indexToUse] = lastValInArray;
            }
        }

        _numAvailableTokens--;
        return result;
    }

    function tokenURI(uint256 _tokenId)
        public
        view
        override
        returns (string memory)
    {
        string memory base = _baseURI();
        string memory _tokenURI = Strings.toString(_tokenId);
        return string(abi.encodePacked(base, _tokenURI));
    }

    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    function getNumAvailableTokens() public view returns (string memory) {
        string memory _nAVI = Strings.toString(_numAvailableTokens);
        string memory _tSup = Strings.toString(totalSupply());
        return string(abi.encodePacked(_nAVI, " ", _tSup));
    }

    function totalSupply() internal view returns (uint256) {
        return totalNumberOfItems - _numAvailableTokens;
    }

    function canMintMonster(
        address addr,
        uint256 character,
        uint256 weapon
    ) public view returns (bool) {
        require(
            ownerOf(character) == addr && ownerOf(weapon) == addr,
            "You do not own these items!"
        );
        require(
            (weapon % 3000) == character,
            "Weapon doesn't match your character!"
        );
        return true;
    }
}