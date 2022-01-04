// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

contract OutlierNFT is ERC721URIStorage {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    uint256 m_nUserTokenIds;
    uint256 m_nDevTokenIds;
    uint256 mintingFeeForEth = 0.008 ether;
    uint256 public constant TOTAL_SPPLY = 11111;
    uint256 public constant DEV_SUPPLY = 111;
    address payable m_addrOwner;
    string BASE_URL = "https://gateway.pinata.cloud/ipfs/QmPQgFsG6AiEk7RL7nfqyC2ZMcMSSRhQaJwBWYqPd6ukeL/";

    constructor() ERC721("The Outlier Project", "OUT") {
        m_addrOwner = payable(msg.sender);
        _tokenIds.increment();
    }

    modifier onlyByOwner() {
        require(msg.sender == m_addrOwner, "Unauthorised Access");
        _;
    }

    function mintTokenForUsers(uint256 amount) public payable {
        require(
            _tokenIds.current() + amount <= TOTAL_SPPLY - DEV_SUPPLY,
            "total supply overflowed"
        );
        require(
            msg.value == mintingFeeForEth * amount,
            "ether amount input error"
        );

        m_addrOwner.transfer(msg.value);

        for (uint256 i = 0; i < amount; i++) {
            uint256 newItemId = _tokenIds.current();
            _mint(msg.sender, newItemId);
            _setTokenURI(
                newItemId,
                concateString(
                    BASE_URL,
                    makeStringFormat(newItemId, ".json")
                )
            );
            _tokenIds.increment();
        }
        m_nUserTokenIds += amount;
    }

    function mintTokenForTeam(
        uint256 amount
    ) public onlyByOwner {
        require(
            _tokenIds.current() + amount <= DEV_SUPPLY,
            "dev supply overflowed"
        );
        for (uint256 i = 0; i < amount; i++) {
            uint256 newItemId = _tokenIds.current();
            _mint(m_addrOwner, newItemId);
            _setTokenURI(
                newItemId,
                concateString(
                    BASE_URL,
                    makeStringFormat(newItemId, ".json")
                )
            );
            _tokenIds.increment();
        }
        m_nDevTokenIds += amount;
    }

    function concateString(string memory str1, string memory str2)
        public
        view
        returns (string memory)
    {
        return string(abi.encodePacked(str1, str2));
    }

        function uint2str(uint256 _i)
        internal
        pure
        returns (string memory _uintAsString)
    {
        if (_i == 0) {
            return "0";
        }
        uint256 j = _i;
        uint256 len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint256 k = len;
        while (_i != 0) {
            k = k - 1;
            uint8 temp = (48 + uint8(_i - (_i / 10) * 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            _i /= 10;
        }
        return string(bstr);
    }

    function makeStringFormat(uint256 _id, string memory str)
        public
        view
        returns (string memory)
    {
        uint256 numberTobeconverted = _id;
        string memory temp = uint2str(numberTobeconverted);
        string memory concated = concateString(temp, str);
        return concated;
    }

    function getCurrentTokenId() public view returns (uint256) {
        return _tokenIds.current();
    }

    function getMintingFeeForEth() public view returns (uint256) {
        return mintingFeeForEth;
    }

    function getLeftUserTokenCount() public view returns (uint256) {
        return TOTAL_SPPLY - DEV_SUPPLY - m_nUserTokenIds;
    }

    function getLeftDevTokenCount() public view returns (uint256) {
        return DEV_SUPPLY - m_nDevTokenIds;
    }

    function getOwner() public view returns (address) {
        return m_addrOwner;
    }

    function setOwner(address _address) public onlyByOwner {
        m_addrOwner = payable(_address);
    }
}