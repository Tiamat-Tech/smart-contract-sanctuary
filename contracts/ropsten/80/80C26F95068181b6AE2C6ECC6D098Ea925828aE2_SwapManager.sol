// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "./token/interfaces/FakeInterface.sol";
import "./interfaces/IBridgeManager.sol";
import "./interfaces/IPRIVIPodERC20Factory.sol";
import "./interfaces/IPRIVIPodERC721Factory.sol";
import "./interfaces/IPRIVIPodERC1155Factory.sol";
import "./interfaces/IPRIVIPodERC721RoyaltyFactory.sol";
import "./interfaces/IPRIVIPodERC1155RoyaltyFactory.sol";

/**
 * @title   SwapManager contract
 * @dev     Manages swaps and withdraws of Ether, ERC20 tokens, ERC721 tokens
 * and ERC1155 tokens between Ethereum and PRIVI blockchains
 * @author  PRIVI
 **/
contract SwapManager is AccessControl, ERC1155Holder {
  bytes32 public constant TRANSFER_ROLE = keccak256("TRANSFER_ROLE");
  address private ZERO_ADDRESS = 0x0000000000000000000000000000000000000000;
  address public bridgeManagerAddress;
  address public erc20FactoryAddress;
  address public erc721FactoryAddress;
  address public erc1155FactoryAddress;
  address public erc721RoyaltyFactoryAddress;
  address public erc1155RoyaltyFactoryAddress;

  event DepositERC20Token(
    string indexed tokenSymbol,
    address from,
    uint256 amount
  );
  event WithdrawERC20Token(
    string indexed tokenSymbol,
    address to,
    uint256 amount
  );
  event DepositERC721Token(
    string indexed tokenSymbol,
    address from,
    uint256 tokenId
  );
  event WithdrawERC721Token(
    string indexed tokenSymbol,
    address to,
    uint256 tokenId
  );
  event DepositERC1155Token(
    string indexed tokenURI,
    address from,
    uint256 tokenId,
    uint256 amount
  );
  event WithdrawERC1155Token(
    string indexed tokenURI,
    address to,
    uint256 tokenId,
    uint256 amount
  );
  event BatchWithdrawERC1155Token(
    string indexed tokenURI,
    address to,
    uint256[] tokenIds,
    uint256[] amounts
  );
  event DepositEther(address indexed from, uint256 amount);
  event WithdrawEther(address indexed to, uint256 amount);

  /**
   * @notice Constructor to assign all roles to contract creator
   */
  constructor(
    address bridgeDeployedAddress,
    address erc20FactoryDeployedAddress,
    address erc721FactoryDeployedAddress,
    address erc1155FactoryDeployedAddress,
    address erc721FactoryRoyaltyDeployedAddress,
    address erc1155FactoryRoyaltyDeployedAddress
  ) {
    _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
    // _setupRole(REGISTER_ROLE, _msgSender());
    _setupRole(TRANSFER_ROLE, _msgSender());
    bridgeManagerAddress = bridgeDeployedAddress;
    erc20FactoryAddress = erc20FactoryDeployedAddress;
    erc721FactoryAddress = erc721FactoryDeployedAddress;
    erc1155FactoryAddress = erc1155FactoryDeployedAddress;
    erc721RoyaltyFactoryAddress = erc721FactoryRoyaltyDeployedAddress;
    erc1155RoyaltyFactoryAddress = erc1155FactoryRoyaltyDeployedAddress;
  }

  // To be able to receive ERC1155 tokens (required if inheriting from AccessControl, ERC1155Holder)
  function supportsInterface(bytes4 interfaceId)
    public
    view
    virtual
    override(ERC1155Receiver, AccessControl)
    returns (bool)
  {
    return super.supportsInterface(interfaceId);
  }

  /**
   * @notice  Transfer ERC20 token from sender address (User) to contract address (PRIVI)
   * @dev     - Token to be transferred must be already registered
   *          - User has to approve first the amount to be transferred WITHIN the original ERC20 token contract,
   *          and not from this contract. Otherwise, transaction will always fail
   * @param   tokenSymbol Name of the token to be transferred
   * @param   amount Amount of tokens to be transferred
   */
  function depositERC20Token(string calldata tokenSymbol, uint256 amount)
    external
  {
    IBridgeManager bManager = IBridgeManager(bridgeManagerAddress);
    address tokenAddress = bManager.getErc20AddressRegistered(tokenSymbol);
    require(
      tokenAddress != ZERO_ADDRESS,
      "SwapManager: token is not registered into the platform"
    );
    require(
      IERC20(tokenAddress).allowance(_msgSender(), address(this)) >= amount,
      "SwapManager: token amount to be transferred to PRIVI is not yet approved by User"
    );
    IERC20(tokenAddress).transferFrom(_msgSender(), address(this), amount);
    emit DepositERC20Token(tokenSymbol, _msgSender(), amount);
  }

  /**
   * @notice  Transfer ERC20 token from contract address (PRIVI) to sender address (User)
   * @dev     - User must have TRANSFER_ROLE
   *          - PRIVI must have enough tokens to transfer them back to User
   * @param   tokenSymbol Name of the token to be transferred
   * @param   to Destination address to receive the tokens
   * @param   amount Amount of tokens to be transferred
   */
  function withdrawERC20Token(
    string calldata tokenSymbol,
    address to,
    uint256 amount
  ) external {
    require(amount > 0, "SwapManager: amount must be greater than 0");
    IBridgeManager bManager = IBridgeManager(bridgeManagerAddress);
    address tokenAddress = bManager.getErc20AddressRegistered(tokenSymbol);
    require(
      hasRole(TRANSFER_ROLE, _msgSender()),
      "SwapManager: must have TRANSFER_ROLE to withdraw token"
    );
    if (amount <= IERC20(tokenAddress).balanceOf(address(this))) {
      IERC20(tokenAddress).approve(address(this), amount);
      IERC20(tokenAddress).transferFrom(address(this), to, amount);
      emit WithdrawERC20Token(tokenSymbol, to, amount);
    } else if (
      IPRIVIPodERC20Factory(erc20FactoryAddress).getPodAddressBySymbol(
        tokenSymbol
      ) != ZERO_ADDRESS
    ) {
      IPRIVIPodERC20Factory(erc20FactoryAddress).mintPodTokenBySymbol(
        tokenSymbol,
        to,
        amount
      );
      emit WithdrawERC20Token(tokenSymbol, to, amount);
    } else {
      revert("SwapManager: cannot withdraw any amount");
      // only for testnet mint fake tokens
      // FakeInterface(tokenAddress).mintForUser(to, amount);
      // emit WithdrawERC20Token(tokenSymbol, to, amount);
    }
  }

  /**
   * @notice  Transfer ERC721 token from sender address (User) to contract address (PRIVI)
   * @dev     - User must have TRANSFER_ROLE
   *          - Token to be transferred must be already registered
   *          - User has to approve first the amount to be transferred WITHIN the original ERC721 token contract,
   *          and not from this contract. Otherwise, transaction will always fail
   * @param   tokenSymbol Name of the token to be transferred
   * @param   tokenId Token identifier to be transferred
   */
  function depositERC721Token(string calldata tokenSymbol, uint256 tokenId)
    external
  {
    IBridgeManager bManager = IBridgeManager(bridgeManagerAddress);
    address tokenAddress = bManager.getErc721AddressRegistered(tokenSymbol);
    require(
      tokenAddress != ZERO_ADDRESS,
      "SwapManager: token is not registered into the platform"
    );
    require(
      IERC721(tokenAddress).getApproved(tokenId) == address(this),
      "SwapManager: token to be transferred to PRIVI is not yet approved by User"
    );
    IERC721(tokenAddress).transferFrom(_msgSender(), address(this), tokenId);
    emit DepositERC721Token(tokenSymbol, _msgSender(), tokenId);
  }

  /**
   * @notice  Transfer ERC721 token from contract address (PRIVI) to sender address (User)
   * @dev     - User must have TRANSFER_ROLE
   *          - PRIVI must have enough tokens to transfer them back to User
   * @param   tokenSymbol Name of the token to be transferred
   * @param   to Destination address to receive the tokens
   * @param   tokenId Token identifier to be transferred
   * @param   isPodMint is it a withdraw from swap manager or is it minting new nft pod token
   */
  function withdrawERC721Token(
    string calldata tokenSymbol,
    address to,
    uint256 tokenId,
    bool isPodMint,
    bool isRoyalty
  ) external {
    IBridgeManager bManager = IBridgeManager(bridgeManagerAddress);
    address tokenAddress = bManager.getErc721AddressRegistered(tokenSymbol);
    require(
      hasRole(TRANSFER_ROLE, _msgSender()),
      "SwapManager: must have TRANSFER_ROLE to withdraw token"
    );
    if (isPodMint == true) {
      if (isRoyalty == true) {
        if (
          IPRIVIPodERC721RoyaltyFactory(erc721RoyaltyFactoryAddress)
            .getPodAddressBySymbol(tokenSymbol) != ZERO_ADDRESS
        ) {
          IPRIVIPodERC721RoyaltyFactory(erc721RoyaltyFactoryAddress)
            .mintPodTokenBySymbol(tokenSymbol, tokenId, to);
          emit WithdrawERC721Token(tokenSymbol, to, tokenId);
        } else {
          revert("SwapManager: cannot withdraw royalty token");
        }
      } else {
        if (
          IPRIVIPodERC721Factory(erc721FactoryAddress).getPodAddressBySymbol(
            tokenSymbol
          ) != ZERO_ADDRESS
        ) {
          IPRIVIPodERC721Factory(erc721FactoryAddress).mintPodTokenBySymbol(
            tokenSymbol,
            tokenId,
            to
          );
          emit WithdrawERC721Token(tokenSymbol, to, tokenId);
        } else {
          revert("SwapManager: cannot withdraw non royalty token");
        }
      }
    } else {
      if (IERC721(tokenAddress).ownerOf(tokenId) == address(this)) {
        IERC721(tokenAddress).transferFrom(address(this), to, tokenId);
        emit WithdrawERC721Token(tokenSymbol, to, tokenId);
      } else {
        revert("SwapManager: cannot withdraw non standard token");
      }
    }
  }

  /**
   * @notice  Transfer ERC1155 token from sender address (User) to contract address (PRIVI)
   * @dev     - User must have TRANSFER_ROLE
   *          - Token to be transferred must be already registered
   *          - User has to approve first the amount to be transferred WITHIN the original ERC1155 token contract,
   *          and not from this contract. Otherwise, transaction will always fail
   * @param   tokenURI Name of the token to be transferred
   * @param   tokenId Token identifier to be transferred
   */
  function depositERC1155Token(
    string calldata tokenURI,
    uint256 tokenId,
    uint256 amount,
    bytes memory data
  ) external {
    IBridgeManager bManager = IBridgeManager(bridgeManagerAddress);
    address tokenAddress = bManager.getErc1155AddressRegistered(tokenURI);
    require(
      tokenAddress != ZERO_ADDRESS,
      "SwapManager: token is not registered on BridgeManager"
    );
    require(
      IERC1155(tokenAddress).isApprovedForAll(msg.sender, address(this)) ==
        true,
      "SwapManager: user did not grant aprove yet"
    );
    IERC1155(tokenAddress).safeTransferFrom(
      _msgSender(),
      address(this),
      tokenId,
      amount,
      data
    );
    emit DepositERC1155Token(tokenURI, _msgSender(), tokenId, amount);
  }

  /**
   * @notice  Transfer ERC1155 token from contract address (PRIVI) to address (User)
   * @dev     - PRIVI must have enough tokens to transfer them to User
   *          or is has to be isPodMint.
   * @param   tokenURI Name of the token to be transferred
   * @param   to Destination address to receive the tokens
   * @param   tokenId Token identifier to be transferred
   * @param   amount Token amount to be transfered
   * @param   data bytes
   */
  function withdrawERC1155Token(
    string calldata tokenURI,
    address to,
    uint256 tokenId,
    uint256 amount,
    bytes memory data,
    bool isPodMint,
    bool isRoyalty
  ) external {
    IBridgeManager bManager = IBridgeManager(bridgeManagerAddress);
    address tokenAddress = bManager.getErc1155AddressRegistered(tokenURI);
    require(
      hasRole(TRANSFER_ROLE, _msgSender()),
      "SwapManager: must have TRANSFER_ROLE to withdraw token"
    );
    if (isPodMint == true) {
      if (isRoyalty) {
        if (
          IPRIVIPodERC1155RoyaltyFactory(erc1155RoyaltyFactoryAddress)
            .getPodAddressByUri(tokenURI) != ZERO_ADDRESS
        ) {
          IPRIVIPodERC1155RoyaltyFactory(erc1155RoyaltyFactoryAddress).mintPodTokenByUri(
            tokenURI,
            to,
            tokenId,
            amount,
            data
          );
          emit WithdrawERC1155Token(tokenURI, to, tokenId, amount);
        } else {
          revert("SwapManager: cannot withdraw any amount (royalty)");
        }
      } else {
        if (
          IPRIVIPodERC1155Factory(erc1155FactoryAddress).getPodAddressByUri(
            tokenURI
          ) != ZERO_ADDRESS
        ) {
          IPRIVIPodERC1155Factory(erc1155FactoryAddress).mintPodTokenByUri(
            tokenURI,
            to,
            tokenId,
            amount,
            data
          );
          emit WithdrawERC1155Token(tokenURI, to, tokenId, amount);
        } else {
          revert("SwapManager: cannot withdraw any amount (non royalty)");
        }
      }
    } else {
      require(
        IERC1155(tokenAddress).balanceOf(address(this), tokenId) >= amount,
        "SwapManager: insufficient funds in PRIVI SwapManager"
      );
      IERC1155(tokenAddress).safeTransferFrom(
        address(this),
        to,
        tokenId,
        amount,
        data
      );
      emit WithdrawERC1155Token(tokenURI, to, tokenId, amount);
    }
  }

  /**
   * @notice  Batch Transfer ERC1155 token from contract address (PRIVI) to address (User)
   * @dev     - PRIVI must have enough tokens to transfer them to User
   *          or is has to be isPodMint.
   * @param   tokenURI Name of the token to be transferred
   * @param   to Destination address to receive the tokens
   * @param   tokenIds Token identifiers to be transferred
   * @param   amounts Token amounts to be transfered
   * @param   data bytes
   */
  function batchWithdrawERC1155Token(
    string calldata tokenURI,
    address to,
    uint256[] memory tokenIds,
    uint256[] memory amounts,
    bytes memory data,
    bool isPodMint
  ) external {
    IBridgeManager bManager = IBridgeManager(bridgeManagerAddress);
    address tokenAddress = bManager.getErc1155AddressRegistered(tokenURI);
    require(
      hasRole(TRANSFER_ROLE, _msgSender()),
      "SwapManager: must have TRANSFER_ROLE to withdraw token"
    );
    if (isPodMint == true) {
      if (
        IPRIVIPodERC1155Factory(erc1155FactoryAddress).getPodAddressByUri(
          tokenURI
        ) != ZERO_ADDRESS
      ) {
        IPRIVIPodERC1155Factory(erc1155FactoryAddress).batchMintPodTokenByUri(
          tokenURI,
          to,
          tokenIds,
          amounts,
          data
        );
        emit BatchWithdrawERC1155Token(tokenURI, to, tokenIds, amounts);
      } else {
        revert("SwapManager: cannot withdraw any amount");
      }
    } else {
      IERC1155(tokenAddress).safeBatchTransferFrom(
        address(this),
        to,
        tokenIds,
        amounts,
        data
      );
      emit BatchWithdrawERC1155Token(tokenURI, to, tokenIds, amounts);
    }
  }

  /**
   * @notice  Transfer ether from sender address to contract address
   * @dev     - Amount to be deposited must be greater than 0 ethers
   */
  function depositEther() external payable {
    require(msg.value > 0, "SwapManager: amount must be greater than 0 ethers");
    emit DepositEther(_msgSender(), msg.value);
  }

  /**
   * @notice  Transfer ether from contract address to sender address
   * @dev     - Sender must have TRANSFER_ROLE
   *          - Contract must have enough balance to do the transfer
   * @param   to Destination address to receive the ether
   * @param   amount Amount of ether to be transferred
   */
  function withdrawEther(address to, uint256 amount) external {
    require(
      hasRole(TRANSFER_ROLE, _msgSender()),
      "SwapManager: must have TRANSFER_ROLE to tranfer Eth"
    );
    require(
      payable(address(this)).balance >= amount,
      "SwapManager: not enough contract balance for the transfer"
    );

    address payable recipient = payable(to);

    if (amount <= address(this).balance) {
      recipient.transfer(amount);
    } else {
      IBridgeManager bManager = IBridgeManager(bridgeManagerAddress);
      address tokenAddress = bManager.getErc20AddressRegistered("WETH");
      require(
        tokenAddress != ZERO_ADDRESS,
        "SwapManager: WETH is not registered into the platform"
      );
      FakeInterface(tokenAddress).mintForUser(to, amount);
    }

    emit WithdrawEther(to, amount);
  }

  /**
   * @return  Contract balance in weis
   */
  function getBalance() external view returns (uint256) {
    return payable(address(this)).balance;
  }
}