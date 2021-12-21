pragma solidity ^0.8.3;

import "./Owned.sol";
//import "./MixinResolver.sol";
import "./MixinSystemSettings.sol";
import "./ExternStateToken.sol";

import './interfaces/ICbbcToken.sol';
import './interfaces/ILiquidityToken.sol';
import './interfaces/ICharmToken.sol';
import './interfaces/IRouter.sol';
import './interfaces/IERC20.sol';
import './interfaces/IOrchestrator.sol';
import './interfaces/IWETH.sol';
import "./interfaces/IIssuerForCbbcToken.sol";
import "./interfaces/IIssuerForLiquidityToken.sol";
import "./interfaces/IIssuerForDividendToken.sol";

import './libraries/CbbcLibrary.sol';
import './libraries/TransferHelper.sol';

import "./interface/ISatoshiOpsition.sol";
import "./libraries/SafeToken.sol";


contract Router is IRouter, MixinSystemSettings, Owned{

    using SafeToken for address;

    bytes32 public constant CONTRACT_NAME = "Router";

    /* ========== ENCODED NAMES ========== */
    bytes32 internal constant CHARM = "CHARM";
    bytes32 internal constant ETH = "ETH";


    /* ========== ADDRESS RESOLVER CONFIGURATION ========== */
//    bytes32 private constant CONTRACT_CHARM_CHEF = "CharmChef";
    bytes32 private constant CONTRACT_ISSUER_FOR_LIQUIDITY_TOKEN = "IssuerForLiquidityToken";
    bytes32 private constant CONTRACT_ISSUER_FOR_CBBC_TOKEN = "IssuerForCbbcToken";
    bytes32 private constant CONTRACT_ISSUER_FOR_DIVIDEND_TOKEN = "IssuerForDividendToken";
//    bytes32 private constant CONTRACT_CHARM = "CharmToken";
//    bytes32 private constant CONTRACT_EXRATES = "ExchangeRates";
    bytes32 private constant CONTRACT_MARKET_ORACLE = "MarketOracle";
    bytes32 private constant CONTRACT_ORCHESTRATOR = "Orchestrator";

    /* ========== SatoshiOpstion ========== */
    bytes32 private constant CONTRACT_SATOSHIOPTIONS = "SatoshiOptions";

//// the address of the Cppc Chef contract, which convert the liquidity token to Cppc token


    constructor(address _owner, address _resolver) Owned(_owner) MixinSystemSettings(_resolver) {}

    receive() external payable {
        assert(msg.sender == address(weth())); // only accept ETH via fallback from the WETH contract
    }

    /* ========== VIEWS ========== */
    function resolverAddressesRequired() public view override returns (bytes32[] memory addresses) {
        bytes32[] memory existingAddresses = MixinSystemSettings.resolverAddressesRequired();
        bytes32[] memory newAddresses = new bytes32[](7);
        newAddresses[0] = CHARM;
        newAddresses[1] = ETH;
        newAddresses[2] = CONTRACT_ISSUER_FOR_LIQUIDITY_TOKEN;
        newAddresses[3] = CONTRACT_ISSUER_FOR_CBBC_TOKEN;
        newAddresses[4] = CONTRACT_ISSUER_FOR_DIVIDEND_TOKEN;
        newAddresses[5] = CONTRACT_MARKET_ORACLE;
        newAddresses[6] = CONTRACT_ORCHESTRATOR;
        return combineArrays(existingAddresses, newAddresses);
    }

    function charm() internal view returns (ICharmToken) {
        return ICharmToken(requireAndGetAddress(CHARM));
    }

    function weth() internal view returns (IWETH) {
        return IWETH(requireAndGetAddress(ETH));
    }

    function issuerForCbbcToken() internal view returns (IIssuerForCbbcToken) {
        return IIssuerForCbbcToken(requireAndGetAddress(CONTRACT_ISSUER_FOR_CBBC_TOKEN));
    }

    function issuerForLiquidityToken() internal view returns (IIssuerForLiquidityToken) {
        return IIssuerForLiquidityToken(requireAndGetAddress(CONTRACT_ISSUER_FOR_LIQUIDITY_TOKEN));
    }

    function issuerForDividendToken() internal view returns (IIssuerForDividendToken) {
        return IIssuerForDividendToken(requireAndGetAddress(CONTRACT_ISSUER_FOR_DIVIDEND_TOKEN));
    }

    function marketOracle() internal view returns (IMarketOracle) {
        return IMarketOracle(requireAndGetAddress(CONTRACT_MARKET_ORACLE));
    }

    function orchestrator() internal view returns (IOrchestrator) {
        return IOrchestrator(requireAndGetAddress(CONTRACT_ORCHESTRATOR));
    }

    function satoshiOptions() internal view returns (ISatoshiOptions) {
        return ISatoshiOptions(requireAndGetAddress(CONTRACT_SATOSHIOPTIONS));
    }

    

//       /*  MUTATIVE FUNCTIONS ========== */
    // *** Update oracle and rebase ***
    function _rebase(bytes32 cTokenKey) private {
        ICbbcToken cToken = issuerForCbbcToken().cTokens(cTokenKey);

        uint rebasePrice = cToken.rebasePrice();

        (uint currentPrice, ) = marketOracle().priceAndTimestamp(cToken.tradeTokenKey());

        if(rebasePrice + rebasePrice * getUpperRebaseThreshold() / uint(cToken.leverage()) / 10**18 < currentPrice ||
            rebasePrice - rebasePrice * getLowerRebaseThreshold() / uint(cToken.leverage()) / 10**18 > currentPrice)
        {
            orchestrator().rebase(cToken);
        }
    }
/*
    function rebase(
        signedPrice calldata signedPr,
        ICbbcToken cbbcToken
    ) external virtual override returns (bool){
        require(_checkIdentityAndUpdateOracle(cbbcToken.tradeToken(), signedPr), "CBBC: UPDATE_ORACLE_FAILED.");
        orchestrator.rebase(cbbcToken);
        return true;
    }
*/
    function rebase(
        IMarketOracle.signedPrice calldata signedPr,
        bytes32 tradeTokenKey,
        bytes32[] calldata cTokenKeys
    ) external virtual override returns (bool){

        uint256 numberOfCbbcs = cTokenKeys.length;

        require(numberOfCbbcs > 0, "CBBC: NONE_TO_REBASE.");

        require(marketOracle().updateOracle(tradeTokenKey, signedPr), "CBBC: UPDATE_ORACLE_FAILED.");

        for(uint256 i = 0; i < numberOfCbbcs; i++){
            bytes32 cTokenKey = cTokenKeys[i];

            ICbbcToken cToken = issuerForCbbcToken().cTokens(cTokenKey);

            require(cToken.tradeTokenKey() == tradeTokenKey, "CBBC: TRADE_TOKEN_MISMATCH.");

            orchestrator().rebase(cToken);
        }
        /*
        uint256 cbbcPrice;
        ICbbcToken cbbcToken;
        for(uint256 i = 0; i < numberOfCbbcs; i++){
            cbbcToken = cbbcTokens[i];
            cbbcPrice = getCbbcPrice(cbbcToken, 0, 0, ICbbcFactory.tradeDirection.buyCbbc);
            if(10**18 + rebaseThresholdInCbbcPrice < cbbcPrice ||
                10**18 - rebaseThresholdInCbbcPrice > cbbcPrice)
                {
                orchestrator.rebase(cbbcToken);
                }
        }
        */
        return true;
    }

    // **** ADD LIQUIDITY ****
    function addLiquidity(
        bytes32 settleTokenKey,
        uint amountDesired,
        address destAccount,
        uint deadline
    ) public virtual override ensure(deadline) returns (uint liquidity) {
        ILiquidityToken liquidityToken = issuerForLiquidityToken().lTokensForSettleToken(settleTokenKey);
        bytes32 lTokenKey = issuerForLiquidityToken().lTokensByAddress(address(liquidityToken));

        require(liquidityToken != ILiquidityToken(address(0)), "CBBC: LIQUIDITY_POOL_NOT_EXIST.");

        TransferHelper.safeTransferFrom(liquidityToken.settleTokenAddress(), msg.sender, address(liquidityToken), amountDesired);

        liquidity = issuerForLiquidityToken().mintLiquidityTokens(lTokenKey, destAccount, amountDesired);
    }

    function addLiquidityETH(
        address destAccount,
        uint deadline
    ) external virtual override payable ensure(deadline) returns (uint liquidity) {
        ILiquidityToken liquidityToken = issuerForLiquidityToken().lTokensForSettleToken(ETH);
        bytes32 lTokenKey = issuerForLiquidityToken().lTokensByAddress(address(liquidityToken));

        require(liquidityToken != ILiquidityToken(address(0)), "CBBC: LIQUIDITY_POOL_NOT_EXIST.");

        uint amountETH = msg.value;
        weth().deposit{value: amountETH}(); // wrapped ETH to WETH
        assert(weth().transfer(address(liquidityToken), amountETH));

        liquidity = issuerForLiquidityToken().mintLiquidityTokens(lTokenKey, destAccount, amountETH);
        // refund dust eth, if any
//        if (msg.value > amountETH) TransferHelper.safeTransferETH(msg.sender, msg.value - amountETH);
    }

    // **** REMOVE LIQUIDITY ****
    function removeLiquidity(
        bytes32 settleTokenKey,
        uint liquidity,
        uint amountMin,
        address destAccount, // where settleToken is going
        uint deadline
    ) public virtual override ensure(deadline) returns (uint amount) {
        ILiquidityToken liquidityToken = issuerForLiquidityToken().lTokensForSettleToken(settleTokenKey);
        bytes32 lTokenKey = issuerForLiquidityToken().lTokensByAddress(address(liquidityToken));


        IERC20(address(liquidityToken)).transferFrom(msg.sender, address(issuerForLiquidityToken()), liquidity);
        // send liquidity to issuerForLiquidityToken()

        amount = issuerForLiquidityToken().burnLiquidityTokens(lTokenKey,  destAccount, liquidity);

        require(amount >= amountMin, 'CBBC: INSUFFICIENT_SETTLEMENT_AMOUNT');
    }

    function removeLiquidityETH(
        uint liquidity,
        uint amountETHMin,
        address destAccount,
        uint deadline
    ) public virtual override ensure(deadline) returns (uint amountETH) {
        amountETH = removeLiquidity(
            ETH,
            liquidity,
            amountETHMin,
            address(this),
            deadline
        );
        weth().withdraw(amountETH);// transform WETH back to ETH

        TransferHelper.safeTransferETH(destAccount, amountETH);
    }


    function removeLiquidityWithPermit(
        bytes32 settleTokenKey,
        uint liquidity,
        uint amountMin,
        address destAccount, // where settleToken is going
        uint deadline,
        permitData calldata permitData_
    ) public virtual override returns (uint amount) {
        ILiquidityToken liquidityToken = issuerForLiquidityToken().lTokensForSettleToken(settleTokenKey);

        uint value = permitData_.approveMax ? type(uint).max : liquidity;

        IExternStateToken(address(liquidityToken)).permit(msg.sender, address(this), value, deadline, permitData_.v, permitData_.r, permitData_.s);

        amount = removeLiquidity(settleTokenKey, liquidity, amountMin, destAccount, deadline);
    }

    function removeLiquidityETHWithPermit(
        uint liquidity,
        uint amountETHMin,
        address destAccount,
        uint deadline,
        permitData calldata permitData_
    ) public virtual override returns (uint amountETH) {
        ILiquidityToken liquidityToken = issuerForLiquidityToken().lTokensForSettleToken(ETH);

        uint value = permitData_.approveMax ? type(uint).max : liquidity;

        IExternStateToken(address(liquidityToken)).permit(msg.sender, address(this), value, deadline, permitData_.v, permitData_.r, permitData_.s);

        amountETH = removeLiquidityETH(liquidity, amountETHMin, destAccount, deadline);
    }



    // **** Mint DividendToken ****
    function buyDividendToken(
        bytes32 settleTokenKey,
        uint amountDesired,
        address destAccount,
        uint deadline
    ) public virtual override ensure(deadline) returns (uint dividend) {
        IDividendToken dividendToken = issuerForDividendToken().dTokensForSettleToken(settleTokenKey);
        bytes32 dTokenKey = issuerForDividendToken().dTokensByAddress(address(dividendToken));

        require(dividendToken != IDividendToken(address(0)), "CBBC: DIVIDEND_TOKEN_NOT_EXIST.");

        IERC20(address(charm())).transferFrom(msg.sender, address(issuerForDividendToken()), amountDesired);

        dividend = issuerForDividendToken().mintDividendTokens(dTokenKey, destAccount, amountDesired);
    }

    function buyDividendTokenWithPermit(
        bytes32 settleTokenKey,
        uint amountDesired,
        address destAccount,
        uint deadline,
        permitData calldata permitData_
    ) public virtual override ensure(deadline) returns (uint dividend) {
        uint value = permitData_.approveMax ? type(uint).max : amountDesired;

        IExternStateToken(address(charm())).permit(msg.sender, address(this), value, deadline, permitData_.v, permitData_.r, permitData_.s);

        dividend = buyDividendToken(settleTokenKey, amountDesired, destAccount, deadline);
    }


    // **** Burn DividendToken ****
    function sellDividendToken(
        bytes32 settleTokenKey,
        uint dividend,
        uint amountMin,
        address to,
        uint deadline
    ) public virtual override ensure(deadline) returns (uint amount) {
        IDividendToken dividendToken = issuerForDividendToken().dTokensForSettleToken(settleTokenKey);
        bytes32 dTokenKey = issuerForDividendToken().dTokensByAddress(address(dividendToken));

        IERC20(address(dividendToken)).transferFrom(msg.sender, address(issuerForDividendToken()), dividend);

        // send liquidity to pair
        amount = issuerForDividendToken().burnDividendTokens(dTokenKey, to, dividend);

        require(amount >= amountMin, 'CBBC: INSUFFICIENT_SETTLEMENT_AMOUNT');
    }

    function sellDividendTokenETH(
        uint dividend,
        uint amountETHMin,
        address to,
        uint deadline
    ) public virtual override ensure(deadline) returns (uint amountETH) {
        amountETH = sellDividendToken(
            ETH,
            dividend,
            amountETHMin,
            address(this),
            deadline
        );
        weth().withdraw(amountETH);// transform WETH back to ETH

        TransferHelper.safeTransferETH(to, amountETH);
    }

    function sellDividendTokenWithPermit(
        bytes32 settleTokenKey,
        uint dividend,
        uint amountMin,
        address to,
        uint deadline,
        permitData calldata permitData_
    ) public virtual override ensure(deadline) returns (uint amount) {
        IDividendToken dividendToken = issuerForDividendToken().dTokensForSettleToken(settleTokenKey);

        uint value = permitData_.approveMax ? type(uint).max : dividend;

        IExternStateToken(address(dividendToken)).permit(msg.sender, address(this), value, deadline, permitData_.v, permitData_.r, permitData_.s);

        // send liquidity to pair
        amount = sellDividendToken(settleTokenKey, dividend, amountMin, to, deadline);
    }

    function sellDividendTokenETHWithPermit(
        uint dividend,
        uint amountETHMin,
        address to,
        uint deadline,
        permitData calldata permitData_
    ) public virtual override ensure(deadline) returns (uint amountETH) {
        IDividendToken dividendToken = issuerForDividendToken().dTokensForSettleToken(ETH);

        uint value = permitData_.approveMax ? type(uint).max : dividend;

        IExternStateToken(address(dividendToken)).permit(msg.sender, address(this), value, deadline, permitData_.v, permitData_.r, permitData_.s);

        // send liquidity to pair
        amountETH = sellDividendTokenETH(dividend, amountETHMin, to, deadline);
    }

    // **** MINT CBBC ****
    /*
    function buyCbbc(
        address settleToken,
        address tradeToken,
        uint8 leverage,
        ICbbcToken.CbbcType cbbcType,
        uint amountDesired,
        address to,
        uint deadline
    ) external virtual override onlyDirectCall ensure(deadline) returns (uint cbbcAmount) {
        address cbbcToken = factory.getCbbc(settleToken, tradeToken, leverage, cbbcType);
        require(cbbcToken != address(0), "CBBC: NOT_CREATED.");

        address liquidityToken = factory.getLiquidityToken(settleToken);
        TransferHelper.safeTransferFrom(settleToken, msg.sender, liquidityToken, amountDesired);
        cbbcAmount = ICbbcToken(cbbcToken).mintCbbc(to, amountDesired);
    }
    */
    function buyCbbc(
        IMarketOracle.signedPrice calldata signedPr,
        bytes32 settleTokenKey,
        bytes32 tradeTokenKey,
        uint8 leverage,
        ICbbcToken.CbbcType cbbcType,
        uint amountDesired,
        address to,
        uint deadline
    ) public virtual override ensure(deadline) returns (uint cbbcAmount) {
        ICbbcToken cToken = issuerForCbbcToken().getCTokens(settleTokenKey, tradeTokenKey, leverage, cbbcType);

        require(cToken != ICbbcToken(address(0)), "CBBC: NOT_CREATED.");

        ILiquidityToken liquidityToken = issuerForLiquidityToken().lTokensForSettleToken(settleTokenKey);

        require(marketOracle().updateOracle(tradeTokenKey, signedPr), "CBBC: UPDATE_ORACLE_FAILED.");

        bytes32 cTokenKey = issuerForCbbcToken().cTokensByAddress(address(cToken));

        _rebase(cTokenKey);

        TransferHelper.safeTransferFrom(liquidityToken.settleTokenAddress(), msg.sender, address(liquidityToken), amountDesired);

        cbbcAmount = issuerForCbbcToken().mintCbbc(cTokenKey, to, amountDesired);
    }

    function buyCbbcUsingLiquidityToken(
        IMarketOracle.signedPrice calldata signedPr,
        bytes32 settleTokenKey,
        bytes32 tradeTokenKey,
        uint8 leverage,
        ICbbcToken.CbbcType cbbcType,
        uint amountDesired,
        address to,
        uint deadline
    ) public virtual override ensure(deadline) returns (uint cbbcAmount) {
        ICbbcToken cToken = issuerForCbbcToken().getCTokens(settleTokenKey, tradeTokenKey, leverage, cbbcType);

        require(cToken != ICbbcToken(address(0)), "CBBC: NOT_CREATED.");

        ILiquidityToken liquidityToken = issuerForLiquidityToken().lTokensForSettleToken(settleTokenKey);

        require(marketOracle().updateOracle(tradeTokenKey, signedPr), "CBBC: UPDATE_ORACLE_FAILED.");

        bytes32 cTokenKey = issuerForCbbcToken().cTokensByAddress(address(cToken));

        _rebase(cTokenKey);

        if(settleTokenKey == CHARM){
            IERC20(address(charm())).transferFrom(msg.sender, address(this), amountDesired);
            charm().burn(address(this), amountDesired);
        } else {
            IERC20(address(liquidityToken)).transferFrom(msg.sender, address(this), amountDesired);
            liquidityToken.burn(address(this), amountDesired);
        }
        cbbcAmount = issuerForCbbcToken().mintCbbc(cTokenKey, to, amountDesired);
    }

    function buyCbbcUsingLiquidityTokenWithPermit(
        IMarketOracle.signedPrice calldata signedPr,
        bytes32 settleTokenKey,
        bytes32 tradeTokenKey,
        uint8 leverage,
        ICbbcToken.CbbcType cbbcType,
        uint amountDesired,
        address to,
        uint deadline,
        permitData calldata permitData_
    ) public virtual override ensure(deadline) returns (uint cbbcAmount) {
        uint value = permitData_.approveMax ? type(uint).max : amountDesired;

        if(settleTokenKey == CHARM){
            IExternStateToken(address(charm())).permit(msg.sender, address(this), value, deadline, permitData_.v, permitData_.r, permitData_.s);
        } else {
            ILiquidityToken liquidityToken = issuerForLiquidityToken().lTokensForSettleToken(settleTokenKey);

            IExternStateToken(address(liquidityToken)).permit(msg.sender, address(this), value, deadline, permitData_.v, permitData_.r, permitData_.s);
    }
        cbbcAmount = buyCbbcUsingLiquidityToken(signedPr, settleTokenKey, tradeTokenKey, leverage, cbbcType, amountDesired, to, deadline);
    }
/*
    function buyCbbcETH(
        address tradeToken,
        uint8 leverage,
        ICbbcToken.CbbcType cbbcType,
        address to,
        uint deadline
    ) external virtual override payable onlyDirectCall ensure(deadline) returns (uint cbbcAmount) {
        address tempAddress = factory.getCbbc(WETH, tradeToken, leverage, cbbcType);
        require(tempAddress != address(0), "CBBC: NOT_CREATED.");

        address liquidityToken = factory.getLiquidityToken(WETH);
        address cbbcToken = tempAddress;
        uint amountETH = msg.value;
        IWETH(WETH).deposit{value: amountETH}(); // wrapped ETH to WETH
        assert(IWETH(WETH).transfer(liquidityToken, amountETH));
        cbbcAmount = ICbbcToken(cbbcToken).mintCbbc(to, amountETH);
        // refund dust eth, if any
        //if (msg.value > amountETH) TransferHelper.safeTransferETH(msg.sender, msg.value - amountETH);
    }
*/
function buyCbbcETH(
        IMarketOracle.signedPrice calldata signedPr,
        bytes32 tradeTokenKey,
        uint8 leverage,
        ICbbcToken.CbbcType cbbcType,
        address to,
        uint deadline
    ) external virtual override payable ensure(deadline) returns (uint cbbcAmount) {
        ICbbcToken cToken = issuerForCbbcToken().getCTokens(ETH, tradeTokenKey, leverage, cbbcType);
        require(cToken != ICbbcToken(address(0)), "CBBC: NOT_CREATED.");

        ILiquidityToken liquidityToken = issuerForLiquidityToken().lTokensForSettleToken(ETH);

        require(marketOracle().updateOracle(tradeTokenKey, signedPr), "CBBC: UPDATE_ORACLE_FAILED.");

        bytes32 cTokenKey = issuerForCbbcToken().cTokensByAddress(address(cToken));

        _rebase(cTokenKey);

        uint amountETH = msg.value;
        weth().deposit{value: amountETH}(); // wrapped ETH to WETH
        assert(weth().transfer(address(liquidityToken), amountETH));

        cbbcAmount = issuerForCbbcToken().mintCbbc(cTokenKey, to, amountETH);
        // refund dust eth, if any
//        if (msg.value > amountETH) TransferHelper.safeTransferETH(msg.sender, msg.value - amountETH);
    }


    // **** SELL CBBC ****
/*
    function sellCbbc(
        address settleToken,
        address tradeToken,
        uint8 leverage,
        ICbbcToken.CbbcType cbbcType,
        uint cbbcAmount,
        uint amountMin,
        address to,
        uint deadline
    ) public virtual override onlyDirectCall ensure(deadline) returns (uint settleAmount) {
        address cbbcToken = factory.getCbbc(settleToken, tradeToken, leverage, cbbcType);
        IERC20(cbbcToken).transferFrom(msg.sender, cbbcToken, cbbcAmount);
        settleAmount = ICbbcToken(cbbcToken).burnCbbc(to, cbbcAmount);

//        address liquidityToken = factory.getLiquidityToken(settleToken);
//        TransferHelper.safeTransferFrom(settleToken, liquidityToken, to, settleAmount);
        require(settleAmount >= amountMin, 'CbbcRouter: INSUFFICIENT_SETTLEMENT_AMOUNT_OUT');
    }
    */
    function sellCbbc(
        IMarketOracle.signedPrice calldata signedPr,
        bytes32 settleTokenKey,
        bytes32 tradeTokenKey,
        uint8 leverage,
        ICbbcToken.CbbcType cbbcType,
        uint cbbcAmount,
        uint amountMin,
        address to,
        uint deadline
    ) public virtual override ensure(deadline) returns (uint settleAmount){
        ICbbcToken cToken = issuerForCbbcToken().getCTokens(settleTokenKey, tradeTokenKey, leverage, cbbcType);

        require(marketOracle().updateOracle(tradeTokenKey, signedPr), "CBBC: UPDATE_ORACLE_FAILED.");

        IERC20(address(cToken)).transferFrom(msg.sender, address(issuerForCbbcToken()), cbbcAmount);

        bytes32 cTokenKey = issuerForCbbcToken().cTokensByAddress(address(cToken));

        settleAmount = issuerForCbbcToken().burnCbbc(cTokenKey, to, cbbcAmount);
//        address liquidityToken = factory.getLiquidityToken(settleToken);
//        TransferHelper.safeTransferFrom(settleToken, liquidityToken, to, settleAmount);
        require(settleAmount >= amountMin, 'CbbcRouter: INSUFFICIENT_SETTLEMENT_AMOUNT_OUT');
        //rebase
        _rebase(cTokenKey);
    }
/*
    function sellCbbcETH(
        address tradeToken,
        uint8 leverage,
        ICbbcToken.CbbcType cbbcType,
        uint cbbcAmount,
        uint amountETHMin,
        address to,
        uint deadline
    ) public virtual override onlyDirectCall ensure(deadline) returns (uint amountETH) {
        amountETH = sellCbbc(
            WETH,
            tradeToken,
            leverage,
            cbbcType,
            cbbcAmount,
            amountETHMin,
            address(this),
            deadline
        );
        IWETH(WETH).withdraw(amountETH);// transform WETH back to WTH
        TransferHelper.safeTransferETH(to, amountETH);
    }
    */
    function sellCbbcETH(
        IMarketOracle.signedPrice calldata signedPr,
        bytes32 tradeToken,
        uint8 leverage,
        ICbbcToken.CbbcType cbbcType,
        uint cbbcAmount,
        uint amountETHMin,
        address to,
        uint deadline
    ) public virtual override ensure(deadline) returns (uint amountETH) {
        amountETH = sellCbbc(
            signedPr,
            ETH,
            tradeToken,
            leverage,
            cbbcType,
            cbbcAmount,
            amountETHMin,
            address(this),
            deadline
        );
        weth().withdraw(amountETH);// transform WETH back to WTH
        TransferHelper.safeTransferETH(to, amountETH);
    }
/*
    function sellCbbcWithPermit(
        address settleToken,
        address tradeToken,
        uint8 leverage,
        ICbbcToken.CbbcType cbbcType,
        uint cbbcAmount,
        uint amountMin,
        address to,
        uint deadline,
        permitData calldata permitData_
    ) external virtual override returns (uint amount) {
        {
        address cbbcToken = factory.getCbbc(settleToken, tradeToken, leverage, cbbcType);
        uint value = permitData_.approveMax ? type(uint).max : cbbcAmount;
        CbbcERC20(cbbcToken).permit(msg.sender, address(this), value, deadline, permitData_.v, permitData_.r, permitData_.s);
        }
        amount = sellCbbc(settleToken, tradeToken, leverage, cbbcType, cbbcAmount, amountMin, to, deadline);
    }
    */

    function sellCbbcWithPermit(
        IMarketOracle.signedPrice calldata signedPr,
        bytes32 settleTokenKey,
        bytes32 tradeTokenKey,
        uint8 leverage,
        ICbbcToken.CbbcType cbbcType,
        uint cbbcAmount,
        uint amountMin,
        address to,
        uint deadline,
        permitData calldata permitData_
    ) external virtual override returns (uint amount) {
        ICbbcToken cToken = issuerForCbbcToken().getCTokens(settleTokenKey, tradeTokenKey, leverage, cbbcType);

        uint value = permitData_.approveMax ? type(uint).max : cbbcAmount;

        IExternStateToken(address(cToken)).permit(msg.sender, address(this), value, deadline, permitData_.v, permitData_.r, permitData_.s);

        amount = sellCbbc(signedPr,
                        settleTokenKey,
                        tradeTokenKey,
                        leverage,
                        cbbcType,
                        cbbcAmount,
                        amountMin,
                        to,
                        deadline);
    }
/*
    function sellCbbcETHWithPermit(
        address tradeToken,
        uint8 leverage,
        ICbbcToken.CbbcType cbbcType,
        uint cbbcAmount,
        uint amountETHMin,
        address to,
        uint deadline,
        permitData calldata permitData_
    ) external virtual override returns (uint amountETH) {
        address cbbcToken = factory.getCbbc(WETH, tradeToken, leverage, cbbcType);
        uint value = permitData_.approveMax ? type(uint).max : cbbcAmount;
        CbbcERC20(cbbcToken).permit(msg.sender, address(this), value, deadline, permitData_.v, permitData_.r, permitData_.s);
        amountETH = sellCbbcETH(
            tradeToken,
            leverage,
            cbbcType,
            cbbcAmount,
            amountETHMin,
            to,
            deadline
        );
    }
*/

    function sellCbbcETHWithPermit(
        IMarketOracle.signedPrice calldata signedPr,
        bytes32 tradeTokenKey,
        uint8 leverage,
        ICbbcToken.CbbcType cbbcType,
        uint cbbcAmount,
        uint amountETHMin,
        address to,
        uint deadline,
        permitData calldata permitData_
    ) external virtual override returns (uint amountETH) {
        ICbbcToken cToken = issuerForCbbcToken().getCTokens(ETH, tradeTokenKey, leverage, cbbcType);

        uint value = permitData_.approveMax ? type(uint).max : cbbcAmount;

        IExternStateToken(address(cToken)).permit(msg.sender, address(this), value, deadline, permitData_.v, permitData_.r, permitData_.s);

        amountETH = sellCbbcETH(
            signedPr,
            tradeTokenKey,
            leverage,
            cbbcType,
            cbbcAmount,
            amountETHMin,
            to,
            deadline
        );
    }

    // **** LIBRARY FUNCTIONS ****

    function computeCbbcPrice(
        CbbcLibrary.priceData memory priceData_,
        CbbcLibrary.cbbcTokenData memory cbbcTokenData_,
        CbbcLibrary.marketData memory marketData_,
        uint priceImpact,
        ICbbcToken.tradeDirection direction)
        external override pure returns (uint cbbcPrice){
        return CbbcLibrary._computeCbbcPrice(priceData_, cbbcTokenData_, marketData_, priceImpact, direction);
    }
/*
    function getCbbcPrice(
        ICbbcToken cbbcToken,
        uint settleAmount,
        uint cbbcAmount,
        ICbbcFactory.tradeDirection direction)
        public override view returns (uint) {
        return CbbcLibrary.getCbbcPrice(cbbcToken, settleAmount, cbbcAmount, direction);
    }

    function adjustLiability(
        uint totalLiabilities,
        uint balance)
        external override pure returns(uint){
        return CbbcLibrary.adjustLiability(totalLiabilities, balance);
    }

    function getCbbcAmount(
        ICbbcToken cbbcToken,
        uint settleAmount)
        external override view returns (uint cbbcAmount){
        return CbbcLibrary.getCbbcAmount(cbbcToken, settleAmount);
    }

    function getSettleAmount(
        ICbbcToken cbbcToken,
        uint cbbcAmount)
        external override view returns (uint settleAmount) {
        return CbbcLibrary.getSettleAmount(cbbcToken, cbbcAmount);
        }
*/

    function buyOptions(
        bool direction,
        uint128 _delta,
        uint128 _bk,
        uint128 _cppcNum,
        address _strategy,
        ISatoshiOptions.SignedPriceInput calldata signedPr
    ) external payable returns(uint256 pid){
        _deposit(signedPr.tradeToken, msg.sender, _cppcNum);
        pid = satoshiOptions().mintTo(
            msg.sender,
            direction,
            _delta,
            _bk,
            _cppcNum,
            _strategy,
            signedPr
        );
    }

    function sellOptions(
        uint256 _pid,
        uint128 _cAmount,
        ISatoshiOptions.SignedPriceInput calldata signedPr
    ) external returns(uint256 liquidationNum) {

        liquidationNum = satoshiOptions().burnFor(
            msg.sender,
            _pid,
            _cAmount,
            signedPr
        );
        
        uint256 balance = _containersBalance();
        if ( liquidationNum > balance ) {
            _withdraw(signedPr.tradeToken, msg.sender, balance);
            liquidationNum -= balance;
        }
        _mintLiquidityToken(token, msg.sender, liquidationNum);
    }
    function _mintLiquidityToken(
        address token,
        address destAccount,
        uint256 amount
    ) external {}


    function _containersBalance() internal view returns(uint256) {
        return address(issuerForLiquidityToken()).myBalance();
    }

    function _deposit(address token, address _from, uint256 amount) payable internal {
        address containers = address(issuerForLiquidityToken());
        if ( token == address(0) ) {
            amount = msg.value;
            weth().deposit{value: amount}();
            weth().safeTransfer(containers,amount);
        } else {
            token.safeTransferFrom(_from, containers, amount);
        }
    }

    function _withdraw(address token, address _to, uint256 amount) internal {
        if ( token == address(0) ) {
            weth().withdraw(amount);
            SafeToken.safeTransferETH(_to, amount);
        } else {
            token.safeTransfer(_to, amount);
        }
    }

    /* ==========  MODIFIERS   =========== */
    modifier ensure(uint deadline) {
        require(deadline >= block.timestamp, 'CBBC::Router: EXPIRED');
        _;
    }
}