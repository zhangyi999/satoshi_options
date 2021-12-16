pragma solidity 0.8.3;

// Inheritance
import "./Owned.sol";
//import "./MixinResolver.sol";
import "./MixinSystemSettings.sol";
//import "./ExternCbbcStateToken.sol";
//import "./ExternStateToken.sol";

// Libraries
//import "./libraries/SafeCast.sol";
//import "./libraries/SafeDecimalMath.sol";

// Internal references
import "./interfaces/IIssuerForCbbcToken.sol";
import "./interfaces/ICbbcToken.sol";
import "./interfaces/IIssuerForLiquidityToken.sol";
import "./interfaces/ILiquidityToken.sol";
import "./interfaces/IExchangeRates.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/ICharmToken.sol";
//import "./Proxyable.sol";
/*
interface IProxy {
    function target() external view returns (address);
}
*/

// https://docs.synthetix.io/contracts/source/contracts/issuer
contract IssuerForCbbcToken is Owned, MixinSystemSettings, IIssuerForCbbcToken{
//    using SafeDecimalMath for uint;

    bytes32 public constant CONTRACT_NAME = "IssuerForCbbcToken";

    // Available Synths which can be used with the system
    ICbbcToken[] public availableCTokens;
    mapping(bytes32 => ICbbcToken) public override cTokens;
    mapping(address => bytes32) public override cTokensByAddress;
    mapping(bytes32 => mapping(bytes32 => mapping(uint8 => mapping(ICbbcToken.CbbcType => ICbbcToken)))) public override getCTokens;

    /* ========== ENCODED NAMES ========== */
    bytes32 internal constant CHARM = "CHARM";

    // Flexible storage names
    bytes32 internal constant PURCHASE_COST = "purchaseCost";

    /* ========== ADDRESS RESOLVER CONFIGURATION ========== */
    //bytes32 private constant CONTRACT_CHARM = "CharmToken";
    bytes32 private constant CONTRACT_EXRATES = "ExchangeRates";
    bytes32 private constant CONTRACT_ISSUER_FOR_LIQUIDITY_TOKEN = "IssuerForLiquidityToken";
    bytes32 private constant CONTRACT_ROUTER = "Router";

    constructor(address _owner, address _resolver) Owned(_owner) MixinSystemSettings(_resolver) {}

    /* ========== VIEWS ========== */
    function resolverAddressesRequired() public view override returns (bytes32[] memory addresses) {
        bytes32[] memory existingAddresses = MixinSystemSettings.resolverAddressesRequired();
        bytes32[] memory newAddresses = new bytes32[](4);
        newAddresses[0] = CONTRACT_EXRATES;
        newAddresses[1] = CONTRACT_ISSUER_FOR_LIQUIDITY_TOKEN;
        newAddresses[2] = CONTRACT_ROUTER;
        newAddresses[3] = CHARM;
        return combineArrays(existingAddresses, newAddresses);
    }

    function exchangeRates() internal view returns (IExchangeRates) {
        return IExchangeRates(requireAndGetAddress(CONTRACT_EXRATES));
    }

    function issuerForLiquidityToken() internal view returns (IIssuerForLiquidityToken) {
        return IIssuerForLiquidityToken(requireAndGetAddress(CONTRACT_ISSUER_FOR_LIQUIDITY_TOKEN));
    }

    function router() internal view returns (address) {
        return requireAndGetAddress(CONTRACT_ROUTER);
    }

    function charm() internal view returns (ICharmToken) {
        return ICharmToken(requireAndGetAddress(CHARM));
    }

    function _settleTokenKey(ICbbcToken _token) internal view returns (bytes32) {
        return _token.settleTokenKey();
    }

    function _tradeTokenKey(ICbbcToken _token) internal view returns (bytes32) {
        return _token.tradeTokenKey();
    }

    function _leverage(ICbbcToken _token) internal view returns (uint256) {
        return uint256(_token.leverage());
    }

    function _cbbcType(ICbbcToken _token) internal view returns (ICbbcToken.CbbcType) {
        return _token.cbbcType();
    }

    function _availableCTokenKeys() internal view returns (bytes32[] memory) {
        bytes32[] memory currencyKeys = new bytes32[](availableCTokens.length);

        for (uint i = 0; i < availableCTokens.length; i++) {
            currencyKeys[i] = cTokensByAddress[address(availableCTokens[i])];
        }

        return currencyKeys;
    }

    function availableCTokenKeys() external view override returns (bytes32[] memory) {
        return _availableCTokenKeys();
    }

    function availableCTokenCount() external view override returns (uint) {
        return availableCTokens.length;
    }

    function availableCToken(uint index) external view override returns (ICbbcToken) {
        require(index < availableCTokens.length, "Length of availableCTokens is less than index");
        return availableCTokens[index];
    }

    function getCTokensByKeys(bytes32[] calldata currencyKeys) external view override returns (ICbbcToken[] memory) {
        uint numKeys = currencyKeys.length;
        ICbbcToken[] memory addresses = new ICbbcToken[](numKeys);

        for (uint i = 0; i < numKeys; i++) {
            addresses[i] = cTokens[currencyKeys[i]];
        }

        return addresses;
    }

    function getAvailableCTokens() external view override returns (ICbbcToken[] memory) {
        ICbbcToken[] memory tokens = new ICbbcToken[](availableCTokens.length);

        for (uint i = 0; i < availableCTokens.length; i++) {
            tokens[i] = availableCTokens[i];
        }

        return tokens;
    }

    function issuedCTokens(bytes32 currencyKey) external view override returns (uint){
        return _issuedCTokens(currencyKey);
    }

    function _issuedCTokens(bytes32 currencyKey) internal view returns (uint){
        return IERC20(address(cTokens[currencyKey])).totalSupply();
    }

    function _totalIssuedCTokens(bytes32 settleTokenKey) internal view returns (uint){
        bytes32[] memory tokenKeys = _cTokenKeysForSettleToken(settleTokenKey);
        uint totalIssued = 0;
        for (uint i = 0; i < tokenKeys.length; i++) {
            totalIssued += _issuedCTokens(tokenKeys[i]);
        }

        return totalIssued;
    }

    function totalIssuedCTokens(bytes32 settleTokenKey) external view override returns (uint){
            return _totalIssuedCTokens(settleTokenKey);
        }

    function cTokenKeysForSettleToken(bytes32 settleTokenKey) external view override returns (bytes32[] memory) {
        return _cTokenKeysForSettleToken(settleTokenKey);
    }

    function _cTokenKeysForSettleToken(bytes32 settleTokenKey) internal view returns (bytes32[] memory) {
        uint numKeys = availableCTokens.length;
        bytes32[] memory cTokenKeys = new bytes32[](numKeys);
        uint numCTokens = 0;

        for (uint i = 0; i < numKeys; i++) {
            if (availableCTokens[i].settleTokenKey() == settleTokenKey) {
                cTokenKeys[numCTokens] = cTokensByAddress[address(availableCTokens[i])];
                numCTokens++;
            }
        }
        
        return cTokenKeys; // cTokenKeys[:numCTokens]; TODO:
    }

    function claimableProfits(bytes32 settleTokenKey) external view override returns (uint){
        return _claimableProfits(settleTokenKey);
    }

    function _claimableProfits(bytes32 settleTokenKey) internal view returns (uint) {
        if(settleTokenKey == CHARM){
            return 0;
        } else {
            ILiquidityToken lToken = issuerForLiquidityToken().lTokensForSettleToken(settleTokenKey);
            uint256 initialSupply = lToken.initialSupply();
            uint256 totalSupply = IERC20(address(lToken)).totalSupply();
            IERC20 settleToken = IERC20(lToken.settleTokenAddress());
            uint256 settleTokensInPool = settleToken.balanceOf(address(lToken)) * 10**(18 - settleToken.decimals());
            uint256 cTokensInPool = _totalIssuedCTokens(settleTokenKey);

            uint256 profits = settleTokensInPool + initialSupply > totalSupply + cTokensInPool*2 ?
                settleTokensInPool + initialSupply - totalSupply - cTokensInPool*2 : 0;
            return profits;
        }
    }

    /**
    * @dev Compute cbbc amount you will receive if you spend settleAmount of settleToken to buy cbbc.
    * @param cToken ICbbcToken. The cbbc you are buying
    * @param settleAmount A uint256 value. The amount of settle token you are using
    * @return cbbcAmount A uint256 value. The amount of cbbc you will receive
    */
    function getCbbcAmount(
        ICbbcToken cToken,
        uint settleAmount)
        internal view returns (uint cbbcAmount)
    {
        require(!exchangeRates().rateIsInvalid(_tradeTokenKey(cToken)), "CBBC: TRADE_PRICE_INVALID.");

        uint cbbcPrice = cToken.getCbbcPrice(settleAmount, 0, ICbbcToken.tradeDirection.buyCbbc);

//        cbbcAmount = settleAmount * (10**18) /(10 ** IERC20(cToken.settleTokenAddress()).decimals()) * (10**18) / cbbcPrice;
        cbbcAmount = settleAmount * 10**(36 - IERC20(cToken.settleTokenAddress()).decimals())/ cbbcPrice;
    }

    /**
    * @dev Compute settleToken amount you will receive if you sell cbbcAmount of cbbc.
    * @param cToken ICbbcToken. The cbbc you are selling
    * @param cbbcAmount A uint256 value. The amount of cbbc you are selling
    * @return settleAmount A uint256 value. The amount of settleToken you will receive
    */
    function getSettleAmount(
        ICbbcToken cToken,
        uint cbbcAmount)
        internal view returns (uint settleAmount)
    {
        require(!exchangeRates().rateIsInvalid(_tradeTokenKey(cToken)), "CBBC: TRADE_PRICE_INVALID.");

        uint cbbcPrice = cToken.getCbbcPrice(0, cbbcAmount, ICbbcToken.tradeDirection.sellCbbc);

        settleAmount = cbbcAmount * cbbcPrice / (10**18) * (10000 - _leverage(cToken) * 6) / 10000 * (10 ** IERC20(cToken.settleTokenAddress()).decimals()) / (10**18); // transform to USDT * 10 s** 18; round fee = 6bp
    }

    function getPurchaseCost(bytes32 cTokenKey, address account) public view override returns (uint) {
        // Set the cost of the last mint or burn event.
        return flexibleStorage().getUIntValue(
            CONTRACT_NAME,
            keccak256(abi.encodePacked(PURCHASE_COST, cTokenKey, account))
        );
    }
    /* ========== MUTATIVE FUNCTIONS ========== */

    function _addCToken(ICbbcToken token) internal {
        bytes32 currencyKey = token.currencyKey();
        ICbbcToken cbbcToken = getCTokens[_settleTokenKey(token)][_tradeTokenKey(token)][uint8(_leverage(token))][_cbbcType(token)];

        require(cbbcToken == ICbbcToken(address(0)), "CbbcToken exists");
        require(cTokens[currencyKey] == ICbbcToken(address(0)), "CbbcToken exists");
        require(cTokensByAddress[address(token)] == bytes32(0), "cToken address already exists");
        require(_settleTokenKey(token) == CHARM || issuerForLiquidityToken().lTokensForSettleToken(_settleTokenKey(token)) != ILiquidityToken(address(0)), "Liquidity pool is not ready yet.");

        availableCTokens.push(token);
        cTokens[currencyKey] = token;
        cTokensByAddress[address(token)] = currencyKey;
        getCTokens[_settleTokenKey(token)][_tradeTokenKey(token)][uint8(_leverage(token))][_cbbcType(token)] = token;

        emit CbbcTokenAdded(currencyKey, address(token));
    }

    function addCToken(ICbbcToken token) external onlyOwner {
        _addCToken(token);
    }

    function addCTokens(ICbbcToken[] calldata tokensToAdd) external onlyOwner {
        uint numSynths = tokensToAdd.length;
        for (uint i = 0; i < numSynths; i++) {
            _addCToken(tokensToAdd[i]);
        }
    }

    function _removeCToken(bytes32 currencyKey) internal {
        address tokenToRemove = address(cTokens[currencyKey]);
        require(tokenToRemove != address(0), "Synth does not exist");

        uint tokenSupply = IERC20(tokenToRemove).totalSupply();

        if (tokenSupply > 0) { //TODO: what action will be taken if there is a supply?
//            ISynthRedeemer _synthRedeemer = synthRedeemer();
//            synths[sUSD].issue(address(_synthRedeemer), amountOfsUSD);
            // ensure the debt cache is aware of the new sUSD issued
//            debtCache().updateCachedsUSDDebt(SafeCast.toInt256(amountOfsUSD));
//            _synthRedeemer.deprecate(IERC20(address(Proxyable(address(synthToRemove)).proxy())), rateToRedeem);
        }

        // Remove the synth from the availableSynths array.
        for (uint i = 0; i < availableCTokens.length; i++) {
            if (address(availableCTokens[i]) == tokenToRemove) {
                delete availableCTokens[i];

                // Copy the last synth into the place of the one we just deleted
                // If there's only one synth, this is synths[0] = synths[0].
                // If we're deleting the last one, it's also a NOOP in the same way.
                availableCTokens[i] = availableCTokens[availableCTokens.length - 1];

                // Decrease the size of the array by one.
                availableCTokens.pop();

                break;
            }
        }

        // And remove it from the synths mapping
        delete cTokensByAddress[tokenToRemove];
        delete cTokens[currencyKey];
        ICbbcToken cTokenToRemove = ICbbcToken(tokenToRemove);
        delete getCTokens[_settleTokenKey(cTokenToRemove)][_tradeTokenKey(cTokenToRemove)][uint8(_leverage(cTokenToRemove))][_cbbcType(cTokenToRemove)];

        emit CbbcTokenRemoved(currencyKey, tokenToRemove);
    }

    function removeCToken(bytes32 currencyKey) external onlyOwner {
        _removeCToken(currencyKey);
    }

    function removeCTokens(bytes32[] calldata currencyKeys) external onlyOwner {
        uint numKeys = currencyKeys.length;

        for (uint i = 0; i < numKeys; i++) {
            _removeCToken(currencyKeys[i]);
        }
    }

    // this low-level function should be called from a contract which performs important safety checks
    function mintCbbc(
        bytes32 token,
        address to,
        uint settleAmount)
        external override lock onlyRouter returns(uint cbbcAmount)
    {
        ICbbcToken cToken = cTokens[token];

        require(cToken != ICbbcToken(address(0)), "CbbcToken does not exist");

        cbbcAmount = getCbbcAmount(cToken, settleAmount);

        require(cbbcAmount > 0, "CBBC: INSUFFICIENT_CBBC_TOKEN_OUT.");

        _issueCTokens(cToken, to, cbbcAmount);
        _setPurchaseCost(token, to, settleAmount, 0);
    }

    // this low-level function should be called from a contract which performs important safety checks
    function burnCbbc(
        bytes32 token,
        address from,
        uint cbbcAmount
        ) external override lock onlyRouter returns(uint settleAmount)
    {
        ICbbcToken cToken = cTokens[token];

        settleAmount = getSettleAmount(cToken, cbbcAmount);
        require(settleAmount > 0, "CBBC: INSUFFICIENT_SETTLE_TOKEN_OUT.");

        uint previousPurchaseCost = getPurchaseCost(token, from);

        uint numberOfCTokens = IERC20(address(cToken)).balanceOf(from);

        numberOfCTokens = numberOfCTokens > cbbcAmount? numberOfCTokens : cbbcAmount; // to make sure we don't have negative cost.

        uint costToReduce = previousPurchaseCost * cbbcAmount/numberOfCTokens;

        require(_burnCTokens(cToken, address(this), cbbcAmount), "CBBC: FAIL to burn CBBC_TOKEN.");

        bytes32 settleTokenKey = cToken.settleTokenKey();
        address settleTokenAddress = cToken.settleTokenAddress();

        if (settleTokenKey == CHARM) {
            charm().issue(from, settleAmount);
        } else {
            ILiquidityToken lToken = issuerForLiquidityToken().lTokensForSettleToken(cToken.settleTokenKey());

            uint256 settleTokenInPool = IERC20(settleTokenAddress).balanceOf(address(lToken));

            if (settleTokenInPool < settleAmount * 2) {
                lToken.transferSettleToken(from, settleTokenInPool/2);

                lToken.issue(from, settleAmount - settleTokenInPool/2);
            } else {
                // if there is no liquidity in the pool, we can't issue the tokens
                lToken.transferSettleToken(from, settleAmount);
            }
        }

        _setPurchaseCost(token, from, 0, costToReduce);
    }
    /* ========== INTERNAL FUNCTIONS ========== */
    function _setPurchaseCost(bytes32 cTokenKey, address account, uint256 costToAdd, uint256 costToReduce) internal {
        // Set the cost of the last mint or burn event.
        flexibleStorage().setUIntValue(
            CONTRACT_NAME,
            keccak256(abi.encodePacked(PURCHASE_COST, cTokenKey, account)),
            getPurchaseCost(cTokenKey, account) + costToAdd - costToReduce
        );
    }

    function _issueCTokens(
        ICbbcToken token,
        address to,
        uint cbbcAmount
    ) internal {
        token.issue(to, cbbcAmount);
    }

    function _burnCTokens(
        ICbbcToken token,
        address from,
        uint amountOfCTokenToBurn
     ) internal returns(bool){
        require(token.burn(from, amountOfCTokenToBurn), "CBBC: FAIL to burn CBBC_TOKEN.");

        return true;
    }

    /* ========== MODIFIERS ========== */
    uint private unlocked = 1;
    modifier lock() {
        require(unlocked == 1, 'CBBC: LOCKED');
        unlocked = 0;
        _;
        unlocked = 1;
    }

    function _onlyRouter() internal view {
        require(msg.sender == router(), "Issuer: Only the router contract can perform this action");
    }

    modifier onlyRouter() {
        _onlyRouter(); // Use an internal function to save code size.
        _;
    }

    /* ========== EVENTS ========== */

    event CbbcTokenAdded(bytes32 currencyKey, address cToken);
    event CbbcTokenRemoved(bytes32 currencyKey, address cToken);
}
