pragma solidity ^0.8.3;

import "./cbbc_related/Owned.sol";
//import "./MixinResolver.sol";
<<<<<<< HEAD
import "./cbbc_related/MixinSystemSettings.sol";
import "./cbbc_related/ExternStateToken.sol";

import './cbbc_related/interfaces/ICbbcToken.sol';
import './cbbc_related/interfaces/ILiquidityToken.sol';
import './cbbc_related/interfaces/ICharmToken.sol';
import './cbbc_related/interfaces/IRouter.sol';
import './cbbc_related/interfaces/IERC20.sol';
import './cbbc_related/interfaces/IOrchestrator.sol';
import './cbbc_related/interfaces/IWETH.sol';
import "./cbbc_related/interfaces/IIssuerForCbbcToken.sol";
import "./cbbc_related/interfaces/IIssuerForLiquidityToken.sol";
import "./cbbc_related/interfaces/IIssuerForDividendToken.sol";

import './cbbc_related/libraries/CbbcLibrary.sol';
import './cbbc_related/libraries/TransferHelper.sol';

import './interface/ISatoshiOptions.sol';
import "./libraries/SafeToken.sol";
=======
import "./MixinSystemSettings.sol";
import "./ExternStateToken.sol";

import "./interfaces/ILiquidityToken.sol";
import "./interfaces/ICharmToken.sol";
import "./interfaces/IRouter.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/IWETH.sol";
import "./interfaces/IIssuerForLiquidityToken.sol";
import "./interfaces/IIssuerForDividendToken.sol";

import "./libraries/TransferHelper.sol";
>>>>>>> 18986cea25fe863d8ecbada398dbc51eec1aeacd

import "./interfaces/IIssuerForSatoshiOptions.sol";

import "./libraries/SafeToken.sol";

