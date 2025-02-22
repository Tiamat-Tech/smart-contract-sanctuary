import "./StonesUtils.sol";

pragma solidity ^0.6.12;

contract Stones is ERC721, Ownable {

    // lock trading (incl. OTC) during distribution phase (1 month)
    uint transfersUnlockedAt = block.timestamp + 2629746;

    function claimedInfo() public view returns (uint[] memory) {
        return claimed;
    }

    constructor() public ERC721("Stones", "STONES") {
        _setBaseURI("https://nft.deworld.org/describe/");
    }

    uint public curveX = 100;
    uint[] public claimed;
    mapping(uint => bool) public isClaimed;

    function claimStone(uint _Id) public payable returns (uint256)
    {
        require(_Id < 1420, "wrong id");
        require(isClaimed[_Id] == false, "claimed");

        // LINK Stone (Chainlink capabilities)
        if (_Id >= 0 && _Id < 50) {
            require(msg.value == 5 ether *curveX/100);
        }

        // UNI Stone (Uniswap capabilities)
        if (_Id >= 50 && _Id < 200) {
            require(msg.value == 1 ether *curveX/100);
        }

        // COMP Stone (Compound capabilities)
        if (_Id >= 200 && _Id < 270) {
            require(msg.value == 3 ether *curveX/100);
        }

        // AAVE Stone (AAVE capabilities)
        if (_Id >= 270 && _Id < 340) {
            require(msg.value == 3 ether *curveX/100);
        }

        // DAI Stone (Maker SAI/DAI capabilities)
        if (_Id >= 340 && _Id < 440) {
            require(msg.value == 1 ether *curveX/100);
        }

        // YFI Stone (Yearn capabilities)
        if (_Id >= 440 && _Id < 540) {
            require(msg.value == 2 ether *curveX/100);
        }

        // PROMINT Stone (DeFi Mint capabilities)
        if (_Id >= 540 && _Id < 620) {
            require(msg.value == 6 ether *curveX/100);
        }

        // HUT (full access to DeWorld)
        if (_Id >= 620 && _Id < 1420) {
            //0.2 eth
            require(msg.value == 2e17*curveX/100);
        }

        _mint(msg.sender, _Id);
        claimed.push(_Id);
        isClaimed[_Id] = true;
        //bump NFT up BC price up 3%;
        curveX = curveX + 3;
        return _Id;
    }

    function claimETH() public payable onlyOwner {
        msg.sender.transfer(address(this).balance);
    }

    function _beforeTokenTransfer(address _from, address _to, uint256 _tokenId) internal override {
        require(transfersUnlockedAt > block.timestamp || _from == address(0), "distribution");
    }
}