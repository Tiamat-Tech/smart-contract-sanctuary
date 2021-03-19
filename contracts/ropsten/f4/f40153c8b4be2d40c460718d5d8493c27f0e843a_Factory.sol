// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./../dependencies/contracts/IERC20Detailed.sol";
import "./../dependencies/pancake/core/interfaces/IPancakeFactory.sol";
import "./../interfaces/IFactory.sol";
import "./libraries/helpers/Errors.sol";
import "./libraries/upgradeability/Versioned.sol";
import "./Pool.sol";
import "./Reserve.sol";

/**
 * @title FactoryStorage contract
 * @dev Defines all stored data for Factory
 * @author WOWSwap
 **/
abstract contract FactoryStorage is
    Initializable,
    ContextUpgradeable,
    Versioned,
    OwnableUpgradeable
{
    bytes32 internal m_poolHash;
    bytes32 internal m_reserveHash;
    IPancakeFactory internal m_pancakeFactory;

    // Registry of swap pools (first key is lendable token, second is tradable)
    mapping(address => mapping(address => address)) internal m_pools;

    // Registry of lendable reserves
    mapping(address => address) internal m_reserves;

    EnumerableSet.AddressSet internal m_tradables;
    EnumerableSet.AddressSet internal m_lendables;

    address[] internal m_tradableTokensArray;

    uint256[50] private ______gap;
}

/**
 * @title FactoryStorage contract
 * @dev Defines all stored data for Factory
 * @author WOWSwap
 **/
contract Factory is FactoryStorage, IFactory {
    using EnumerableSet for EnumerableSet.AddressSet;

    uint256 public constant REVISION = 0x1;

    modifier isTradable(address token) {
        require(m_tradables.contains(token), Errors.F_NOT_TRADABLE_TOKEN);
        _;
    }

    modifier isLendable(address token) {
        require(m_lendables.contains(token), Errors.F_NOT_LENDABLE_TOKEN);
        _;
    }

    modifier isRegisteredToken(address token) {
        require(
            m_tradables.contains(token) || m_lendables.contains(token),
            Errors.F_NOT_REGISTERED_TOKEN
        );
        _;
    }

    function getRevision() internal pure override returns (uint256) {
        return REVISION;
    }

    function initialize(address pancakeFactory) public initializer {
        __Context_init_unchained();
        __Ownable_init();
        __Versioned_init_unchained();

        m_poolHash = bytes32(hex"01");
        m_reserveHash = bytes32(hex"01");
        m_pancakeFactory = IPancakeFactory(pancakeFactory);
    }

    function getPool(address lendable, address tradable)
        external
        view
        virtual
        override
        returns (address)
    {
        return m_pools[lendable][tradable];
    }

    function getReserve(address lendable)
        external
        view
        virtual
        override
        returns (address)
    {
        return m_reserves[lendable];
    }

    function getOrCreateReserve(address lendable)
        public
        virtual
        override
        isLendable(lendable)
        returns (address)
    {
        if (m_reserves[lendable] == address(0x0)) {
            address reserve = _createReserve(lendable);
            m_reserves[lendable] = reserve;

            string memory name = IERC20Detailed(lendable).name();
            string memory symbol = IERC20Detailed(lendable).symbol();

            Reserve(reserve).initialize(name, symbol);
        }

        return m_reserves[lendable];
    }

    function getOrCreatePool(address lendable, address tradable)
        public
        virtual
        override
        isLendable(lendable)
        isTradable(tradable)
        returns (address)
    {
        if (m_pools[lendable][tradable] == address(0x0)) {
            address pool = _createPool(lendable, tradable);
            m_pools[lendable][tradable] = pool;

            // TODO: initialize
            address reserve = getOrCreateReserve(lendable);
            address pancakePair = m_pancakeFactory.getPair(lendable, tradable);
            string memory name = IERC20Detailed(tradable).name();
            string memory symbol = IERC20Detailed(tradable).symbol();

            Pool(pool).initialize(
                reserve,
                pancakePair,
                lendable,
                tradable,
                name,
                symbol
            );
        }

        return m_pools[lendable][tradable];
    }

    function poolBytecodeHash()
        external
        view
        virtual
        override
        returns (bytes32)
    {
        return m_poolHash;
    }

    function reserveBytecodeHash()
        external
        view
        virtual
        override
        returns (bytes32)
    {
        return m_reserveHash;
    }

    function registerTradable(address token)
        external
        virtual
        override
        onlyOwner
        returns (bool)
    {
        require(
            !m_tradables.contains(token),
            Errors.F_ALREADY_REGISTERED_TRADABLE
        );

        m_tradables.add(token);
        return true;
    }

    function registerTradables(address[] calldata tokens)
        external
        virtual
        override
        onlyOwner
        returns (bool)
    {
        for (uint256 index = 0; index < tokens.length; index++) {
            if (!m_tradables.contains(tokens[index])) {
                m_tradables.add(tokens[index]);
            }
        }

        return true;
    }

    function registerLendable(address token)
        external
        virtual
        override
        onlyOwner
        returns (bool)
    {
        require(
            !m_lendables.contains(token),
            Errors.F_ALREADY_REGISTERED_LENDABLE
        );

        m_lendables.add(token);
        return true;
    }

    function registerLendables(address[] calldata tokens)
        external
        virtual
        override
        onlyOwner
        returns (bool)
    {
        for (uint256 index = 0; index < tokens.length; index++) {
            if (!m_lendables.contains(tokens[index])) {
                m_lendables.add(tokens[index]);
            }
        }

        return true;
    }

    function getAllTradables()
        external
        view
        virtual
        override
        returns (bytes32[] memory)
    {
        return m_tradables._inner._values;
    }

    function getAllLendables()
        external
        view
        virtual
        override
        returns (bytes32[] memory)
    {
        return m_lendables._inner._values;
    }

    function parseTokens(address tokenA, address tokenB)
        external
        view
        virtual
        override
        isRegisteredToken(tokenA)
        isRegisteredToken(tokenB)
        returns (address lendable, address tradable)
    {
        lendable = m_lendables.contains(tokenA)
            ? tokenA
            : m_lendables.contains(tokenB)
            ? tokenB
            : address(0x0);
        tradable = lendable == tokenA ? tokenB : tokenA;
    }

    function _create(bytes memory bytecode, bytes32 salt)
        internal
        returns (address dest)
    {
        assembly {
            dest := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
    }

    function _createPool(address lendable, address tradable)
        internal
        returns (address dest)
    {
        dest = _create(
            type(Pool).creationCode,
            keccak256(abi.encodePacked(lendable, tradable))
        );
    }

    function _createReserve(address lendable) internal returns (address dest) {
        dest = _create(
            type(Reserve).creationCode,
            keccak256(abi.encodePacked(lendable))
        );
    }
}