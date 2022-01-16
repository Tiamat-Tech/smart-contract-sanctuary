// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

/**
TODO: prevent re-entrancy
*/
contract WIP is ERC721, ERC721URIStorage, Pausable, Ownable, ERC721Burnable {

    using Counters for Counters.Counter;

    address payable private _owner;
    Counters.Counter public numGenomes;
    Counters.Counter public numTokens;

    struct Genome {
        uint256 totalSize;
        uint256 costToMint;
        address originator;
        string originatorName;
        string originatorAbout;
        address payable sequencingBot;
    }

    struct SNaP {
        uint256 genomeId;
        bool revealed;
        string rsid;
        string chromosome;
        string position;
        string genotype;
    }

    /**
    TODO: MORE EVENTS 
    */
    event WithdrawEth(
        uint256 indexed amount,
        address indexed receiver
    );
    event SNaPMinted(
        uint256 indexed genomeId,
        uint256 indexed tokenId,
        address indexed minter
    );
    event SNaPSequenced(
        uint256 indexed tokenId
    );

    mapping(uint256 => Genome) public genomes;
    mapping(uint256 => SNaP) public snaps;

    constructor() ERC721("WIP", "WIP") {
        _owner = payable(msg.sender);
    }

    function setCostToMint(uint256 _genomeId, uint256 _costToMint)
        public 
        onlyOwner {
            _validateGenome(_genomeId);
            genomes[_genomeId].costToMint = _costToMint;
    }

    function addGenome(
        uint256 _totalSize, 
        uint256 _costToMint,
        address _originator,
        string memory _originatorName,
        string memory _originatorAbout,
        address payable _sequencingBot)
        public 
        onlyOwner {
            numGenomes.increment();
            genomes[numGenomes.current()] = Genome({
                totalSize: _totalSize,
                costToMint: _costToMint,
                originator: _originator,
                originatorName: _originatorName,
                originatorAbout: _originatorAbout,
                sequencingBot: _sequencingBot
            });
    }

    function mintSNaP(
        uint256 _genomeId)
        public
        payable
        {
        _validateGenome(_genomeId);
        require(genomes[_genomeId].costToMint == msg.value, "Exact minting cost must be included.");

        //mint SNaP token and store mapping of SNaP object
        numTokens.increment();
        snaps[numTokens.current()] = SNaP({
            genomeId: _genomeId,
            revealed: false,
            rsid: "", 
            chromosome: "", 
            position: "", 
            genotype: ""
        });

        //send funds to sequencing bot
        genomes[_genomeId].sequencingBot.transfer(msg.value);

        //mint token
        _safeMint(msg.sender, numTokens.current());

        emit SNaPMinted(_genomeId, numTokens.current(), msg.sender);
    }

    function sequenceSNaP(
        uint256 _tokenId,
        uint256 _genomeId,
        string memory _rsid, 
        string memory _chromosome, 
        string memory _position, 
        string memory _genotype) 
        public {
        _validateGenome(_genomeId);
        require(snaps[_tokenId].genomeId == _genomeId, "Incorrect genome for token");
        require(msg.sender == genomes[_genomeId].sequencingBot, "Not authorized for SNaP");

        snaps[_tokenId] = SNaP({
            genomeId: _genomeId,
            revealed: true,
            rsid: _rsid, 
            chromosome: _chromosome, 
            position: _position, 
            genotype: _genotype
        });

        emit SNaPSequenced(_tokenId);
    }

    function _validateGenome(
        uint256 _genomeId)
        private 
        view {
        if (_genomeId <= 0 || _genomeId < numGenomes.current()) {
            revert("Genome id out of range");
        }
    }

    function _baseURI() 
        internal 
        pure 
        override returns (string memory) {
        return "https://test.com/api/base-route/";
    }

    function pause() 
        public 
        onlyOwner {
        _pause();
    }

    function unpause() 
        public 
        onlyOwner {
        _unpause();
    }

    function _beforeTokenTransfer(
        address from, 
        address to, 
        uint256 tokenId)
        internal
        whenNotPaused
        override {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function withdrawEth(
        uint256 amount, 
        address payable receiver) 
        external 
        onlyOwner {
        receiver.transfer(amount);
        emit WithdrawEth(amount, receiver);
    }

    // The following functions are overrides required by Solidity.

    function _burn(
        uint256 tokenId) 
        internal 
        override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
        {
        require(_exists(tokenId),"URI query for nonexistent token");
        /**
        TODO: formaulate metadata from SNaP mappings
        - consider pre-reveal and post-reveal state
        */
        return string(abi.encodePacked(_baseURI(), Strings.toString(tokenId)));
    }
}