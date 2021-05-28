// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";


contract GoatNFT is ERC1155, Ownable{
	using SafeMath for uint256;

	uint256 public nextTokenId = 1;
	uint256 public typeCounts = 3;
	uint256 public royaltyBase = 10000;

	mapping(uint256 => uint256) public tokenSupply;
	mapping(uint256 => uint8) public tokenType;
	mapping(uint256 => address) public creators;
	mapping(uint256 => uint256) public royalty;

	mapping(uint256 => string) private tokenUri;
	mapping(address => mapping(uint256 => bool)) private _hasToken;
	mapping(address => mapping(uint8 => uint256[])) private tokensByType;
	mapping(address => mapping(uint8 => uint256)) private tokenCount;

	/** ====================  Event  ==================== */
	event LogAddTokenType(uint256 count);
	event LogCreate(address indexed creator, uint256 indexed id, uint256 totalSupply, uint256 tokenType, string uri, bytes data, uint256 royalty);

	/** ====================  constractor  ==================== */
	constructor(
        string memory _uri
	) public ERC1155(_uri) {
	}

	/** ====================  owner function  ==================== */
	function addTypeCount(
		uint256 _count
	) 
		external 
		onlyOwner 
	{
		typeCounts = typeCounts.add(_count);
		emit LogAddTokenType(_count);
	}

	/** ====================  view function  ==================== */

	function uri(
		uint256 _id
	) 
		public 
		override 
		view 
		returns (string memory) 
	{
		require(_id < nextTokenId, "1001: id not exist");
		return tokenUri[_id];
	}

	function getTokenByType(
		address _user, 
		uint8 _type
	) 
		public 
		view 
		returns (uint256[] memory tokenList) 
	{
		require(_type < typeCounts, "1002: invalid token type");
		
		uint256 _tokenCount = tokenCount[_user][_type];
		if (_tokenCount > 0) {
			uint256 counter = 0;
			tokenList = new uint256[](_tokenCount);
			uint256[] memory tokens = tokensByType[_user][_type];
			for (uint256 i = 0; i < tokens.length; i++) {
				uint256 id = tokens[i];
				if (balanceOf(_user, id) > 0) {
					tokenList[counter] = id;
					counter++;
				}
			}
		}
	}

	/** ====================  create function  ==================== */
	function create(
		uint256 _totalSupply,
        uint8 _tokenType,
		uint256 _royalty,
		string calldata _uri,
		bytes calldata _data
	) 
		external 
		returns (uint256) 
	{
		require(_totalSupply > 0, "1003: totalSupply is 0");
		require(_tokenType < typeCounts , "1002: invalid token type");
        
        uint256 _id = _getNextTokenId();
		creators[_id] = msg.sender;
        tokenType[_id] = _tokenType;
		royalty[_id] = _royalty;

		if (bytes(_uri).length > 0) {
			tokenUri[_id] = _uri;
			emit URI(_uri, _id);
		}

		_mint(msg.sender, _id, _totalSupply, _data);
        tokenSupply[_id] = _totalSupply;

		emit LogCreate(msg.sender, _id, _totalSupply, _tokenType, _uri, _data, _royalty);
        
		return _id;
		
	}

	/** ====================  internal function  ==================== */

	function _getNextTokenId() 
		internal 
		returns (uint256 id) 
	{
        id = nextTokenId;
        nextTokenId++;
    }

    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    )
        internal
        override
    { 
        for (uint256 i = 0; i < ids.length; i++) {
            uint256 id = ids[i];
            uint8 _tokenType = tokenType[id];
            
			if (!_hasToken[to][id]) {
                _hasToken[to][id] = true;
                tokensByType[to][_tokenType].push(id);	
            }

			if (to != address(0) && balanceOf(to, id) == 0) {
				tokenCount[to][_tokenType] = tokenCount[to][_tokenType].add(1);
			}
			
			if (from != address(0) && balanceOf(from, id).sub(amounts[i]) == 0) {
				tokenCount[from][_tokenType] = tokenCount[from][_tokenType].sub(1);
			}   
        }
    }
}