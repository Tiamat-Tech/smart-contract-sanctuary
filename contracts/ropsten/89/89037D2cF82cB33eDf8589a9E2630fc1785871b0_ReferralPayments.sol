// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract ReferralPayments is ReentrancyGuard {
    using Address for address;
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address payable public governor;

    mapping(address => uint256) public  lastClaimedAt;

    mapping(address => uint256) public totalClaimed;
    mapping(address => uint256) public totalUnclaimed;
    mapping(string => mapping(address => uint256)) public claimedAmounts;
    mapping(string => mapping(address => uint256)) public claimableAmounts;

    mapping(address => uint256) public totalRevoked;

    address[] public tokens;

    mapping(address => string) private tokensSymbols;
    mapping(string => address) private tokensBySymbol;

    struct SupportedToken {
        string symbol;
        address location;
    }

    uint256 revokingPeriodInSecs = 7889400; // 3 months

    event Claim(address token, address owner, uint256 amount);
    event AddClaimableAmount(address token, address owner, uint256 amount);
    event RevokeClaimableAmount(address token, address owner, uint256 amount);

    constructor(SupportedToken[] memory supportedTokens) {
        governor = payable(msg.sender);

        for (uint counter; counter < supportedTokens.length; counter++) {
            SupportedToken memory token = supportedTokens[counter];

            _addToken(token.location, token.symbol);
        }
    }

    function setGovernor(address payable newGovernor) external {
        require(msg.sender == governor, "ReferralPayments: !governor");

        governor = newGovernor;
    }

    function addToken(address token, string memory symbol) external {
        require(msg.sender == governor, "ReferralPayments: !governor");

        _addToken(token, symbol);
    }

    function _addToken(address token, string memory symbol) internal {
        tokensSymbols[token] = symbol;
        tokensBySymbol[symbol] = token;

        tokens.push(token);
    }

    function addClaimableAmount(
        string memory token,
        address owner,
        uint256 amount
    ) external {
        require(msg.sender == governor, "ReferralPayments: !governor");

        address tokenAddress = tokensBySymbol[token];
        uint256 currentAmount = claimableAmounts[token][owner];

        claimableAmounts[token][owner] = currentAmount.add(amount);
        totalUnclaimed[tokenAddress] = totalUnclaimed[tokenAddress].add(
            amount
        );

        emit AddClaimableAmount(tokenAddress, owner, amount);
    }

	function transferOut(address token, uint256 amount) external {
        require(msg.sender == governor, "ReferralPayments: !governor");

		IERC20(token).safeTransfer(governor, amount);
    }

    function revokeUnclaimedAmounts(address[] memory owners) external {
        require(msg.sender == governor, "ReferralPayments: !governor");

        for (uint256 counter = 0; counter < owners.length; counter++) {
            address owner = owners[counter];
            uint256 lastClaimedDate = lastClaimedAt[owner];

            if (block.timestamp - lastClaimedDate <= revokingPeriodInSecs) {
                continue;
            }

            for (uint256 i = 0; i < tokens.length; i++) {
                address tokenAddress = tokens[i];
                string memory tokenSymbol = tokensSymbols[tokenAddress];

                uint256 amountToRevoke = claimableAmounts[tokenSymbol][owner];

                if (amountToRevoke == 0) {
                    continue;
                }

                _revokeUnclaimedAmount(
                    owner,
                    SupportedToken(tokenSymbol, tokenAddress),
                    amountToRevoke
                );
            }
        }
    }

    function _revokeUnclaimedAmount(
        address owner,
        SupportedToken memory supportedToken,
        uint256 amountToRevoke
    ) internal {
        claimableAmounts[supportedToken.symbol][owner] = 0;
        claimedAmounts[supportedToken.symbol][owner] = claimedAmounts[
            supportedToken.symbol
        ][owner]
            .add(amountToRevoke);

        totalRevoked[supportedToken.location] = totalRevoked[
            supportedToken.location
        ]
            .add(amountToRevoke);
        totalUnclaimed[supportedToken.location] = totalUnclaimed[
            supportedToken.location
        ]
            .sub(amountToRevoke);

        emit RevokeClaimableAmount(
            supportedToken.location,
            owner,
            amountToRevoke
        );
    }

    function claim(address owner) external nonReentrant {
        for (uint256 counter = 0; counter < tokens.length; counter++) {
            address tokenAddress = tokens[counter];
            string memory tokenSymbol = tokensSymbols[tokenAddress];

            uint256 amountToClaim = claimableAmounts[tokenSymbol][owner];

            if (amountToClaim == 0) {
                continue;
            }

            _claimAmount(
                owner,
                SupportedToken(tokenSymbol, tokenAddress),
                amountToClaim
            );
        }
    }

    function _claimAmount(
        address owner,
        SupportedToken memory supportedToken,
        uint256 amountToClaim
    ) internal {
        claimableAmounts[supportedToken.symbol][owner] = 0;
        claimedAmounts[supportedToken.symbol][owner] = claimedAmounts[
            supportedToken.symbol
        ][owner]
            .add(amountToClaim);

        IERC20(supportedToken.location).safeTransfer(owner, amountToClaim);

        totalClaimed[supportedToken.location] = totalClaimed[
            supportedToken.location
        ]
            .add(amountToClaim);
        totalUnclaimed[supportedToken.location] = totalUnclaimed[
            supportedToken.location
        ]
            .sub(amountToClaim);

        emit Claim(supportedToken.location, owner, amountToClaim);

        lastClaimedAt[owner] = block.timestamp;
    }
}