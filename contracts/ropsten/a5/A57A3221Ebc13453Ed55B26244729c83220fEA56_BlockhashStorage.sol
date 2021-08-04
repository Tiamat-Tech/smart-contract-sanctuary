import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

contract BlockhashStorage is ERC20 {

    mapping (uint256=>bytes32) public blocknumberToHash;
    
    constructor() ERC20("BlockHash", "BHS") {}

    // STORE / MUTATIVE FUNCTIONS

    function store() public {
        uint256 currentBlock = block.number;
        if (blocknumberToHash[currentBlock-1] == 0
            && blockhash(currentBlock-1) != 0) {
                blocknumberToHash[currentBlock-1] = blockhash(currentBlock-1);
                _mint(_msgSender(), 1e18);
        }
    }

    function store(uint256 blocknumber) public {
        if (blocknumberToHash[blocknumber] == 0
            && blockhash(blocknumber) != 0) {
                blocknumberToHash[blocknumber] = blockhash(blocknumber);
                _mint(_msgSender(), 1e18);
        }
    }


    function store(uint256[] calldata blocknumbers) public {
        uint256 reward;
        for (uint256 i = 0; i<blocknumbers.length; i++) {
            if (blocknumberToHash[blocknumbers[i]] == 0
                && blockhash(blocknumbers[i]) != 0) {
                    blocknumberToHash[blocknumbers[i]] = blockhash(blocknumbers[i]);
                    reward++;            
            }
        }
        _mint(_msgSender(), reward * 1e18);
    }
    
    function store(uint256 blocknumberFrom, uint256 blocknumberTo) public {
        uint256 reward;
        for (uint256 blocknumber = blocknumberFrom; blocknumber<=blocknumberTo; blocknumber++) {
            if (blocknumberToHash[blocknumber] == 0
                && blockhash(blocknumber) != 0) {
                    blocknumberToHash[blocknumber] = blockhash(blocknumber);
                    reward++;            
            }
        }
        _mint(_msgSender(), reward * 1e18);
    }
    
    // Stores blockhashes of the latest 256 blocks (skipping the ones that are already there)
    function store256() public {
        uint256 reward;
        uint256 currentBlock = block.number;
        for (uint256 blocknumber = currentBlock - 1; blocknumber >= currentBlock - 256; blocknumber--) {
            if (blocknumberToHash[blocknumber] == 0
                && blockhash(blocknumber) != 0) {
                    blocknumberToHash[blocknumber] = blockhash(blocknumber);
                    reward++;
            }
        }
        _mint(_msgSender(), reward * 1e18);
    }
    
    // RETRIEVE / VIEW FUNCTIONS

    function retrieve() public view returns (bytes32) {
        return blocknumberToHash[block.number - 1];
    }

    function retrieve(uint256 blocknumber) public view returns (bytes32) {
        return blocknumberToHash[blocknumber];
    }
    
    function retrieve(uint256[] calldata blocknumbers) public view returns(bytes32[] memory) {
        bytes32[] memory blockhashes = new bytes32[](blocknumbers.length);
        for (uint256 i = 0; i < blocknumbers.length; i++) {
            blockhashes[i] = blocknumberToHash[blocknumbers[i]];
        }
        return blockhashes;
    }

    function retrieve(uint256 blocknumberFrom, uint256 blocknumberTo) public view returns(bytes32[] memory) {
        bytes32[] memory blockhashes = new bytes32[](blocknumberTo-blocknumberFrom + 1);
        for (uint256 i = 0; i <= blocknumberTo - blocknumberFrom; i++) {
            blockhashes[i] = blocknumberToHash[blocknumberFrom + i];
        }
        return blockhashes;
    }
    
    // Returns 256 latest blockhashes with [0] being the current block and going to the past
    function retrieve256() public view returns(bytes32[] memory) {
        bytes32[] memory blockhashes = new bytes32[](256);
        for (uint256 i=0; i<256; i++) {
            blockhashes[i] = blocknumberToHash[block.number - i];
        }
        return blockhashes;
    }

}