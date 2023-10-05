//SPDX-License-Identifier: MIT

//Handler Narrows down the way we call functions 

pragma solidity ^0.8.18;
import {Test} from "forge-std/Test.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";


contract Handler is Test{
    DSCEngine dsce;
    DecentralizedStableCoin dsc;
    constructor(DSCEngine _dscEngine,DecentralizedStableCoin _dsc){
        dsce=_dscEngine;
        dsc=_dsc;
    }
    
    function depositCollateral(address collateral,uint256 amountCollateral) public{
        dsce.depositCollateral(collateral)
    }
}
