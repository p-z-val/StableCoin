//SPDX-License-Identifier: MIT
// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// internal & private view & pure functions
// external & public view & pure functions

/**
 * @title Decentralized Stable Coin
 * @dev Pramit
 * Collateral: exogenous
 * Minting Mechanism: Algorithmic
 * Relative Stability: Pegged to USD
 * This contract is just the ERC20 implementation of the Decentralized Stable Coin. This contract is meant to be governed by DSCEngine contract.
 */

pragma solidity ^0.8.18;

import {ERC20Burnable, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol"; //We want the token to be 100% controlled by our logic

contract DecentralizedStableCoin is ERC20Burnable, Ownable {
    error DecentralizedStableCoin__MustBeMoreThanZero();
    error DecentralizedStableCoin__BurnAmountMustBeLessThanBalance();
    error DecentralizedStableCoin__NotZeroAddress();

    constructor() ERC20("DecentralizedStableCoin", "DSC") {}

    function burn(uint256 _amount) public override onlyOwner {
        uint256 balance = balanceOf(msg.sender);
        if (_amount <= 0) {
            revert DecentralizedStableCoin__MustBeMoreThanZero();
        }
        if (balance < _amount) {
            revert DecentralizedStableCoin__BurnAmountMustBeLessThanBalance();
        }
        super.burn(_amount); // this tells to call the burn function of ERC20Burnable contract(base contract)
    }

    function mint(address _to, uint256 _amount) public onlyOwner returns (bool) {
        //Owner of this is going to be DSCEngine
        if (_to == address(0)) {
            revert DecentralizedStableCoin__NotZeroAddress();
        }
        if (_amount <= 0) {
            revert DecentralizedStableCoin__MustBeMoreThanZero();
        }
        _mint(_to, _amount); //no need to override here beacuse there is no _mint function in the base contract
        return true;
    }
}
