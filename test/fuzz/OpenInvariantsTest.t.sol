// //SPDX-License-Identifier: MIT

// // First we need to ask What are our invariants

// //1. Total Suppy of DSC should be less than the value of Collateral

// //2. Getter View functions should never revert

// pragma solidity ^0.8.18;

// import {Test,console} from "forge-std/Test.sol";
// import {StdInvariant} from "forge-std/StdInvariant.sol";
// import {DeployDSC} from "../../script/DeployDSC.s.sol";
// import {DSCEngine} from "../../src/DSCEngine.sol";
// import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
// import {HelperConfig} from "../../script/HelperConfig.s.sol";
// import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// contract InvariantsTest is StdInvariant,Test{
//     DeployDSC deployer;
//     DSCEngine dsce;
//     DecentralizedStableCoin dsc;
//     HelperConfig helperConfig;
//     address weth;
//     address wbtc;

//     function setUp() external{
//         deployer=new DeployDSC();
//         (dsc, dsce, helperConfig)=deployer.run();
//         (,,weth,wbtc,)=helperConfig.activeNetworkConfig();
//         targetContract(address(dsce));

//     }

//     function invariant_protocolMusthaveMoreValueThanTotalSupply() public view{
//         // get the value of all the collateral in the protocol
//         //compare it to all the debt(dsc)
//         uint256 totalSupply=dsc.totalSupply();
//         uint256 totalWethDeposited=IERC20(weth).balanceOf(address(dsce));
//         uint256 totalWbtcDeposited=IERC20(wbtc).balanceOf(address(dsce));

//         uint256 wethValue=dsce.getUSDValue(weth,totalWethDeposited);
//         uint256 wbtcValue=dsce.getUSDValue(wbtc,totalWbtcDeposited);

//         console.log("weth value:",wethValue);
//         console.log("wbtc value:",wbtcValue);
//         console.log("total supply:",totalSupply);

//         assert(wethValue+wbtcValue>=totalSupply);

//     }
// }
