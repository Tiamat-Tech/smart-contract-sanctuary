pragma solidity ^0.8.0;
import "./Factory.sol";
import "./DAOtoken.sol";


/// @title Multisignature wallet factory - Allows creation of multisig wallet.
/// @author Stefan George - <[email protected]>
contract DAOtokenFactory is Factory {

    /*
     * Public functions
     */
    /// @dev Allows verified creation of multisignature wallet.
    /// @param _DAOname List of initial owners.
    /// @param _DAOsymbol Number of required confirmations.
    /// @param amount Number of required confirmations.
    /// @return contract_addr Returns token contract address.
    function mint(string memory _DAOname, string memory _DAOsymbol, uint amount)
        public 
        returns (address contract_addr)
    {
        // wallet = address(new MultiSigWallet(_owners, _required));
        contract_addr = address(new DAOtoken(_DAOname, _DAOsymbol, amount));
        register(contract_addr);
    }
}