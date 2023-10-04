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

pragma solidity ^0.8.18;
/**
 * @title DSC Engine
 * @dev Pramit
 * The system is designed to be as minimal as possible and have the tokens maintain a 1$ peg
 * It is similar to DAI if DAI had no governance. It is backed wBTC and wETH
 * @notice Our system should always be overcollateralized.
 * @notice This contract very loosely based on the Dai Stablecoin System
 * @notice This contract has the logic for mining and redeeming DSC and for withdrawing and depositing collateral
 */

import {DecentralizedStableCoin} from "./DecentralizedStableCoin.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract DSCEngine is ReentrancyGuard {
    //////////////////////
    ////////Errors////////
    //////////////////////

    ////////////////////////
    /////State Variables////
    ////////////////////////
    mapping(address token => address priceFeed) s_PriceFeeds;
    mapping(address user => mapping(address collateralToken => uint256 amount)) private s_collateralDeposited;
    mapping(address user => uint256 amountDSCMinted) private s_DSCMinted;
    address[] private s_collateralToken;

    DecentralizedStableCoin private immutable i_dsc;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant LIQUIDATION_THRESHOLD = 50; // This means you need to be 200% over-collateralized
    uint256 private constant LIQUIDATION_PRECISION = 100; // This means you need to be 200% over-collateralized
    uint256 private constant MIN_HEALTH_FACTOR = 1e18;
    uint256 private constant LIQUIDATION_BONUS = 10;
    ////////////////////////
    ///////Events//////////
    ////////////////////////

    event CollateralDeposited(address indexed user, address indexed tokenCollateralAddress, uint256 amountCollateral);
    event CollateralRedeemed(
        address indexed user, address indexed to, address indexed tokenCollateralAddress, uint256 amount
    );

    error DSCEngine__MustBeMoreThanZero();
    error DSCEngine__TokenAndPriceFeedAddressLengthMismatch();
    error DSCEngine__NotAllowedToken();
    error DSCEngine__TransferFailed();
    error DSCEngine__BreaksHealthFactor(uint256 healthFactor);
    error DSCEngine__MintFailed();
    error DSCEngine__HealthFactorOK();
    error DSCEngine__HealthFactorNotImproved();
    ///////////////////////
    ///////Modifier///////
    //////////////////////

    modifier MoreThanZero(uint256 _amount) {
        if (_amount == 0) {
            revert DSCEngine__MustBeMoreThanZero();
        }
        _;
    }

    modifier isAllowedToken(address _token) {
        if (s_PriceFeeds[_token] == address(0)) {
            revert DSCEngine__NotAllowedToken();
        }
        _;
    }
    ///////////////////////
    ///////Functions///////
    //////////////////////

    constructor(address[] memory tokenAddresses, address[] memory priceFeedAddresses, address DSCAddress) {
        if (tokenAddresses.length != priceFeedAddresses.length) {
            revert DSCEngine__TokenAndPriceFeedAddressLengthMismatch();
        }
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            s_PriceFeeds[tokenAddresses[i]] = priceFeedAddresses[i]; //If the tokens have a price feed they are allowed on the platform
            s_collateralToken.push(tokenAddresses[i]);
        }
        i_dsc = DecentralizedStableCoin(DSCAddress); //?
    }

    ////////////////////////////////
    ///////External Functions///////
    ////////////////////////////////

    //Whenever working with an external function, it is a good idea to have a non-reentrant modifier

    function depositCollateral(address tokenCollateralAddress, uint256 amountCollateral)
        public
        MoreThanZero(amountCollateral)
        isAllowedToken(tokenCollateralAddress)
        nonReentrant
    {
        //First we need to track how much collateral someone has deposited
        s_collateralDeposited[msg.sender][tokenCollateralAddress] += amountCollateral;
        //When we update state we should emit
        emit CollateralDeposited(msg.sender, tokenCollateralAddress, amountCollateral);
        //We need to wrap our collateral as an ERC-20
        bool success = IERC20(tokenCollateralAddress).transferFrom(msg.sender, address(this), amountCollateral);
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
    }

    /*
    * @notice This function burns DSC and redeems collateral in one transaction
    */
    function redeemCollateralForDSC(address tokenCollateralAddress, uint256 amountCollateral) external {
        redeemCollateral(tokenCollateralAddress, amountCollateral);
        burnDSC(amountCollateral);
    }
    // 1. Health Factor must be over 1 after collateral is pulled

    function redeemCollateral(address tokenCollateralAddress, uint256 amountCollateral)
        public
        MoreThanZero(amountCollateral)
        nonReentrant
    {
        _redeemCollateral(tokenCollateralAddress, amountCollateral, msg.sender, msg.sender);
        _revertIfHealthFactorBelowThreshold(msg.sender);
    }

    /*
    *  @param tokenCollateralAddress: The address of the token to deposit as collateral
    *  @param amountCollateral: The amount of collateral to deposit
    *   @param amountDSCToMint: The amount of DSC to mint
    *   @notice This function is a convenience function that allows you to deposit collateral and mint DSC in one transaction
    */
    function depositCollateralAndMintDSC(
        address tokenCollateralAddress,
        uint256 amountCollateral,
        uint256 amountDSCToMint
    ) external {
        depositCollateral(tokenCollateralAddress, amountCollateral);
        mintDSC(amountDSCToMint);
    }

    //
    function burnDSC(uint256 amount) public {
        _burnDSC(amount, msg.sender, msg.sender);
        _revertIfHealthFactorBelowThreshold(msg.sender); // I don't think we need this here  because we are burning DSC
    }

    //In order to be able to mint Token we need to check that the Collateral value>DSC amount
    /**
     * @notice Follows CEI pattern
     * @param amountDSCToMint  The amount of Decentralized Stable Coin to mint
     * @notice They must have more collateral than the minimum Threshold
     */
    function mintDSC(uint256 amountDSCToMint) public MoreThanZero(amountDSCToMint) nonReentrant {
        s_DSCMinted[msg.sender] += amountDSCToMint;
        _revertIfHealthFactorBelowThreshold(msg.sender);
        bool minted = i_dsc.mint(msg.sender, amountDSCToMint);
        if (!minted) {
            revert DSCEngine__MintFailed();
        }
    }

    // If we start nearing undercollaterallization we need someone to liquidate the position

    //If someone is undercollateralized we will pay you to liquidate them
    // $75ETH  backing $50 DSC
    // Liquadator takes $75 ETH and burns $50 DSC

    /*
    * @param collateral
    * @param user address user who has broken the health factor. Their _healthFactor should be below MIN_HEALTH_FACTOR
    * @param debtToCover The amount of DSC to burn to improve the User's health factor
    * @notice You can partially liquidate a someone 
    * @notice You will get a liquidation bonus for taking the user's funds 
    * @notice this function assumes that the protocol is 200% collateralized in order for this to work
    * @notice A known bug would be if the protocol wwas 100% or less collateralized then we would not be able to incentivize liquidators
    */
    function liquidate(address collateral, address user, uint256 debtToCover)
        external
        MoreThanZero(debtToCover)
        nonReentrant
    {
        uint256 startingUserHealthFactor = _healthFactor(user);
        if (startingUserHealthFactor >= MIN_HEALTH_FACTOR) {
            revert DSCEngine__HealthFactorOK();
        }
        // We want to burn their DSC and take their collateral
        uint256 tokenAmountFromDebtCovered = getTokenAmountFromUSD(collateral, debtToCover);
        // We want to give the Liquidator a 10%  bonus for taking the user's funds.
        //$200weth for $100 DSC
        // then $150weth for $100 DSC
        // then $140wEth for $100 DSC
        // $110wEth for $100 DSC as reward
        //We should implement a feature to liquidate in the event of insolvency
        //Move the extra funds to a treasury

        uint256 bonusCollateral = (tokenAmountFromDebtCovered * LIQUIDATION_BONUS) / PRECISION;
        uint256 totalCollateralToRedeem = tokenAmountFromDebtCovered + bonusCollateral;
        _redeemCollateral(collateral, totalCollateralToRedeem, user, msg.sender);
        // After redeeming collateral we need to burn the DSC
        _burnDSC(debtToCover, user, msg.sender);

        uint256 endingUserHealthFactor = _healthFactor(user);
        if (endingUserHealthFactor < MIN_HEALTH_FACTOR) {
            revert DSCEngine__HealthFactorNotImproved();
        }
        _revertIfHealthFactorBelowThreshold(msg.sender);
    }

    function getHealthFator() external {}
    ////////////////////////////////////////////////
    ///////Private & Internal View Functions////////
    ///////////////////////////////////////////////

    /*
    * @dev low-level internal call , do not call unless the function calling it is checking for health factor being broken
    * 
    */
    function _burnDSC(uint256 amountDSCToBurn, address onBehalfOf, address dscFrom) private {
        s_DSCMinted[onBehalfOf] -= amountDSCToBurn;
        bool success = i_dsc.transferFrom(dscFrom, address(this), amountDSCToBurn);
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
        i_dsc.burn(amountDSCToBurn);
    }

    function _redeemCollateral(address tokenCollateral, uint256 amount, address from, address to) private {
        s_collateralDeposited[from][tokenCollateral] -= amount;
        emit CollateralRedeemed(from, to, tokenCollateral, amount);
        //check for Health Factor
        bool success = IERC20(tokenCollateral).transfer(to, amount);
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
    }

    function _getAccountInformation(address user)
        private
        view
        returns (uint256 totalDSCMinted, uint256 collateralValueInUSD)
    {
        totalDSCMinted = s_DSCMinted[user];
        collateralValueInUSD = getAccountCollateralValue(user);
    }

    function _healthFactor(address user) private view returns (uint256) {
        //1. Get the value of all the collateral
        //2. Get the value of all the DSC minted
        //3. Divide the value of all the collateral by the value of all the DSC
        (uint256 totalDSCMinted, uint256 collateralValueInUSD) = _getAccountInformation(user);
        uint256 collateralAdjustedForThreshold = (collateralValueInUSD * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
        return (collateralAdjustedForThreshold * PRECISION) / totalDSCMinted;
        // return _calculateHealthFactor(totalDscMinted, collateralValueInUsd);
    }
    //1. Check Helath Factor (do they have enough collateral)
    //2. Revert if they do't

    function _revertIfHealthFactorBelowThreshold(address user) internal view {
        uint256 userhealthFactor = _healthFactor(user);
        if (userhealthFactor < MIN_HEALTH_FACTOR) {
            revert DSCEngine__BreaksHealthFactor(userhealthFactor);
        }
    }

    ///////////////////////////////////////////////
    ///////Public & External View Functions////////
    ///////////////////////////////////////////////

    function getTokenAmountFromUSD(address token, uint256 usdAmountInWei) public view returns (uint256) {
        //price of ETH
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_PriceFeeds[token]);
        (, int256 price,,,) = priceFeed.latestRoundData();
        //($10e18*1e18)/($2000e8*1e10)
        return (usdAmountInWei * PRECISION) / (uint256(price) * ADDITIONAL_FEED_PRECISION);
    }

    function getAccountCollateralValue(address user) public view returns (uint256 totalCollateralValue) {
        /**
         * Loop through all the collateral tokens, get the amount deposited and map it to the price in USD
         *
         */
        for (uint256 i = 0; i < s_collateralToken.length; i++) {
            address token = s_collateralToken[i];
            uint256 amount = s_collateralDeposited[user][token];
            totalCollateralValue += getUSDValue(token, amount);
        }
    }

    function getUSDValue(address token, uint256 amount) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_PriceFeeds[token]);
        (, int256 price,,,) = priceFeed.latestRoundData();
        // 1 ETH = 1000 USD
        // The returned value from Chainlink will be 1000 * 1e8
        // Most USD pairs have 8 decimals, so we will just pretend they all do
        // We want to have everything in terms of WEI, so we add 10 zeros at the end
        return ((uint256(price) * ADDITIONAL_FEED_PRECISION) * amount) / PRECISION;
    }

    function getAccountInformation(address user)
        external
        view
        returns (uint256 totalDSCMinted, uint256 collateralValueInUSD)
    {
        (totalDSCMinted, collateralValueInUSD) = _getAccountInformation(user);
    }
}
