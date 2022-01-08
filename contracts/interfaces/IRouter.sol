pragma solidity =0.8.3;

import "./IMarketOracle.sol";
import "./IIssuerForSatoshiOptions.sol";

interface IRouter {
    struct permitData {
        bool approveMax;
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    function addLiquidity(
        bytes32 settleTokenKey,
        uint256 amountDesired,
        address to,
        uint256 deadline
    ) external returns (uint256 liquidity);

    function addLiquidityETH(address to, uint256 deadline)
        external
        payable
        returns (uint256 liquidity);

    // **** REMOVE LIQUIDITY ****
    // function removeLiquidity(
    //     bytes32 settleTokenKey,
    //     uint256 liquidity,
    //     uint256 amountMin,
    //     address destAccount,
    //     uint256 deadline
    // ) external returns (uint256 amount);

    // function removeLiquidityETH(
    //     uint256 liquidity,
    //     uint256 amountETHMin,
    //     address destAccount,
    //     uint256 deadline
    // ) external returns (uint256 amountETH);

    // function removeLiquidityWithPermit(
    //     bytes32 settleTokenKey,
    //     uint256 liquidity,
    //     uint256 amountMin,
    //     address destAccount, // where settleToken is going
    //     uint256 deadline,
    //     permitData calldata permitData_
    // ) external returns (uint256 amount);

    // function removeLiquidityETHWithPermit(
    //     uint256 liquidity,
    //     uint256 amountETHMin,
    //     address destAccount,
    //     uint256 deadline,
    //     permitData calldata permitData_
    // ) external returns (uint256 amountETH);

    // **** Mint DividendToken ****
    // function buyDividendToken(
    //     bytes32 settleTokenKey,
    //     uint256 amountDesired,
    //     address to,
    //     uint256 deadline
    // ) external returns (uint256 dividend);

    // function buyDividendTokenWithPermit(
    //     bytes32 settleTokenKey,
    //     uint256 amountDesired,
    //     address destAccount,
    //     uint256 deadline,
    //     permitData calldata permitData_
    // ) external returns (uint256 dividend);

    // **** Burn DividendToken ****
    // function sellDividendToken(
    //     bytes32 settleTokenKey,
    //     uint256 liquidity,
    //     uint256 amountMin,
    //     address to,
    //     uint256 deadline
    // ) external returns (uint256 amount);

    // function sellDividendTokenETH(
    //     uint256 liquidity,
    //     uint256 amountETHMin,
    //     address to,
    //     uint256 deadline
    // ) external returns (uint256 amountETH);

    // function sellDividendTokenWithPermit(
    //     bytes32 settleTokenKey,
    //     uint256 dividend,
    //     uint256 amountMin,
    //     address to,
    //     uint256 deadline,
    //     permitData calldata permitData_
    // ) external returns (uint256 amount);

    // function sellDividendTokenETHWithPermit(
    //     uint256 dividend,
    //     uint256 amountETHMin,
    //     address to,
    //     uint256 deadline,
    //     permitData calldata permitData_
    // ) external returns (uint256 amountETH);

    // **** MINT Options ****
    function buyOptions(
        bool direction,
        uint128 _delta,
        uint128 _bk,
        uint128 _cppcNum,
        address _strategy,
        IIssuerForSatoshiOptions.SignedPriceInput calldata signedPr
    ) external payable returns (uint256 pid);

    // **** SELL CBBC ****
    function sellOptions(
        uint256 _pid,
        uint128 _cAmount,
        IIssuerForSatoshiOptions.SignedPriceInput calldata signedPr
    ) external returns (uint256 liquidationNum);
}
