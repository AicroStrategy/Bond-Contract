// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ERC20} from "solmate/tokens/ERC20.sol";

/// @title MintableERC20
/// @notice ERC20 token that can be minted by an authorized bond factory for bond redemptions
/// @dev Only the bond factory can mint new tokens, initial supply is minted to deployer
contract MintableERC20 is ERC20 {
    address public bondFactory;

    /// @notice Creates a new mintable ERC20 token
    /// @param _name Token name
    /// @param _symbol Token symbol
    /// @param _decimals Token decimal places
    /// @param _supply Initial token supply
    /// @param _bondFactory Address of the authorized bond factory
    constructor(string memory _name, string memory _symbol, uint8 _decimals, uint256 _supply, address _bondFactory)
        ERC20(_name, _symbol, _decimals)
    {
        bondFactory = _bondFactory;
        _mint(msg.sender, _supply);
    }

    /// @dev Restricts function access to the bond factory
    modifier onlyBondFactory() {
        require(msg.sender == bondFactory, "Only bond factory can call this function");
        _;
    }

    /// @notice Mints new tokens to a specified address
    /// @dev Can only be called by the authorized bond factory during bond redemption
    /// @param to Address to receive the tokens
    /// @param amount Amount of tokens to mint
    function mint(address to, uint256 amount) external onlyBondFactory {
        _mint(to, amount);
    }
}
