// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract DNA is Ownable {

    using Counters for Counters.Counter;

    address autobot;
    Counters.Counter public numGenomes;
    Counters.Counter public numSnaps;

    struct Genome {
        uint256 totalSize;
        Counters.Counter snapsAdded;
        address autobot;
    }

    struct SNaP {
        uint256 genomeId;
        string rsid;
        string chromosome;
        string position;
        string genotype;
    }

    /**
    TODO: MORE EVENTS 
    */
    event GenomeAdded(
        uint256 indexed genomeId
    );
    event GenomeAutobotAssigned(
        uint256 indexed genomeId,
        address indexed autobot
    );
    event SNaPAdded(
        uint256 indexed tokenId,
        uint256 indexed genomeId
    );
    event AutobotAssigned(
        address indexed autobot
    );

    mapping(uint256 => Genome) public genomes;
    mapping(uint256 => SNaP) public snaps;

    constructor() {
        autobot = msg.sender;
    }

    function addGenome(
        uint256 _totalSize,
        address _autobot)
        public {
            require(_autobot != address(0), "Invalid autobot address");
            require(msg.sender == owner() || msg.sender == autobot, "Only owner or primary autobot can add genomes");
            
            numGenomes.increment();
            Counters.Counter memory _snapsAdded;
            genomes[numGenomes.current()] = Genome({
                totalSize: _totalSize,
                snapsAdded: _snapsAdded,
                autobot: _autobot
            });
            
            emit GenomeAdded(numGenomes.current());
    }

    function assignGenomeAutobot(
        uint256 _genomeId,
        address _autobot)
        public {
            _validateGenome(_genomeId);
            require(_autobot != address(0), "Valid bot address required");
            require(msg.sender == owner() || msg.sender == genomes[_genomeId].autobot, "Only primary or genome-assigned bot may assign");
            
            genomes[_genomeId].autobot = _autobot;

            emit GenomeAutobotAssigned(_genomeId, _autobot);
    }

    function assignPrimaryAutobot(
        address _autobot)
        public {
            require(_autobot != address(0), "Valid bot address required");
            require(msg.sender == owner(), "Only owner can assign primary autobot");
            
            autobot = _autobot;

            emit AutobotAssigned(_autobot);
    }

    function addSNaPs(
        uint256 _genomeId,
        string[] memory _rsids,
        string[] memory _chromosomes,
        string[] memory _positions,
        string[] memory _genotypes)
        public
        onlyOwner
        {
        _validateGenome(_genomeId);
        require(_rsids.length ==_chromosomes.length && _rsids.length == _positions.length && _rsids.length == _genotypes.length, "Data length mismatch");
        require(genomes[_genomeId].snapsAdded.current() + _rsids.length <= genomes[_genomeId].totalSize, "Too many snaps");

        for (uint256 i = 0; i < _rsids.length; i++) {
            numSnaps.increment();
            genomes[_genomeId].snapsAdded.increment();
            snaps[numSnaps.current()] = SNaP({
                genomeId: _genomeId,
                rsid: _rsids[i], 
                chromosome: _chromosomes[i], 
                position: _positions[i], 
                genotype: _genotypes[i]
            });

            emit SNaPAdded(numSnaps.current(), _genomeId);
        }
    }

    /*
    Conditions for validating a provided genome id.
    */
    function _validateGenome(
        uint256 _genomeId)
        private 
        view {
        if (_genomeId <= 0 || _genomeId < numGenomes.current()) {
            revert("Genome id out of range");
        }
    }
}