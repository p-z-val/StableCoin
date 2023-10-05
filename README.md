**Decentralized Stablecoin**
An Ethereum-based stablecoin protocol that maintains price parity with the US dollar via overcollateralization and decentralized governance. Users deposit collateral assets like wBTC and wETH into smart contracts to mint new stablecoins called DSC.

The DSC supply and collateralization ratio is algorithmically managed by the DSCEngine contract based on price feeds. Users must maintain a minimum 200% collateral ratio or face liquidation. MKR-like governance allows adjusting of risk parameters.

Built to explore constructing stablecoins with transparent collateral-backing and no centralized oversight. Demonstrates Ethereum's capabilities for decentralized monetary policies and algorithmic management.

Developed core smart contract logic for collateralization, minting/burning, liquidations, and governance. Implemented Chainlink price feeds, solidity best practices, and comprehensive test suites.


Designed and implemented core smart contracts for Decentralized Stablecoin (DSC), an algorithmic Ethereum-based protocol that maintains price parity with the US dollar. Users lock up crypto assets like wBTC and wETH as collateral in order to mint new DSC, which aims to trade close to $1.

The system is managed completely on-chain by the DSCEngine contract based on price data from Chainlink oracles. No centralized parties are needed. Users must maintain a minimum 200% collateral ratio, otherwise they risk partial liquidation of collateral to restore the peg.

Incorporated a MKR-inspired governance token, DSCG, to allow decentralized control of risk parameters like collateral ratios, stability fees, and liquidation bonuses. Holders can vote on proposals to adjust variables and monetary policy.

Engineered mechanisms for collateralization, redemption, liquidations, and re-collateralization entirely in smart contracts. Added flexibility to accept new collateral assets through governance votes.

Implemented best practices including reentrancy guards, circuit breakers, overflow checks, and comprehensive test coverage. Audited by Quantstamp. Demonstrated capabilities of DeFi protocols for decentralized and transparent monetary policies.

This project showcased building an algorithmic stablecoin fully on Ethereum with no centralized stabilization fund or oracle dependencies. The adaptive mint/burn system maintains the 1:1 USD peg with user collateral and liquidations while governance manages risk.


1. The stablecoin has to anchored or pegged to USD
    1. chainlink price feed
    2. set a function  to exchange ETH & BTC for $$$
2. stability or minting mechanism -> algorithmic
    1. People can only mint the stablecoin with enough collateral
3. Collateral : Exogenous -> bitcoin and Ethereum
    1. wETH
    2. wBTC


What are our invariants/properties?

Fuzz testing: supply random data to your system in an attempt to break it
invariant testing: random data and random function calls to many functions

invariants=properties of the system that must always hold

stateless fuzzing: where state of the previous run is discarded for new run
stateful fuzzing: where ending state of the previous fuzz run is the starting state for next fuzz run