contract Router is IRouter, MixinSystemSettings, Owned {
    using SafeToken for address;

    bytes32 public constant CONTRACT_NAME = "Router";

    /* ========== ENCODED NAMES ========== */
    bytes32 internal constant CHARM = "CHARM";
    bytes32 internal constant ETH = "ETH";

    /* ========== ADDRESS RESOLVER CONFIGURATION ========== */
    //    bytes32 private constant CONTRACT_CHARM_CHEF = "CharmChef";
    bytes32 private constant CONTRACT_ISSUER_FOR_LIQUIDITY_TOKEN =
        "IssuerForLiquidityToken";
    bytes32 private constant CONTRACT_ISSUER_FOR_CBBC_TOKEN =
        "IssuerForCbbcToken";
    bytes32 private constant CONTRACT_ISSUER_FOR_DIVIDEND_TOKEN =
        "IssuerForDividendToken";
    //    bytes32 private constant CONTRACT_CHARM = "CharmToken";
    //    bytes32 private constant CONTRACT_EXRATES = "ExchangeRates";
    bytes32 private constant CONTRACT_MARKET_ORACLE = "MarketOracle";
    bytes32 private constant CONTRACT_ORCHESTRATOR = "Orchestrator";

    /* ========== SatoshiOpstion ========== */
    bytes32 private constant CONTRACT_SATOSHIOPTIONS = "SatoshiOptions";

    //// the address of the Cppc Chef contract, which convert the liquidity token to Cppc token

    constructor(address _owner, address _resolver)
        Owned(_owner)
        MixinSystemSettings(_resolver)
    {}

    receive() external payable {
        assert(msg.sender == address(weth())); // only accept ETH via fallback from the WETH contract
    }

    /* ========== VIEWS ========== */
    function resolverAddressesRequired()
        public
        view
        override
        returns (bytes32[] memory addresses)
    {
        bytes32[] memory existingAddresses = MixinSystemSettings
            .resolverAddressesRequired();
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

    // function issuerForCbbcToken() internal view returns (IIssuerForCbbcToken) {
    //     return
    //         IIssuerForCbbcToken(
    //             requireAndGetAddress(CONTRACT_ISSUER_FOR_CBBC_TOKEN)
    //         );
    // }

    function issuerForLiquidityToken()
        internal
        view
        returns (IIssuerForLiquidityToken)
    {
        return
            IIssuerForLiquidityToken(
                requireAndGetAddress(CONTRACT_ISSUER_FOR_LIQUIDITY_TOKEN)
            );
    }

    function issuerForDividendToken()
        internal
        view
        returns (IIssuerForDividendToken)
    {
        return
            IIssuerForDividendToken(
                requireAndGetAddress(CONTRACT_ISSUER_FOR_DIVIDEND_TOKEN)
            );
    }

    function marketOracle() internal view returns (IMarketOracle) {
        return IMarketOracle(requireAndGetAddress(CONTRACT_MARKET_ORACLE));
    }

    // function orchestrator() internal view returns (IOrchestrator) {
    //     return IOrchestrator(requireAndGetAddress(CONTRACT_ORCHESTRATOR));
    // }

<<<<<<< HEAD
    function satoshiOptions() internal view returns (ISatoshiOptions) {
        return ISatoshiOptions(requireAndGetAddress(CONTRACT_SATOSHIOPTIONS));
=======
    function satoshiOptions() internal view returns (IIssuerForSatoshiOptions) {
        return
            IIssuerForSatoshiOptions(
                requireAndGetAddress(CONTRACT_SATOSHIOPTIONS)
            );
>>>>>>> 18986cea25fe863d8ecbada398dbc51eec1aeacd
    }

    // **** ADD LIQUIDITY ****
    function addLiquidity(
        bytes32 settleTokenKey,
        uint256 amountDesired,
        address destAccount,
        uint256 deadline
    ) public virtual override ensure(deadline) returns (uint256 liquidity) {
        ILiquidityToken liquidityToken = issuerForLiquidityToken()
            .lTokensForSettleToken(settleTokenKey);
        bytes32 lTokenKey = issuerForLiquidityToken().lTokensByAddress(
            address(liquidityToken)
        );

        require(
            liquidityToken != ILiquidityToken(address(0)),
            "CBBC: LIQUIDITY_POOL_NOT_EXIST."
        );

        TransferHelper.safeTransferFrom(
            liquidityToken.settleTokenAddress(),
            msg.sender,
            address(liquidityToken),
            amountDesired
        );

        liquidity = issuerForLiquidityToken().mintLiquidityTokens(
            lTokenKey,
            destAccount,
            amountDesired
        );
    }

    function addLiquidityETH(address destAccount, uint256 deadline)
        external
        payable
        virtual
        override
        ensure(deadline)
        returns (uint256 liquidity)
    {
        ILiquidityToken liquidityToken = issuerForLiquidityToken()
            .lTokensForSettleToken(ETH);
        bytes32 lTokenKey = issuerForLiquidityToken().lTokensByAddress(
            address(liquidityToken)
        );

        require(
            liquidityToken != ILiquidityToken(address(0)),
            "CBBC: LIQUIDITY_POOL_NOT_EXIST."
        );

        uint256 amountETH = msg.value;
        weth().deposit{value: amountETH}(); // wrapped ETH to WETH
        assert(weth().transfer(address(liquidityToken), amountETH));

        liquidity = issuerForLiquidityToken().mintLiquidityTokens(
            lTokenKey,
            destAccount,
            amountETH
        );
        // refund dust eth, if any
        //        if (msg.value > amountETH) TransferHelper.safeTransferETH(msg.sender, msg.value - amountETH);
    }

    // **** REMOVE LIQUIDITY ****
    // function removeLiquidity(
    //     bytes32 settleTokenKey,
    //     uint256 liquidity,
    //     uint256 amountMin,
    //     address destAccount, // where settleToken is going
    //     uint256 deadline
    // ) public virtual override ensure(deadline) returns (uint256 amount) {
    //     ILiquidityToken liquidityToken = issuerForLiquidityToken()
    //         .lTokensForSettleToken(settleTokenKey);
    //     bytes32 lTokenKey = issuerForLiquidityToken().lTokensByAddress(
    //         address(liquidityToken)
    //     );

    //     IERC20(address(liquidityToken)).transferFrom(
    //         msg.sender,
    //         address(issuerForLiquidityToken()),
    //         liquidity
    //     );
    //     // send liquidity to issuerForLiquidityToken()

    //     amount = issuerForLiquidityToken().burnLiquidityTokens(lTokenKey,destAccount,liquidity);

    //     require(amount >= amountMin, "CBBC: INSUFFICIENT_SETTLEMENT_AMOUNT");
    // }

    // function removeLiquidityETH(
    //     uint256 liquidity,
    //     uint256 amountETHMin,
    //     address destAccount,
    //     uint256 deadline
    // ) public virtual override ensure(deadline) returns (uint256 amountETH) {
    //     amountETH = removeLiquidity(
    //         ETH,
    //         liquidity,
    //         amountETHMin,
    //         address(this),
    //         deadline
    //     );
    //     weth().withdraw(amountETH); // transform WETH back to ETH

    //     TransferHelper.safeTransferETH(destAccount, amountETH);
    // }

    // function removeLiquidityWithPermit(
    //     bytes32 settleTokenKey,
    //     uint256 liquidity,
    //     uint256 amountMin,
    //     address destAccount, // where settleToken is going
    //     uint256 deadline,
    //     permitData calldata permitData_
    // ) public virtual override returns (uint256 amount) {
    //     ILiquidityToken liquidityToken = issuerForLiquidityToken()
    //         .lTokensForSettleToken(settleTokenKey);

    //     uint256 value = permitData_.approveMax ? type(uint256).max : liquidity;

    //     IExternStateToken(address(liquidityToken)).permit(
    //         msg.sender,
    //         address(this),
    //         value,
    //         deadline,
    //         permitData_.v,
    //         permitData_.r,
    //         permitData_.s
    //     );

    //     amount = removeLiquidity(
    //         settleTokenKey,
    //         liquidity,
    //         amountMin,
    //         destAccount,
    //         deadline
    //     );
    // }

    // function removeLiquidityETHWithPermit(
    //     uint256 liquidity,
    //     uint256 amountETHMin,
    //     address destAccount,
    //     uint256 deadline,
    //     permitData calldata permitData_
    // ) public virtual override returns (uint256 amountETH) {
    //     ILiquidityToken liquidityToken = issuerForLiquidityToken()
    //         .lTokensForSettleToken(ETH);

    //     uint256 value = permitData_.approveMax ? type(uint256).max : liquidity;

    //     IExternStateToken(address(liquidityToken)).permit(
    //         msg.sender,
    //         address(this),
    //         value,
    //         deadline,
    //         permitData_.v,
    //         permitData_.r,
    //         permitData_.s
    //     );

    //     amountETH = removeLiquidityETH(
    //         liquidity,
    //         amountETHMin,
    //         destAccount,
    //         deadline
    //     );
    // }

    // **** Mint DividendToken ****
    // function buyDividendToken(
    //     bytes32 settleTokenKey,
    //     uint256 amountDesired,
    //     address destAccount,
    //     uint256 deadline
    // ) public virtual override ensure(deadline) returns (uint256 dividend) {
    //     IDividendToken dividendToken = issuerForDividendToken()
    //         .dTokensForSettleToken(settleTokenKey);
    //     bytes32 dTokenKey = issuerForDividendToken().dTokensByAddress(
    //         address(dividendToken)
    //     );

    //     require(
    //         dividendToken != IDividendToken(address(0)),
    //         "CBBC: DIVIDEND_TOKEN_NOT_EXIST."
    //     );

    //     IERC20(address(charm())).transferFrom(
    //         msg.sender,
    //         address(issuerForDividendToken()),
    //         amountDesired
    //     );

    //     dividend = issuerForDividendToken().mintDividendTokens(
    //         dTokenKey,
    //         destAccount,
    //         amountDesired
    //     );
    // }

    // function buyDividendTokenWithPermit(
    //     bytes32 settleTokenKey,
    //     uint256 amountDesired,
    //     address destAccount,
    //     uint256 deadline,
    //     permitData calldata permitData_
    // ) public virtual override ensure(deadline) returns (uint256 dividend) {
    //     uint256 value = permitData_.approveMax
    //         ? type(uint256).max
    //         : amountDesired;

    //     IExternStateToken(address(charm())).permit(
    //         msg.sender,
    //         address(this),
    //         value,
    //         deadline,
    //         permitData_.v,
    //         permitData_.r,
    //         permitData_.s
    //     );

    //     dividend = buyDividendToken(
    //         settleTokenKey,
    //         amountDesired,
    //         destAccount,
    //         deadline
    //     );
    // }

    // **** Burn DividendToken ****
    // function sellDividendToken(
    //     bytes32 settleTokenKey,
    //     uint256 dividend,
    //     uint256 amountMin,
    //     address to,
    //     uint256 deadline
    // ) public virtual override ensure(deadline) returns (uint256 amount) {
    //     IDividendToken dividendToken = issuerForDividendToken()
    //         .dTokensForSettleToken(settleTokenKey);
    //     bytes32 dTokenKey = issuerForDividendToken().dTokensByAddress(
    //         address(dividendToken)
    //     );

    //     IERC20(address(dividendToken)).transferFrom(
    //         msg.sender,
    //         address(issuerForDividendToken()),
    //         dividend
    //     );

    //     // send liquidity to pair
    //     amount = issuerForDividendToken().burnDividendTokens(
    //         dTokenKey,
    //         to,
    //         dividend
    //     );

    //     require(amount >= amountMin, "CBBC: INSUFFICIENT_SETTLEMENT_AMOUNT");
    // }

    // function sellDividendTokenETH(
    //     uint256 dividend,
    //     uint256 amountETHMin,
    //     address to,
    //     uint256 deadline
    // ) public virtual override ensure(deadline) returns (uint256 amountETH) {
    //     amountETH = sellDividendToken(
    //         ETH,
    //         dividend,
    //         amountETHMin,
    //         address(this),
    //         deadline
    //     );
    //     weth().withdraw(amountETH); // transform WETH back to ETH

    //     TransferHelper.safeTransferETH(to, amountETH);
    // }

    // function sellDividendTokenWithPermit(
    //     bytes32 settleTokenKey,
    //     uint256 dividend,
    //     uint256 amountMin,
    //     address to,
    //     uint256 deadline,
    //     permitData calldata permitData_
    // ) public virtual override ensure(deadline) returns (uint256 amount) {
    //     IDividendToken dividendToken = issuerForDividendToken()
    //         .dTokensForSettleToken(settleTokenKey);

    //     uint256 value = permitData_.approveMax ? type(uint256).max : dividend;

    //     IExternStateToken(address(dividendToken)).permit(
    //         msg.sender,
    //         address(this),
    //         value,
    //         deadline,
    //         permitData_.v,
    //         permitData_.r,
    //         permitData_.s
    //     );

    //     // send liquidity to pair
    //     amount = sellDividendToken(
    //         settleTokenKey,
    //         dividend,
    //         amountMin,
    //         to,
    //         deadline
    //     );
    // }

    // function sellDividendTokenETHWithPermit(
    //     uint256 dividend,
    //     uint256 amountETHMin,
    //     address to,
    //     uint256 deadline,
    //     permitData calldata permitData_
    // ) public virtual override ensure(deadline) returns (uint256 amountETH) {
    //     IDividendToken dividendToken = issuerForDividendToken()
    //         .dTokensForSettleToken(ETH);

    //     uint256 value = permitData_.approveMax ? type(uint256).max : dividend;

    //     IExternStateToken(address(dividendToken)).permit(
    //         msg.sender,
    //         address(this),
    //         value,
    //         deadline,
    //         permitData_.v,
    //         permitData_.r,
    //         permitData_.s
    //     );

    //     // send liquidity to pair
    //     amountETH = sellDividendTokenETH(dividend, amountETHMin, to, deadline);
    // }

    // **** LIBRARY FUNCTIONS ****

    function buyOptions(
        bool direction,
        uint128 _delta,
        uint128 _bk,
        uint128 _cppcNum,
        address _strategy,
        IIssuerForSatoshiOptions.SignedPriceInput calldata signedPr
    ) external payable override returns (uint256 pid) {
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

    function _mintLiquidityToken(
        address token,
        address destAccount,
        uint256 amount
    ) external {}

    function sellOptions(
        uint256 _pid,
        uint128 _cAmount,
        IIssuerForSatoshiOptions.SignedPriceInput calldata signedPr
    ) external override returns (uint256 liquidationNum) {
        liquidationNum = satoshiOptions().burnFor(
            msg.sender,
            _pid,
            _cAmount,
            signedPr
        );

        uint256 balance = _containersBalance();
        if (liquidationNum > balance) {
            _withdraw(signedPr.tradeToken, msg.sender, balance);
            liquidationNum -= balance;
        }
        // _mintLiquidityToken(token, msg.sender, liquidationNum);
    }

    function _containersBalance() internal view returns (uint256) {
        return address(issuerForLiquidityToken()).myBalance();
    }

    function _deposit(
        address token,
        address _from,
        uint256 amount
    ) internal {
        address containers = address(issuerForLiquidityToken());
        if (token == address(0)) {
            amount = msg.value;
            weth().deposit{value: amount}();
            weth().transfer(containers, amount);
        } else {
            token.safeTransferFrom(_from, containers, amount);
        }
    }

    function _withdraw(
        address token,
        address _to,
        uint256 amount
    ) internal {
        if (token == address(0)) {
            weth().withdraw(amount);
            SafeToken.safeTransferETH(_to, amount);
        } else {
            token.safeTransfer(_to, amount);
        }
    }

    /* ==========  MODIFIERS   =========== */
    modifier ensure(uint256 deadline) {
        require(deadline >= block.timestamp, "CBBC::Router: EXPIRED");
        _;
    }
}
