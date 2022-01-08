pragma solidity = 0.8.3;

import "./Owned.sol";
//import "./MixinResolver.sol";
import "./MixinSystemSettings.sol";

import "./interfaces/IMarketOracle.sol";
import "./interfaces/IExchangeRates.sol";
import "./interfaces/IIssuerForCbbcToken.sol";

import "./libraries/ECDSA.sol";

contract MarketOracle is Owned, MixinSystemSettings, IMarketOracle{
    using ECDSA for bytes32;

    address private _dataProvider;
    // This is the address which provides data oracle. We change this address from time to time, in order to avoid malcious data infusion due to privateKey leakage

    bytes32 public constant CONTRACT_NAME = "MarketOracle";

   mapping (address => mapping(bytes32 => mapping(uint256 => bool))) private seenNonces;
    mapping(bytes32 => uint256) public override interestRates;
    mapping(bytes32 => tradeTokenData) public override tradeTokenDatas;
    mapping(bytes32 => uint256) public override settleTokenPrices; // settleToken prices, decimals = 18
    mapping(bytes32 => mapping(bytes32 => int256)) public override betas; // betas[market][token], real number * 10**6

/* ========== ADDRESS RESOLVER CONFIGURATION ========== */
    bytes32 private constant CONTRACT_EXCHANGERATES = "ExchangeRates";
    bytes32 private constant CONTRACT_ISSUER = "IssuerForCbbcToken";

// ======== Constructor =================
    constructor(
        address dataProvider,
        address owner,
        address resolver
        ) Owned(owner) MixinSystemSettings(resolver){
        _dataProvider = dataProvider;
    }

// =========  Views ============
    function resolverAddressesRequired() public view override returns (bytes32[] memory addresses) {
        bytes32[] memory existingAddresses = MixinSystemSettings.resolverAddressesRequired();
        bytes32[] memory newAddresses = new bytes32[](2);
        newAddresses[0] = CONTRACT_EXCHANGERATES;
        newAddresses[1] = CONTRACT_ISSUER;
        addresses = combineArrays(existingAddresses, newAddresses);
    }

    function exchangeRates() internal view returns (IExchangeRates) {
        return IExchangeRates(requireAndGetAddress(CONTRACT_EXCHANGERATES));
    }

    function issuer() internal view returns (IIssuerForCbbcToken) {
        return IIssuerForCbbcToken(requireAndGetAddress(CONTRACT_ISSUER));
    }

    function priceAndTimestamp(bytes32 token) external view override returns (uint256 price, uint256 timestamp) {
        return exchangeRates().rateAndUpdatedTime(token);
    }

// ========= Setters ===========

   function setDataProvider(address dataProvider) external onlyOwner{
        _dataProvider = dataProvider;
        emit SetDataProvider(dataProvider);
    }

    function setInterestRate(bytes32 token, uint256 iRate) external onlyOwner {
        interestRates[token] = iRate;
        emit SetInterestRate(token, iRate);
    }

    function setTradeTokenData(
        bytes32 token,
        uint80 baSpread,
        uint88 dailyPriceVol,
        uint88 dailyVol
    ) external onlyOwner {
        require(baSpread < type(uint80).max && dailyPriceVol < type(uint80).max && dailyVol < type(uint96).max, "CBBC: tradeTokenData: baSpread, dailyPriceVol or dailyVol overflow");
        tradeTokenDatas[token] = tradeTokenData({
            bidAskSpread: uint80(baSpread),
            dailyPriceVolatility: uint80(dailyPriceVol),
            dailyVolume: uint96(dailyVol)
            });
        emit SetTradeTokenData(token, baSpread, dailyPriceVol, dailyVol);
    }

    function setSettleTokenPrice(bytes32 settleToken, uint256 settleTokenPrice) external onlyOwner {
        settleTokenPrices[settleToken] = settleTokenPrice;
        emit SetSettleTokenPrice(settleToken, settleTokenPrice);
    }

    function setBeta(bytes32 settleToken, bytes32 tradeToken, int256 beta) external onlyOwner {
        betas[settleToken][tradeToken] = beta;
        emit SetBeta(settleToken, tradeToken, beta);
    }


// ============ MUTATIVE FUNCTIONS ====================
    function updateOracle(
        bytes32 tradeToken,
        signedPrice calldata signedPr
        ) external override returns(bool){
            return _checkIdentityAndUpdateOracle(tradeToken, signedPr);
        }

   function updateOracles(
        bytes32[] calldata tradeTokens,
        signedPrice[] calldata signedPrs
        ) external override returns(bool){
            return _checkIdentityAndUpdateOracles(tradeTokens, signedPrs);
        }

/*
    function updateOraclesForOneSettleToken(
        bytes32 settleToken,
        bytes32[] calldata tradeTokens,
        signedPrice[] calldata signedPrs
        ) external override{
            _updateOraclesForOneSettleToken(settleToken, tradeTokens, signedPrs);
        }
*/
    function updateRate(
        bytes32 currencyKey,
        uint newRate,
        uint timeSent
    ) external override onlyDataProvider returns (bool) {
        uint timeSent_ = timeSent == 0? block.timestamp : timeSent;
        return exchangeRates().updateRate(currencyKey, newRate, timeSent_);
    }

    function updateRates(
        bytes32[] calldata currencyKeys,
        uint[] calldata newRates,
        uint timeSent
    ) external override onlyDataProvider returns (bool) {
        uint timeSent_ = timeSent == 0? block.timestamp : timeSent;
        return exchangeRates().updateRates(currencyKeys, newRates, timeSent_);
    }

// ============ INTERNAL FUNCTIONS ====================
    function _checkIdentityAndUpdateOracle(
        bytes32 tradeToken,
        signedPrice calldata signedPr
    )  private returns(bool success){
        // This recreates the message hash that was signed on the client.
        uint256 tradePrice = signedPr.tradePrice;
        uint256 nonce = signedPr.nonce;
        uint256 expireTimeStamp = signedPr.expireTimeStamp;
        bytes calldata signature = signedPr.signature;
        bytes32 hash = keccak256(abi.encodePacked(tradeToken, tradePrice, nonce, expireTimeStamp, _dataProvider));
        bytes32 messageHash = hash.toEthSignedMessageHash();

        // Verify that the message's signer is the data provider
        address signer = messageHash.recover(signature);
        require(signer == _dataProvider, "CBBC: INVALID_SIGNER.");

        require(!seenNonces[signer][tradeToken][nonce], "CBBC: USED_NONCE");
        seenNonces[signer][tradeToken][nonce] = true;

        require(block.timestamp < expireTimeStamp, "CBBC: EXPIRED_PRICE_DATA");
        // update the oracle
        success = exchangeRates().updateRate(tradeToken, tradePrice, block.timestamp);
    }

    function _checkIdentityAndUpdateOracles(
        bytes32[] calldata tradeTokens,
        signedPrice[] calldata signedPrs
        ) private returns (bool){
 //       bytes32[] memory tradeTokensForSettle = IIssuerForCbbcToken(issuer()).tradeTokensForSettleToken(settleToken);
 
        uint numberOfTradeTokens = tradeTokens.length;
        require(signedPrs.length == numberOfTradeTokens, "CBBC: TOKEN AND PRICE LENGTHES MISMATCH.");

        for(uint256 i = 0; i < numberOfTradeTokens; i++){
            //require(tradeTokens[i] == tradeTokensForSettle[i], "CBBC: INVALID_TRADE_TOKEN");
            require(_checkIdentityAndUpdateOracle(tradeTokens[i], signedPrs[i]), "CBBC: UPDATE_ORACLE_FAILED.");
        }
        return true;
    }


/*
    function _updateOraclesForOneSettleToken(
        bytes32 settleToken,
        bytes32[] calldata tradeTokens,
        signedPrice[] calldata signedPrs
        ) private {
        bytes32[] memory tradeTokensForSettle = IIssuerForCbbcToken(issuer()).tradeTokensForSettleToken(settleToken);
        uint numberOfTradeTokens = tradeTokens.length;
        require(signedPrs.length == numberOfTradeTokens && tradeTokensForSettle.length == numberOfTradeTokens, "CBBC: TOKEN AND PRICE LENGTHES MISMATCH.");

        for(uint256 i = 0; i < numberOfTradeTokens; i++){
            require(tradeTokens[i] == tradeTokensForSettle[i], "CBBC: INVALID_TRADE_TOKEN");
            require(_checkIdentityAndUpdateOracle(tradeTokens[i], signedPrs[i]), "CBBC: UPDATE_ORACLE_FAILED.");
        }
    }
*/
/* ========== MODIFIERS ========== */

    modifier onlyDataProvider {
        _onlyDataProvider();
        _;
    }

    function _onlyDataProvider() internal view {
        require(msg.sender == _dataProvider, "Only the oracle can perform this action");
    }

// ======== Events ======================
    event SetDataProvider(address dataProvider);
    event SetInterestRate(bytes32 token, uint256 interestRate);
    event SetTradeTokenData(bytes32 token, uint80, uint88, uint88);
    event SetSettleTokenPrice(bytes32 token, uint256 settleTokenPrice);
    event SetBeta(bytes32 settleTokenKey, bytes32 tradeTokenKey, int256 beta);

}