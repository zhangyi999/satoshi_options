pragma solidity ^0.8.3;

// import "./cbbc_related/Owned.sol";
//import "./MixinResolver.sol";
// import "./router_import/MixinSystemSettings.sol";
import "./interfaces/ICharmToken.sol";

import "./interfaces/IIssuerForSatoshiOptions.sol";

import "./interfaces/IWETH.sol";

import "./libraries/SafeToken.sol";

import "hardhat/console.sol";

contract Router {
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

    // receive() external payable {
    //     assert(msg.sender == address(weth())); // only accept ETH via fallback from the WETH contract
    // }

    address private _weth;
    address private _charm;
    address private _options;
    constructor(address _weth_, address _charm_, address _options_) public {
        _weth = _weth_;
        _charm = _charm_;
        _options = _options_;
    }

    /* ========== VIEWS ========== */
    function weth() public view returns(IWETH) {
        // IWETH();
        return IWETH(_weth);
    }

    function charm() public view returns (ICharmToken) {
        return ICharmToken(_charm);
    }

    // function orchestrator() internal view returns (IOrchestrator) {
    //     return IOrchestrator(requireAndGetAddress(CONTRACT_ORCHESTRATOR));
    // }

    function satoshiOptions() public view returns (IIssuerForSatoshiOptions) {
        return
            IIssuerForSatoshiOptions(_options);
    }

    
    // **** LIBRARY FUNCTIONS ****

    function buyOptions(
        bool direction,
        uint128 _delta,
        uint128 _bk,
        uint128 _cppcNum,
        address _strategy,
        IIssuerForSatoshiOptions.SignedPriceInput calldata signedPr
    ) external payable returns (uint256 pid, uint256 mintBalance) {
        // console.log("wom %s %s %s", _cppcNum,mulu(int128(_cppcNum), 1e18));
        _deposit(signedPr.tradeToken, msg.sender, mulu(int128(_cppcNum), 1e18));
        (pid, mintBalance) = satoshiOptions().mintTo(
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
        address destAccount,
        uint256 amount
    ) internal {
        charm().mint(destAccount, amount);
    }

    function sellOptions(
        uint256 _pid,
        uint128 _cAmount,
        IIssuerForSatoshiOptions.SignedPriceInput calldata signedPr
    ) external returns (uint256 liquidationNum) {
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
        _mintLiquidityToken(msg.sender, liquidationNum);
    }

    function _containersBalance() internal view returns (uint256) {
        return address(charm()).myBalance();
    }

    function _deposit(
        address token,
        address _from,
        uint256 amount
    ) internal {
        address containers = address(charm());
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

    function mulu (int128 x, uint256 y) internal pure returns (uint256) {
        unchecked {
        if (y == 0) return 0;

        require (x >= 0);

        uint256 lo = (uint256 (int256 (x)) * (y & 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)) >> 64;
        uint256 hi = uint256 (int256 (x)) * (y >> 128);

        require (hi <= 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF);
        hi <<= 64;

        require (hi <=
            0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF - lo);
        return hi + lo;
        }
    }

}
