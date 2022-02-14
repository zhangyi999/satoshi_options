pragma solidity ^0.8.3;

// import "./cbbc_related/Owned.sol";
//import "./MixinResolver.sol";
import "./MixinSystemSettings.sol";
import "./interfaces/ICharmToken.sol";

import "./interfaces/IIssuerForSatoshiOptions.sol";

import "./libraries/SafeToken.sol";

contract Router is MixinSystemSettings {
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

    function satoshiOptions() internal view returns (IIssuerForSatoshiOptions) {
        return
            IIssuerForSatoshiOptions(
                requireAndGetAddress(CONTRACT_SATOSHIOPTIONS)
            );
    }

    
    // **** LIBRARY FUNCTIONS ****

    function buyOptions(
        bool direction,
        uint128 _delta,
        uint128 _bk,
        uint128 _cppcNum,
        address _strategy,
        IIssuerForSatoshiOptions.SignedPriceInput calldata signedPr
    ) external payable override returns (uint256 pid, uint256 mintBalance) {
        _deposit(signedPr.tradeToken, msg.sender, _cppcNum);
        (pid,mintBalance) = satoshiOptions().mintTo(
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
