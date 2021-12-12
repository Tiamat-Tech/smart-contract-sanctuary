pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract Shibuya is Ownable, ERC1155Holder, Pausable {
    using Strings for uint256;
    using EnumerableSet for EnumerableSet.UintSet;
    IERC1155 public whiteRabbitProducerPass;
    uint256[] private _microEpisodes;

    event ProducerPassStaked(address indexed account, uint256 episodeID, uint256 voteID, uint256 amount);

    mapping(uint256 => uint256[]) private _microEpisodeOptions;
    EnumerableSet.UintSet private microEpisodesSet;
    EnumerableSet.UintSet private microEpisodeOptionsSet;

    // Voting
    mapping(uint256 => mapping(uint256 => uint256)) private microEpisodeVotesByOptionId;
    mapping(address => mapping(uint256 => mapping(uint256 => uint256))) private userVotes;
    bool public votingEnabled;

    // metadata baseURIs
    string private _microEpisodeBaseURI;
    string private _microEpisodeOptionBaseURI;

    constructor(address whiteRabbitProducerPassContract) {
        whiteRabbitProducerPass = IERC1155(whiteRabbitProducerPassContract);
    }

    // admin
    function setMicroEpisodeBaseURI(string memory baseURI) external onlyOwner() {
        _microEpisodeBaseURI = baseURI;
    }

    function setMicroEpisodeOptionBaseURI(string memory baseURI) external onlyOwner() {
        _microEpisodeOptionBaseURI = baseURI;
    }

    function addNewMicroEpisode(uint256 microEpisodeId, uint256[] calldata microEpisodeOptionIds) external onlyOwner {
        require(!microEpisodesSet.contains(microEpisodeId), "microepisode already added");

        _microEpisodes.push(microEpisodeId);
        microEpisodesSet.add(microEpisodeId);
        _microEpisodeOptions[microEpisodeId] = microEpisodeOptionIds;
        for (uint256 i; i < microEpisodeOptionIds.length; i++) {
            microEpisodeOptionsSet.add(microEpisodeOptionIds[i]);
        }
    }

    function getMicroEpisodes() public view returns (uint256[] memory) {
        return _microEpisodes;
    }

    function getMicroEpisodeOptions(uint256 microEpisodeId) public view returns (uint256[] memory) {
        return _microEpisodeOptions[microEpisodeId];
    }

    // public - get metadata URIs
    function microEpisodeURI(uint256 microEpisodeId) public view virtual returns (string memory) {
        require(microEpisodesSet.contains(microEpisodeId), "microepisode does not exist");

        string memory baseURI = microEpisodeBaseURI();
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, microEpisodeId.toString())) : "";
    }

    function microEpisodeOptionURI(uint256 microEpisodeOptionId) public view virtual returns (string memory) {
        require(microEpisodeOptionsSet.contains(microEpisodeOptionId), "microepisode option does not exist");

        string memory baseURI = microEpisodeOptionBaseURI();
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(_microEpisodeOptionBaseURI, microEpisodeOptionId.toString())) : "";
    }

    function microEpisodeBaseURI() internal view virtual returns (string memory) {
        return _microEpisodeBaseURI;
    }

    function microEpisodeOptionBaseURI() internal view virtual returns (string memory) {
        return _microEpisodeOptionBaseURI;
    }

    // public - get votes
    function microEpisodeVotes(uint256 microEpisodeId, uint256 microEpisodeOptionId) public view virtual returns (uint256) {
        require(microEpisodesSet.contains(microEpisodeId), "microepisode does not exist");
        require(microEpisodeOptionsSet.contains(microEpisodeOptionId), "microepisode option does not exist");

        return microEpisodeVotesByOptionId[microEpisodeId][microEpisodeOptionId];
    }

    function userMicroEpisodeVotes(uint256 microEpisodeId, uint256 microEpisodeOptionId) public view virtual returns (uint256) {
        require(microEpisodesSet.contains(microEpisodeId), "microepisode does not exist");
        require(microEpisodeOptionsSet.contains(microEpisodeOptionId), "microepisode option does not exist");

        return userVotes[msg.sender][microEpisodeId][microEpisodeOptionId];
    }

    // public - staking
    function stakeProducerPass(uint256 episodeId, uint256 voteOptionId, uint256 amount) public {
        require(votingEnabled == true, "Voting not enabled");
        require(amount > 0, "cannot stake 0");
        require(whiteRabbitProducerPass.balanceOf(msg.sender, episodeId) >= amount, "staking more than you got bro");
        uint256[] memory votingOptionsForThisEpisode = _microEpisodeOptions[episodeId];
        require(votingOptionsForThisEpisode[votingOptionsForThisEpisode.length - 1] >= voteOptionId, "Submitted vote option not one of the valid options for this episode");

        uint256 userCurrentVoteCount = userVotes[msg.sender][episodeId][voteOptionId];
        userVotes[msg.sender][episodeId][voteOptionId] = userCurrentVoteCount + amount;

        microEpisodeVotesByOptionId[episodeId][voteOptionId] = microEpisodeVotesByOptionId[episodeId][voteOptionId] + amount;
        whiteRabbitProducerPass.safeTransferFrom(msg.sender, address(this), episodeId, amount, "");
        emit ProducerPassStaked(msg.sender, episodeId, voteOptionId, amount);
    }

    // admin - voting
    function setVotingEnabled(bool enabled) internal {
        require(votingEnabled != enabled, "state is the same, no need to update");
        votingEnabled = enabled;
    }
}