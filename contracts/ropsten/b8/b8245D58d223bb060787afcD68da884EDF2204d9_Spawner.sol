// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.7.6;
pragma abicoder v2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./CryptoZooNFT.sol";

contract Spawner is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    event Spawn(
        address indexed buyer,
        uint256 amount,
        CryptoZooNFT.Tribe _tribe
    );
    event Evolve(uint256 indexed tokenId, address owner, uint256 dna);

    ManagerInterface public manager;
    CryptoZooNFT public zoonerNFT;
    IERC20 public zoonerERC20;

    constructor(
        address _manager,
        address _zoonerERC20,
        address _zoonerNFT
    ) {
        manager = ManagerInterface(_manager);
        zoonerERC20 = IERC20(_zoonerERC20);
        zoonerNFT = CryptoZooNFT(_zoonerNFT);
    }

    function setManager(address _config) public onlyOwner {
        manager = ManagerInterface(_config);
    }

    function setNFT(address _zoonerNFT) public onlyOwner {
        zoonerNFT = CryptoZooNFT(_zoonerNFT);
    }

    function setERC20(address _zoonerERC20) public onlyOwner {
        zoonerERC20 = IERC20(_zoonerERC20);
    }

    function lay(uint256 _amount, CryptoZooNFT.Tribe _tribe) external {
        require(_amount > 0, "dont accept 0 amount");
        uint256 totalFee = manager.priceEgg().mul(_amount);
        zoonerERC20.transferFrom(_msgSender(), manager.feeAddress(), totalFee);

        zoonerNFT.layEgg(_amount, _msgSender(), _tribe);

        emit Spawn(_msgSender(), _amount, _tribe);
    }

    function evolveEgg(uint256 _tokenId) public {
        uint256 dna = generateDNA(_tokenId);
        zoonerERC20.transferFrom(
            _msgSender(),
            manager.feeAddress(),
            manager.feeEvolve()
        );
        zoonerNFT.evolve(_tokenId, _msgSender(), dna);

        emit Evolve(_tokenId, _msgSender(), dna);
    }

    function generateDNA(uint256 _tokenId) public view returns (uint256) {
        uint256 dna = random(_tokenId, 30);
        while (dna < 10**26) {
            dna = random(_tokenId, 30);
        }
        return dna;
    }

    function forceEvolve(uint256 _tokenId, uint256 _dna) public onlyOwner {
        zoonerNFT.evolve(_tokenId, zoonerNFT.ownerOf(_tokenId), _dna);
    }

    function random(uint256 _id, uint256 _length)
        private
        view
        returns (uint256)
    {
        return
            uint256(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            block.difficulty,
                            block.timestamp,
                            _id,
                            _length
                        )
                    )
                )
            ) % (10**_length);
    }
}