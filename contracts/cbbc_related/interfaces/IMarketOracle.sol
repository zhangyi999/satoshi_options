pragma solidity = 0.8.3;

interface IMarketOracle{
    struct tradeTokenData{
        uint80 bidAskSpread; // bid-ask spread; real * 10**18; bid-ask spread of tradeToken/USDT price
        uint80 dailyPriceVolatility; // daily price volatility, real * 10**18; usually 2000 for BTC
        uint96 dailyVolume; // daily tradinng volume; in tradeToken decimal; usually 2000 * 10**18 for BTC
    }

    struct signedPrice {
        uint256 tradePrice;
        bytes signature;
    }

    function interestRates(bytes32) external view returns(uint256);

    function tradeTokenDatas(bytes32) external view returns(uint80, uint80, uint96);

    function settleTokenPrices(bytes32) external view returns(uint256);

    function betas(bytes32 settleTokenKey, bytes32 tradeTokenKey) external view returns(int256);

    function priceAndTimestamp(bytes32 token) external view returns (uint256 price, uint256 timestamp);

// ============ MUTATIVE FUNCTIONS ====================
    function updateOracle(
        bytes32 tradeToken,
        signedPrice calldata signedPr
        ) external returns(bool);

    function updateOracles(
        bytes32[] calldata tradeTokens,
        signedPrice[] calldata signedPrs
        ) external returns(bool);

    function updateRate(
        bytes32 currencyKey,
        uint newRate,
        uint timeSent
    ) external returns (bool);

    function updateRates(
        bytes32[] calldata currencyKeys,
        uint[] calldata newRates,
        uint timeSent
    ) external returns (bool);
}