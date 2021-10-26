// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import 'base64-sol/base64.sol';

contract loveletters_V2 is Ownable, ERC721Enumerable {
    using Counters for Counters.Counter;
    //Relevant mappings
    Counters.Counter private _tokenIdTracker;
    uint256 private _price;

    uint256 public maxSupply;
    bool public saleStarted = true;

    mapping(uint256 => string) private tokenIdToLetter;
    mapping(uint256 => string) private tokenIdToSenderName;
    mapping(uint256 => string) private tokenIdToRecipientName;

    address public constant staffVaultAddress =
        0xd55883D964ad3299Aa099Fae555989FBCe0De6bD;

    event SaleState(bool);
    event LetterWritten(
        uint256 letterid,
        address author_address,
        address to_address,
        string author_name,
        string recipient_name,
        string content
    );

    function toString(uint256 value) internal pure returns (string memory) {
    // Inspired by OraclizeAPI's implementation - MIT license
    // https://github.com/oraclize/ethereum-api/blob/b42146b063c7d6ee1358846c198246239e9360e8/oraclizeAPI_0.4.25.sol

        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

    //Constructor
    constructor(
        string memory name_,
        string memory symbol_,
        uint256 maxSupply_,
        uint256 price_
    ) ERC721(name_, symbol_) {
        maxSupply = maxSupply_;
        _price = price_;

        _tokenIdTracker.increment(); //Start at index 1
    }

    function mint(address to) internal {
        _safeMint(to, _tokenIdTracker.current());
        _tokenIdTracker.increment();
    }

    function writeLetter(
        string memory letter,
        address to,
        string memory recipientName,
        string memory senderName
    ) public payable {
        require(
            saleStarted
        );
        require(to != msg.sender, "Letters are for other people!");
        require(msg.value >= viewPrice(), "sent insufficient Ether");
        require(totalSupply() + 1 <= maxSupply, "We are out of stamps!");
        tokenIdToLetter[_tokenIdTracker.current()] = letter;
        tokenIdToRecipientName[_tokenIdTracker.current()] = recipientName;
        tokenIdToSenderName[_tokenIdTracker.current()] = senderName;
        mint(to);

        emit LetterWritten(
            _tokenIdTracker.current(),
            msg.sender,
            to,
            senderName,
            recipientName,
            letter
        );
    }

    function staffWrite(
        string memory letter,
        address to,
        string memory recipientName,
        string memory senderName
    ) public onlyOwner {
        tokenIdToLetter[_tokenIdTracker.current()] = letter;
        tokenIdToRecipientName[_tokenIdTracker.current()] = recipientName;
        tokenIdToSenderName[_tokenIdTracker.current()] = senderName;
        mint(to);

        emit LetterWritten(
            _tokenIdTracker.current(),
            msg.sender,
            to,
            senderName,
            recipientName,
            letter
        );
    }

    function readLetter(uint256 tokenId) public view returns (string memory) {
        return string(tokenIdToLetter[tokenId]);
    }

    function withdrawAll() public payable onlyOwner {
        uint256 balance = address(this).balance;
        payable(staffVaultAddress).transfer(balance);
    }


    //tokenURI function
    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        string[9] memory parts;
        parts[
            0
        ] = '<svg xmlns="http://www.w3.org/2000/svg" width="256" height="239" fill="none" xmlns:v="https://vecta.io/nano"><defs><style></style></defs><style><![CDATA[.D,.d{font-family:Damion}.E{fill:#3116da}.F,.d{font-size:12px}]]></style><path fill="#000" d="M256 0H0v239h256V0Z"/><path fill="#fff" d="m192 0-2 3-2 2-3 1h-4l-2-3-1-2h-1l-3 2c0 2-3 3-5 3l-7-1-4-2-2 1-4 2c-3 0-5-1-5-2l-3-1-4 1c-1 2-2 2-4 2h-3l-3-3-2-1h-2l-1 1-3 3c-3 1-7 0-8-2l-1-1h-3l-2 1c-1 2-2 2-5 2-2 0-3 0-4-2l-3-1h-2l-2 1-4 2-4-1-2-1c-1-2-1-2-2-1l-2 1-3 1h-7l-2-1-2-2c-2-1-4 0-4 1l-3 2c-2 1-5 0-6-1l-1-1-4-1c-1 0-2 0-3 2a7 7 0 0 1-2 1h-3c-4 0-4 0-5-2l-2-1c-2 0-3 0-5 2l-2 1h-4l-4-2-3-1-2 1-6 3H2L1 7v4l2 2 3 1v4a29 29 0 0 1-3 2l-2 2 1 3a16 16 0 0 1 2 0c2 1 3 2 3 4s-1 3-3 4-2 1-2 3v1h1a4 4 0 0 1 3 2v3l-3 3-2 1-1 2v1h2l4 2c1 1 0 3-2 5l-2 3 1 2 3 2v3l-2 3c-2 1-2 2-2 3l2 2 2 2c1 2-1 3-3 3s-3 1-2 3l2 3 3 2c1 2 0 5-3 6-3 0-3 1-2 2s1 2 3 2l2 2c1 3 0 5-3 6l-2 2 2 2c4 2 4 4 1 6l-1 2c-1 3-1 4 2 5l2 3-1 2-2 2c-2 0-2 1-2 2l2 3c2 1 3 2 3 4l-1 1-3 3-2 1 4 3c1 1 2 4 1 6l-3 1-1 1-1 2 2 1c1 1 3 2 3 4s0 2-2 3l-3 4c0 1 0 2 1 1l4 2v4l-2 2-3 3c-1 1 0 1 1 2l3 2 1 3-4 2-1 1c-1 2 0 3 2 3l3 3c1 2-1 4-3 5s-3 1-2 3l2 2 3 2v4l-4 1-1 2c-1 2 0 2 2 3s3 2 3 4 0 2-2 3l-3 3c-1 1 0 1 1 2l4 2 1 1a9 9 0 0 1 2 2l2 2 4-2 4-2c3-1 3 0 4 3l1 1h5l2-2c2-2 3-2 5-2h3l2 3c1 1 1 2 3 2l3-3 2-2h4c2 0 4 1 4 3l2 1 3 1 1-2 3-3h5l3 2v2h1l5-2 4-2c2-1 3 0 5 1l5 2 2-1 5-2c3 0 5 1 5 2l1 2h3a16 16 0 0 0 4-4h6l1 2 2 1h3c1 0 2 0 3-2 2-1 4-2 6-1l2 1c2 2 4 3 6 2l2-2 4-1c3-1 5 0 5 2l1 1a15 15 0 0 0 2 1h2l1-1c0-2 3-3 6-3l3 1c0 2 2 3 5 3l2-1c1-2 4-4 7-3l4 2a3 3 0 0 0 1 1l4 2 1-1c0-2 1-4 3-4h5l3 2c1 1 1 2 3 2s2 0 3-2l3-2c2-1 5 0 6 1v2l2 3c2 0 2 0 3-2l5-4a16 16 0 0 1 5 0l1 2 4 2h2l3-4h8l-2-3-2-2v-2c0-2 1-2 4-3h2v-1c0-2-1-2-3-3l-3-3 1-3a10 10 0 0 1 3-1c3-1 3-1 2-3l-3-2-2-2-1-3 3-2 3-2v-2l-3-3-2-1v-2l1-2 4-1c2 0 2 0 1-1v-1l-2-2c-3-1-5-2-5-4s2-4 5-4l2-1-2-3c-1 1-3-1-4-2v-3c0-2 0-2 3-2l2-2c0-2-1-3-4-4l-1-2c-1-1-1-2 1-4 2-1 2-3 2-4l-1-2c-3-2-3-3-2-5l4-2c2 0 2 0 2-3l-1-2h-2l-2-1c-2-1-2-4 0-6h2l2-2-3-3-2-2 1-4a11 11 0 0 1 4-1v-3a3 3 0 0 0-2-2c-3-1-4-3-3-5l4-2h1l1-3-3-2a30 30 0 0 1-2-2l-1-2 1-2 3-1c1-1 2-3 1-4l-2-1c-3-1-3-1-3-3l2-4 3-1-1-3-2-1-2-3c-1-2 0-3 3-4l3-3-3-2c-2-1-3-2-3-4l1-2 2-1 3-2v-2l-3-1-3-3v-3l2-1 2-1c2 0 2 0 2-2l-1-3h-1c-3 0-4-2-4-5l3-2c3-1 3-1 3-3l-4-3h-1v-5l3-1c2-1 3-2 2-3l-3-2-3-3 1-3 1-1h-1l-2-1c-1 0-2 0-3-2l-5-1-2 2-3 1a9 9 0 0 1-4 0l-3-2-3-1-3 1-4 3-6-2c-1-2-2-2-4-1l-3 1-3 2-4-1-3-4V0h-3z"/><text xml:space="preserve" letter-spacing="0em" style="white-space:pre" class="D E F"><tspan x="18" y="58.9">Dear  </tspan></text><text xml:space="preserve" fill="#000" letter-spacing="0em" style="white-space:pre" class="D F"><tspan x="46.7" y="58.9">';

        parts[1] = tokenIdToRecipientName[tokenId];

        parts[
            2
        ] = '</tspan></text><text xml:space="preserve" style="white-space:pre" letter-spacing="0em" class="B C D"><tspan x="18" y="200.9">Love,</tspan></text><text fill="#000" xml:space="preserve" style="white-space:pre" letter-spacing="0em" class="B D"><tspan x="18" y="216.9">';

        parts[3] = tokenIdToSenderName[tokenId];

        parts[
            4
        ] = '</tspan></text><path d="M19 22.6l5.6-3.7 5 3.7-3.2 3-7.4-3z" fill="#e4a649"/><path d="M43 23.2L36.2 19l-2 6.7 8.6-2.5z" fill="#b5f42e"/><path d="M19 31.4L36.2 19l-3 12.5H19z" fill="#e6f15f"/><path d="M19 30.5v-7.7l7.7 2.7-7.7 5z" fill="#bb3030"/><path d="M30.3 40L19 31.4h8.6l2.7 8.7z" fill="#801ecd"/><path d="M43 31.4H28.5L31 40 43 31.4z" class="C"/><path d="M33.3 31.4l1.7-6 8-2.7v8.6h-9.6z" fill="#42da51"/><path d="M36 18l-5.6 4-5.6-4-7 4.4v8.7L30.5 41 43 31.2v-8.7L36 18zm-11 7.7l-5.8 4v-6l5.8 2zm5.3-2l4.6-3.3-2.6 9.8H20.7l9.7-6.6h0zm6-3.8l4.3 2.8-5.5 2 1.2-4.7zm-9 11.7l2 6.8-8.6-6.8h6.8zm1.4 0h11.6L30.8 39l-2-7.5zm12.8-1.4h-7.8l1-4 6.7-2.3v6.4h0zm-12.3-7.4l-2.8 2-6.3-2 4.6-3 4.5 3.2z" fill="#000"/><text xml:space="preserve" style="white-space:pre" font-size="24" letter-spacing="0em" class="B C"><tspan x="50" y="36.2">#';

        parts[5] = toString(tokenId);

        parts[
            6
        ] = '</tspan></text><text fill="#575757" xml:space="preserve" style="white-space:pre" letter-spacing="0em" class="B D"><tspan x="18" y="80.9">';

        parts[7] = string(tokenIdToLetter[tokenId]);

        parts[
            8
        ] = '</tspan></text><path d="M218 18h24v24h-24zm0 179h24v24h-24z" class="C"/></svg>';
        string memory output = string(
            abi.encodePacked(
                parts[0],
                parts[1],
                parts[2],
                parts[3],
                parts[4],
                parts[5],
                parts[6],
                parts[7],
                parts[8]
            )
        );
        string memory json = Base64.encode(
            bytes(
                string(
                    abi.encodePacked(
                        '{"name": "Letter #',
                        toString(tokenId),
                        '", "description": "Love Letters descrption", "image": "data:image/svg+xml;base64,',
                        Base64.encode(bytes(output)),
                        '"}'
                    )
                )
            )
        );
        output = string(
            abi.encodePacked("data:application/json;base64,", json)
        );

        return output;
    }

    function viewPrice() public view returns (uint256) {
        return _price;
    }
  }