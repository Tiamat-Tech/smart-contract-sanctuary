//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import "hardhat/console.sol";
import "erc721a/contracts/ERC721A.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract Dickmen is ERC721A, Ownable {
    uint256 public immutable cap;
    uint256 public immutable percentOfDevs;
    uint256 public immutable percentOfVC;
    uint256 public immutable percentOfWinner;

    uint256[] private winnersIdx;
    address[] private winners;

    constructor(
        uint256 _cap,
        uint256 _percentOfDevs,
        uint256 _percentOfVC,
        uint256 _percentOfWinner
    ) ERC721A("Dickmen Test", "DICKT") {
        cap = _cap;
        percentOfDevs = _percentOfDevs;
        percentOfVC = _percentOfVC;
        percentOfWinner = _percentOfWinner;

        require(
            _percentOfDevs + _percentOfVC + _percentOfWinner == 100,
            "Percentage is not 100%"
        );
    }

    function mintDick(uint256 quantity)
    external
    payable
    distributionTrigger
    {
        require(winnersIdx.length > 0, "Winner index not set yet");
        require(msg.value >= 0.05 ether * quantity, "Not enough ether");
        require(totalSupply() + quantity <= cap, "Reached max supply");

        checkWinnerId(currentIndex, quantity);
        _safeMint(msg.sender, quantity);
    }

    function checkWinnerId(uint256 currentIndex, uint256 quantity)
    private
    {
        for (uint256 i = currentIndex; i <= quantity; i++) {
            for (uint256 j; j < winnersIdx.length; j++) {
                if (i == winnersIdx[j]) {
                    winners.push(msg.sender);
                }
            }
        }
    }

    /*function checkMintedAll()
    private
    {
        if (totalSupply() == cap) {
            distributionTrigger();
        }
    }*/

    modifier distributionTrigger()
    {
        require(totalSupply() == cap, "");

        address devAddress = owner();
        //address VCAddress = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;

        uint256 contractAmount = address(this).balance;
        uint256 devAmount = contractAmount * percentOfDevs / 100;
        //uint256 VCAmount = contractAmount * percentOfVC / 100;
        uint256 winnersAmount = contractAmount * percentOfWinner / 100;
        uint256 winnerAmount = winnersAmount / winnersIdx.length;

        devAddress.call{value: devAmount}("");
        //VCAddress.call{value: VCAmount}("");

        for (uint256 i = 0; i < winners.length; i++) {
            winners[i].call{value: winnerAmount}("");
        }
        _;
    }

    function setWinnersIdx(uint256[] memory _winnersIdx)
    public
    onlyOwner
    {
        winnersIdx = _winnersIdx;
    }

    function showWinnersIdx() external view returns (uint256[] memory) {
        return winnersIdx;
    }

    function showWinners() external view returns (address[] memory) {
        return winners;
    }

    function devMintAll()
    external
    onlyOwner
    {
        uint256 leftQuantity = cap - totalSupply();
        require(totalSupply() + leftQuantity == cap, "Left Quantity is not collect");
        _safeMint(msg.sender, leftQuantity);
    }

    function withdrawAllFund()
    external
    onlyOwner
    {
        address devAddress = owner();
        devAddress.call{value: address(this).balance}("");
    }

    function contractBalance()
    external
    view
    returns (uint256)
    {
        return address(this).balance;
    }

    string private _baseTokenURI;

    function _baseURI()
    internal
    view
    virtual
    override
    returns (string memory)
    {
        return _baseTokenURI;
    }

    function setBaseURI(string calldata baseURI)
    external
    onlyOwner
    {
        _baseTokenURI = baseURI;
    }
}