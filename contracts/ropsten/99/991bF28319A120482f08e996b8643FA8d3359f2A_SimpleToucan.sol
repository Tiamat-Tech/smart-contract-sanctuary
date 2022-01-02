pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract SimpleToucan is ERC721Enumerable, Ownable {

    using Strings for uint256;
    string _baseTokenURI;
    //TOUPACAPLYSE NOW
    uint256 private _price = 0.022 ether;
    bool public _paused = true;
    bool public _paused_premint = true;
    address private passwordSigner;

    constructor(
        string memory name,
        string memory symbol,
        string memory baseURI
    ) ERC721(name,symbol)  {
        setBaseURI(baseURI);
    }

    function setPasswordSigner(address signer) public onlyOwner {
        passwordSigner = signer;
    }


    function freebird(uint256 num) public payable {
        uint256 supply = totalSupply();
        require( !_paused,                      "Minting paused" );
        require( num < 30,                      "You can breed a maximum of 29 Toucans" );
        require( supply + num < 10002,          "Exceeds maximum Toucan supply" );
        require( msg.value >= _price * num,     "Eth sent is not correct" );
        for(uint256 i; i < num; i++){
            _safeMint( msg.sender, supply + i );
        }
    }

    function freebirdPremint(uint256 num) public payable {
        uint256 supply = totalSupply();
        require( !_paused_premint,               "Minting paused" );
        require( num < 3,                       "You can breed a maximum of 2 TravelToucans" );
        require( supply + num < 71,             "Exceeds maximum TravelToucans preminting supply" );
        require( msg.value >= _price * num,     "Eth sent is not correct" );
        for(uint256 i; i < num; i++){
            _safeMint( msg.sender, supply + i );
        }
    }

    function walletOfOwner(address _owner) public view returns(uint256[] memory) {
        uint256 tokenCount = balanceOf(_owner);
        uint256[] memory tokensId = new uint256[](tokenCount);
        for(uint256 i; i < tokenCount; i++){
            tokensId[i] = tokenOfOwnerByIndex(_owner, i);
        }
        return tokensId;
    }

    function setPrice(uint256 _newPrice) public onlyOwner() {
        _price = _newPrice;
    }

    function getPrice() public view returns (uint256){
        return _price;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }

    function setBaseURI(string memory baseURI) public onlyOwner {
        _baseTokenURI = baseURI;
    }

    function pause(bool val) public onlyOwner {
        _paused = val;
    }

    function pause_premint(bool val) public onlyOwner {
        _paused_premint = val;
    }

    function giveAway(address _to, uint256 _amount) external onlyOwner() {
        uint256 supply = totalSupply();
        require( supply + _amount < 10002,  "Exceeds maximum TravelToucans supply" );
        for(uint256 i; i < _amount; i++){
            _safeMint( _to, supply + i );
        }
    }

    function isWhitelisted(address user, bytes memory signature) public view returns (bool) {
        bytes32 messageHash = keccak256(abi.encode(user));
        bytes32 ethSignedMessageHash = getEthSignedMessageHash(messageHash);

        return recoverSigner(ethSignedMessageHash, signature) == passwordSigner;
    }

    function getEthSignedMessageHash(bytes32 _messageHash) private pure returns (bytes32) {
        /*
        Signature is produced by signing a keccak256 hash with the following format:
        "\x19Ethereum Signed Message\n" + len(msg) + msg
        */
        return
        keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", _messageHash)
        );
    }

    function recoverSigner(bytes32 _ethSignedMessageHash, bytes memory _signature) private pure returns (address) {
        (bytes32 r, bytes32 s, uint8 v) = splitSignature(_signature);
        return ecrecover(_ethSignedMessageHash, v, r, s);
    }

    function recoverSignerTest(bytes32 _ethSignedMessageHash, bytes memory _signature) private pure returns (address) {
        (bytes32 r, bytes32 s, uint8 v) = splitSignature(_signature);
        return ecrecover(_ethSignedMessageHash, v, r, s);
    }

    function splitSignature(bytes memory sig) private pure returns (bytes32 r, bytes32 s, uint8 v) {
        require(sig.length == 65, "sig invalid");

        assembly {
        /*
        First 32 bytes stores the length of the signature

        add(sig, 32) = pointer of sig + 32
        effectively, skips first 32 bytes of signature

        mload(p) loads next 32 bytes starting at the memory address p into memory
        */

        // first 32 bytes, after the length prefix
            r := mload(add(sig, 32))
        // second 32 bytes
            s := mload(add(sig, 64))
        // final byte (first byte of the next 32 bytes)
            v := byte(0, mload(add(sig, 96)))
        }

        // implicitly return (r, s, v)
    }
}