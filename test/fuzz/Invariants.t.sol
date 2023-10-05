//SPDX-License-Identifier: MIT


pragma solidity ^0.8.18;

import {Test,console} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Handler} from "./Handler.t.sol";

contract InvariantsTest is StdInvariant,Test{
    DeployDSC deployer;
    DSCEngine dsce;
    DecentralizedStableCoin dsc;
    HelperConfig helperConfig;
    address weth;
    address wbtc;
    Handler handler;


    function setUp() external{
        deployer=new DeployDSC();
        (dsc, dsce, helperConfig)=deployer.run();
        (,,weth,wbtc,)=helperConfig.activeNetworkConfig();
        // targetContract(address(dsce));
        //We need to call the functions in sensical order
        // for eg. Don't call redeem collateral unless you have deposited collateral
        //So we are going to make a handler which is going to make calls the way we want
        handler =new Handler(dsce,dsc);
        targetContract(handler);
    }

    function invariant_protocolMusthaveMoreValueThanTotalSupply() public view{
        // get the value of all the collateral in the protocol
        //compare it to all the debt(dsc)
        uint256 totalSupply=dsc.totalSupply();
        uint256 totalWethDeposited=IERC20(weth).balanceOf(address(dsce));
        uint256 totalWbtcDeposited=IERC20(wbtc).balanceOf(address(dsce));

        uint256 wethValue=dsce.getUSDValue(weth,totalWethDeposited);
        uint256 wbtcValue=dsce.getUSDValue(wbtc,totalWbtcDeposited);

        console.log("weth value:",wethValue);
        console.log("wbtc value:",wbtcValue);
        console.log("total supply:",totalSupply);

        assert(wethValue+wbtcValue>=totalSupply);

    }
}
