// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import "./ArticleNFT.sol";

/**
 * @title Decentrastack
 * @dev dApp is a simple publishing platform that allows web3-connected users to 
 * publish articles, view other authors publishings, and subscribe/unsubscribe to/from authors.
 * Every new article is also minted as an ERC721 standard NFT, where the ownership is transferred
 * to the authoring user.
 */
contract Decentrastack is ArticleNFT {  
  
  struct Article {
    address author;
    string title;
    string contentIpfsHash; // ipfs hash of body content, to reduce storage costs
    uint256 date; // date of publication (via block.timestamp)
    uint256 articleId; // keccak hash of author, title, contentIpfsHash, date (block.timestamp)
  }

  // @dev All articles ever written
  Article[] public articles;

  // @dev `authorToArticles` maps all authoring addresses to corresponding authored article(s)
  // @dev `usersToSubscribedAuthors` maps all user addresses to corresponding subscribed authors
  mapping(address => Article[]) public authorToArticles;
  mapping(address => address[]) public usersToSubscribedAuthors;

  // @dev events for new article publications & user (un)subscribing
  event ArticlePublished(address indexed _author, string _title, string indexed _contentIpfsHash, uint256 _date, uint256 indexed _articleId);
  event NewUserSubscription(address indexed _follower, address indexed _author);
  event UserUnsubscribedFromAuthor(address indexed _follower, address indexed _author);

  /**
   * @dev Creates a new article & mint as NFT via `createCollectible`
   * @param _title Article's associated title
   * @param _contentIpfsHash Hash calculated / returned by ipfs
   */
  function createArticle(string memory _title, string memory _contentIpfsHash) public returns(uint256 newArticleId) {
    require(bytes(_title).length > 0, "Title must have a non-empty value");
    require(bytes(_contentIpfsHash).length > 0, "Article content must have a non-empty value");
   
    // @dev `createCollectible` is part of ArticleNFT contract; mints NFT & returns tokenId
    newArticleId = createCollectible(msg.sender, _title, _contentIpfsHash);

    Article memory newArticle = Article({
      author: msg.sender,
      title: _title,
      contentIpfsHash: _contentIpfsHash,
      date: block.timestamp,
      articleId: newArticleId
    });

    authorToArticles[msg.sender].push(newArticle);
    articles.push(newArticle);
    
    emit ArticlePublished(newArticle.author, newArticle.title, newArticle.contentIpfsHash, newArticle.date, newArticle.articleId);
  }

  // @dev Retrieve all articles ever published
  function getArticles() public view returns(Article[] memory) {
      return articles;
  }

  /** 
   * @dev Retrieve authors in which a user is subsribed to
   * @param _user Address of user requesting associated subscriptions
   */
  function getUserToSubscribedAuthors(address _user) public view returns(address[] memory) {
      return usersToSubscribedAuthors[_user];
  }

  /**
   * @dev Allow a user to subscribe to a publishing article's author
   * @param _author Address associated with article's publishing author
   */
  function subscribeToAuthor(address _author) public {
    require(_author != address(0), 'Invalid author');
    require(_author != msg.sender, 'Author cannot subscribe to itself');
    bool alreadySubscribed = false;
    for(uint i = 0; i < usersToSubscribedAuthors[msg.sender].length; i++) {
      if(usersToSubscribedAuthors[msg.sender][i] == _author) {
        alreadySubscribed = true;
        break;
      }
    }
    if(!alreadySubscribed) {
        usersToSubscribedAuthors[msg.sender].push(_author);
        emit NewUserSubscription(msg.sender, _author);
    }
  }

  /**
   * @dev Allow a user to unsubscribe from an author
   * @param _author Address associated with article's publishing author
   */
  function unsubscribeFromAuthor(address _author) public {
    require(_author != address(0), 'Invalid _author');
    for(uint i = 0; i < usersToSubscribedAuthors[msg.sender].length; i++) {
      if(usersToSubscribedAuthors[msg.sender][i] == _author) {
        // @dev swap index with the last item in the array and then `delete` & shorten array
        // Note: this is to prevent 0x0 value being written to author & bloating array
        usersToSubscribedAuthors[msg.sender][i] = usersToSubscribedAuthors[msg.sender][usersToSubscribedAuthors[msg.sender].length - 1];
        usersToSubscribedAuthors[msg.sender].pop();
        emit UserUnsubscribedFromAuthor(msg.sender, _author);
        break;
      }
    }
  }
}