pragma solidity =0.8.3;

import './ICbbcToken.sol';
import './IMarketOracle.sol';
import './IOrchestrator.sol';
import '../libraries/CbbcLibrary.sol';

interface IRouter{
    struct permitData{
        bool approveMax;
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

/*
    function rebase(
        signedPrice calldata signedPr,
        ICbbcToken cbbcToken
    ) external returns (bool);
*/
    function rebase(
        IMarketOracle.signedPrice calldata signedPr,
        bytes32 tradeTokenKey,
        bytes32[] calldata cTokenKeys
    ) external returns (bool);

    function addLiquidity(
        bytes32 settleTokenKey,
        uint amountDesired,
        address to,
        uint deadline
    ) external returns (uint liquidity);

    function addLiquidityETH(
        address to,
        uint deadline
    ) external payable returns (uint liquidity) ;

    // **** REMOVE LIQUIDITY ****
    function removeLiquidity(
        bytes32 settleTokenKey,
        uint liquidity,
        uint amountMin,
        address destAccount,
        uint deadline
    ) external returns (uint amount);

    function removeLiquidityETH(
        uint liquidity,
        uint amountETHMin,
        address destAccount,
        uint deadline
    ) external returns (uint amountETH);

    function removeLiquidityWithPermit(
        bytes32 settleTokenKey,
        uint liquidity,
        uint amountMin,
        address destAccount, // where settleToken is going
        uint deadline,
        permitData calldata permitData_
    ) external returns (uint amount);

    function removeLiquidityETHWithPermit(
        uint liquidity,
        uint amountETHMin,
        address destAccount,
        uint deadline,
        permitData calldata permitData_
    ) external returns (uint amountETH);


    // **** Mint DividendToken ****
    function buyDividendToken(
        bytes32 settleTokenKey,
        uint amountDesired,
        address to,
        uint deadline
    ) external returns (uint dividend);

    function buyDividendTokenWithPermit(
        bytes32 settleTokenKey,
        uint amountDesired,
        address destAccount,
        uint deadline,
        permitData calldata permitData_
    ) external returns (uint dividend);

    // **** Burn DividendToken ****
    function sellDividendToken(
        bytes32 settleTokenKey,
        uint liquidity,
        uint amountMin,
        address to,
        uint deadline
    ) external returns (uint amount);

    function sellDividendTokenETH(
        uint liquidity,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountETH);


    function sellDividendTokenWithPermit(
        bytes32 settleTokenKey,
        uint dividend,
        uint amountMin,
        address to,
        uint deadline,
        permitData calldata permitData_
    ) external returns (uint amount);

    function sellDividendTokenETHWithPermit(
        uint dividend,
        uint amountETHMin,
        address to,
        uint deadline,
        permitData calldata permitData_
    ) external returns (uint amountETH);

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
    ) external returns (uint cbbcAmount);*/
    function buyCbbc(
        IMarketOracle.signedPrice calldata signedPr,
        bytes32 settleTokenKey,
        bytes32 tradeTokenKey,
        uint8 leverage,
        ICbbcToken.CbbcType cbbcType,
        uint amountDesired,
        address to,
        uint deadline
    ) external returns (uint cbbcAmount);

    function buyCbbcUsingLiquidityToken(
        IMarketOracle.signedPrice calldata signedPr,
        bytes32 settleTokenKey,
        bytes32 tradeTokenKey,
        uint8 leverage,
        ICbbcToken.CbbcType cbbcType,
        uint amountDesired,
        address to,
        uint deadline
    ) external returns (uint cbbcAmount);

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
    ) external returns (uint cbbcAmount);
/*
    function buyCbbcETH(
        address tradeToken,
        uint8 leverage,
        ICbbcToken.CbbcType cbbcType,
        address to,
        uint deadline
    ) external payable returns (uint cbbcAmount);*/
    function buyCbbcETH(
        IMarketOracle.signedPrice calldata signedPr,
        bytes32 tradeToken,
        uint8 leverage,
        ICbbcToken.CbbcType cbbcType,
        address to,
        uint deadline
    ) external payable returns (uint cbbcAmount);


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
    ) external returns (uint settleAmount);*/
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
    ) external returns (uint settleAmount);
/*
    function sellCbbcETH(
        address tradeToken,
        uint8 leverage,
        ICbbcToken.CbbcType cbbcType,
        uint cbbcAmount,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountETH);*/
    function sellCbbcETH(
        IMarketOracle.signedPrice calldata signedPr,
        bytes32 tradeToken,
        uint8 leverage,
        ICbbcToken.CbbcType cbbcType,
        uint cbbcAmount,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountETH);
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
    ) external returns (uint amount);*/

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
    ) external returns (uint amount);

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
    ) external returns (uint amountETH);

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
    ) external returns (uint amountETH);
*/

//    function uintToString(uint v) external pure returns (string memory str);

    function computeCbbcPrice(
        CbbcLibrary.priceData memory priceData_,
        CbbcLibrary.cbbcTokenData memory cbbcTokenData_,
        CbbcLibrary.marketData memory marketData_,
        uint priceImpact,
        ICbbcToken.tradeDirection direction)
        external pure returns (uint cbbcPrice);
/*
    function getCbbcPrice(
        ICbbcToken cbbcToken,
        uint settleAmount,
        uint cbbcAmount,
        ICbbcFactory.tradeDirection direction)
        external view returns (uint);

    function adjustLiability(
        uint totalLiabilities,
        uint balance)
        external pure returns(uint);

   function getCbbcAmount(
        ICbbcToken cbbcToken,
        uint settleAmount)
        external view returns (uint cbbcAmount);

    function getSettleAmount(
        ICbbcToken cbbcToken,
        uint cbbcAmount)
        external view returns (uint settleAmount);
*/
}