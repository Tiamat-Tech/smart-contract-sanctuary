pragma solidity ^0.5.0;
pragma experimental ABIEncoderV2;

import { WeddingInvitationToken, WeddingWitnessToken } from "./Tokens.sol";


contract GuestBook {
    event GuestbookSignatureAdded(uint timestamp, address wallet, string name, string message);
    event GuestInvited(uint timestamp, address wallet, address from);

    address payable public spouse1Address;
    address payable public spouse2Address;
    address public owner;

    address[] invitationList;
    mapping (address => bool) private isInvited;

    WeddingInvitationToken invitationToken = new WeddingInvitationToken();
    WeddingWitnessToken witnessToken = new WeddingWitnessToken();

    struct GuestBookEntry {
        address sender;
        string name;
        string message;
    }
    GuestBookEntry[] guestBook;

    /**
     * @dev Constructor: Set the wallet addresses of both spouses.
     * @param _spouse1Address Wallet address of spouse1.
     * @param _spouse2Address Wallet address of spouse2.
     */
    constructor(address payable _spouse1Address, address payable _spouse2Address) public {
        require(_spouse1Address != address(0), "Spouse1 address must not be zero!");
        require(_spouse2Address != address(0), "Spouse2 address must not be zero!");
        require(_spouse1Address != _spouse2Address, "Spouse1 address must not equal Spouse2 address!");

        spouse1Address = _spouse1Address;
        isInvited[spouse1Address] = true;
        invitationList.push(spouse1Address);

        spouse2Address = _spouse2Address;
        isInvited[spouse2Address] = true;
        invitationList.push(spouse2Address);
    }

    /**
     * @dev Modifier that only allows contract owner execution.
      */
    modifier onlyOwner() {
        require(msg.sender == owner, "Sender is not contract owner!");
        _;
    }

    /**
     * @dev Modifier that only allows spouse execution.
      */
    modifier onlySpouse() {
        require(msg.sender == spouse1Address || msg.sender == spouse2Address, "Sender is not a spouse!");
        _;
    }

    /**
     * @dev Modifier that only allows invited member execution.
      */
    modifier onlyInvited() {
        require(isInvited[msg.sender], "Sender is not invited!");
        _;
    }

    /**
     * @dev Set contract owner
     */
    function setContractOwner(address _owner) public {
        require(owner == address(0), "Owner already set");
        owner = _owner;
    }

    /**
     * @dev Invite someone to your wedding
     */
    function sendInvitation(address payable _to) public onlySpouse {
        require(!isInvited[_to], "Person has already been invited!");
        if (invitationToken.balanceOf(address(this)) > 0) {
            invitationToken.transfer(_to, 1);
            isInvited[_to] = true;
            invitationList.push(_to);
            emit GuestInvited(now, _to, msg.sender);
        }
    }

    /**
     * @dev Sign the guest book
     */
    function signGuestBook(string memory name, string memory message) public onlyInvited {
        GuestBookEntry memory entry = GuestBookEntry({
            sender: msg.sender,
            name: name,
            message: message
        });
        guestBook.push(entry);
        emit GuestbookSignatureAdded(now, msg.sender, name, message);
    }

    /**
     * @dev Get guest book entries
     */
    function getGuestBookEntries() public view returns (GuestBookEntry[] memory) {
        return guestBook;
    }

    /**
     * @dev Send witness tokens
     */
    function sendWitnessTokens() public onlyOwner {
        for (uint i = 0; i < invitationList.length; i++) {
            if (witnessToken.balanceOf(address(this)) > 0) {
                witnessToken.transfer(invitationList[i], 1);
            }
        }
    }

    /**
     * @dev Get address to WitnessToken
     */
    function getWitnessTokenAddress() public view returns (address) {
        return address(witnessToken);
    }

    /**
     * @dev Get address to InvitationToken
     */
    function getInvitationTokenAddress() public view returns (address) {
        return address(invitationToken);
    }

}