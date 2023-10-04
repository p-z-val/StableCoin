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