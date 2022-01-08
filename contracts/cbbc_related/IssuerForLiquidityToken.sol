pragma solidity 0.8.3;

// Inheritance
import "./Owned.sol";
import "./MixinSystemSettings.sol";

// Libraries

// Internal references
import "./interfaces/IBaseToken.sol";
import "./interfaces/IIssuerForLiquidityToken.sol";
import "./interfaces/ILiquidityToken.sol";
import "./interfaces/IERC20.sol";
//import "./Proxyable.sol";
/*
interface IProxy {
    function target() external view returns (address);
}
*/
// https://docs.synthetix.io/contracts/source/contracts/issuer
contract IssuerForLiquidityToken is Owned, MixinSystemSettings, IIssuerForLiquidityToken{
//    using SafeDecimalMath for uint;

    bytes32 public constant CONTRACT_NAME = "IssuerForLiquidityToken";

    // Available Synths which can be used with the system
    ILiquidityToken[] public availableLTokens;
    mapping(bytes32 => ILiquidityToken) public override lTokens;
    mapping(address => bytes32) public override lTokensByAddress;
    mapping(bytes32 => ILiquidityToken) public override lTokensForSettleToken;

    /* ========== ENCODED NAMES ========== */
    bytes32 internal constant ETH = "ETH";

    /* ========== ADDRESS RESOLVER CONFIGURATION ========== */
    bytes32 private constant CONTRACT_ROUTER = "Router";

    constructor(address _owner, address _resolver) Owned(_owner) MixinSystemSettings(_resolver) {}

    /* ========== VIEWS ========== */
    function resolverAddressesRequired() public view override returns (bytes32[] memory addresses) {
        bytes32[] memory existingAddresses = MixinSystemSettings.resolverAddressesRequired();
        bytes32[] memory newAddresses = new bytes32[](2);
        newAddresses[0] = CONTRACT_ROUTER;
        newAddresses[1] = ETH;
        return combineArrays(existingAddresses, newAddresses);
    }

    function router() internal view returns (address) {
        return requireAndGetAddress(CONTRACT_ROUTER);
    }

    function weth() internal view returns (address) {
        return requireAndGetAddress(ETH);
    }

    function _settleTokenKey(ILiquidityToken _token) internal view returns (bytes32){
        return _token.settleTokenKey();
    }

    function _availableLTokenKeys() internal view returns (bytes32[] memory) {
        bytes32[] memory currencyKeys = new bytes32[](availableLTokens.length);

        for (uint i = 0; i < availableLTokens.length; i++) {
            currencyKeys[i] = lTokensByAddress[address(availableLTokens[i])];
        }

        return currencyKeys;
    }

    function availableLTokenKeys() external view override returns (bytes32[] memory) {
        return _availableLTokenKeys();
    }

    function availableLTokenCount() external view override returns (uint) {
        return availableLTokens.length;
    }

    function availableLToken(uint index) external view override returns (ILiquidityToken) {
        require(index < availableLTokens.length, "Length of availableLTokens is less than index");
        return availableLTokens[index];
    }

    function getLTokensByKeys(bytes32[] calldata currencyKeys) external override view returns (ILiquidityToken[] memory) {
        uint numKeys = currencyKeys.length;
        ILiquidityToken[] memory addresses = new ILiquidityToken[](numKeys);

        for (uint i = 0; i < numKeys; i++) {
            addresses[i] = lTokens[currencyKeys[i]];
        }

        return addresses;
    }

    function getAvailableLTokens() external view override returns (ILiquidityToken[] memory) {
        ILiquidityToken[] memory tokens = new ILiquidityToken[](availableLTokens.length);

        for (uint i = 0; i < availableLTokens.length; i++) {
            tokens[i] = availableLTokens[i];
        }

        return tokens;
    }

    function calculateAmountOfSettleTokenToReceive(
        bytes32 currencyKey,
        uint amountOfLTokenToBurn
    ) external view override returns(uint256, uint256){
        return _calculateAmountOfSettleTokenToReceive(currencyKey, amountOfLTokenToBurn);
    }

    function _calculateAmountOfSettleTokenToReceive(
        bytes32 currencyKey,
        uint amountOfLTokenToBurn
    ) internal view returns(uint256, uint256){
        ILiquidityToken token = lTokens[currencyKey];

        address settleTokenAddress = token.settleTokenAddress();
        uint settleTokenDecimals = IERC20(settleTokenAddress).decimals();

        uint settleTokenInPool = IERC20(settleTokenAddress).balanceOf(address(token));

        uint totalSupplyOfLToken = IERC20(address(token)).totalSupply();

        uint256 amountOfSettleTokenToReceive;

        if (settleTokenAddress == weth()) {
            amountOfLTokenToBurn = amountOfLTokenToBurn < settleTokenInPool * 10**(18 - settleTokenDecimals)/2 ? amountOfLTokenToBurn : settleTokenInPool * 10**(18 - settleTokenDecimals) / 2;

            amountOfSettleTokenToReceive = amountOfLTokenToBurn / 10**(18 - settleTokenDecimals);
        } else {
            amountOfSettleTokenToReceive = settleTokenInPool * amountOfLTokenToBurn / totalSupplyOfLToken;

            amountOfSettleTokenToReceive = amountOfSettleTokenToReceive < amountOfLTokenToBurn / 10**(18 - settleTokenDecimals)? amountOfSettleTokenToReceive : amountOfLTokenToBurn / 10**(18 - settleTokenDecimals);
        }

        return (amountOfSettleTokenToReceive, amountOfLTokenToBurn);
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    function _addLToken(ILiquidityToken lToken) internal {
        bytes32 currencyKey = IBaseToken(address(lToken)).currencyKey();

        require(lTokens[currencyKey] == ILiquidityToken(address(0)), "LiquidityToken exists");
        require(lTokensByAddress[address(lToken)] == bytes32(0), "LiquidityToken address already exists");
        require(lTokensForSettleToken[lToken.settleTokenKey()] == ILiquidityToken(address(0)), "LiquidityToken for this tradeToken already exists");

        availableLTokens.push(lToken);
        lTokens[currencyKey] = lToken;
        lTokensByAddress[address(lToken)] = currencyKey;
        lTokensForSettleToken[lToken.settleTokenKey()] = lToken;

        emit LiquidityTokenAdded(currencyKey, address(lToken));
    }

    function addLToken(ILiquidityToken lToken) external onlyOwner {
        _addLToken(lToken);
    }

    function addLTokens(ILiquidityToken[] calldata lTokensToAdd) external onlyOwner {
        uint num = lTokensToAdd.length;
        for (uint i = 0; i < num; i++) {
            _addLToken(lTokensToAdd[i]);
        }
    }

    function _removeLToken(bytes32 currencyKey) internal {
        address lTokenToRemove = address(lTokens[currencyKey]);
        require(lTokenToRemove != address(0), "Synth does not exist");

        uint lTokenSupply = IERC20(lTokenToRemove).totalSupply();

        if (lTokenSupply > 0) { //TODO: what action will be taken if there is a supply? We need to move settleToken to new liquidity pool
//            ISynthRedeemer _synthRedeemer = synthRedeemer();
//            synths[sUSD].issue(address(_synthRedeemer), amountOfsUSD);
            // ensure the debt cache is aware of the new sUSD issued
//            debtCache().updateCachedsUSDDebt(SafeCast.toInt256(amountOfsUSD));
//            _synthRedeemer.deprecate(IERC20(address(Proxyable(address(synthToRemove)).proxy())), rateToRedeem);
        }

        // Remove the synth from the availableSynths array.
        for (uint i = 0; i < availableLTokens.length; i++) {
            if (address(availableLTokens[i]) == lTokenToRemove) {
                delete availableLTokens[i];

                // Copy the last synth into the place of the one we just deleted
                // If there's only one synth, this is synths[0] = synths[0].
                // If we're deleting the last one, it's also a NOOP in the same way.
                availableLTokens[i] = availableLTokens[availableLTokens.length - 1];

                // Decrease the size of the array by one.
                availableLTokens.pop();

                break;
            }
        }

        // And remove it from the synths mapping
        delete lTokensByAddress[lTokenToRemove];
        delete lTokens[currencyKey];
        delete lTokensForSettleToken[ILiquidityToken(lTokenToRemove).settleTokenKey()];

        emit LiquidityTokenRemoved(currencyKey, lTokenToRemove);
    }

    function removeLToken(bytes32 currencyKey) external onlyOwner {
        _removeLToken(currencyKey);
    }

    function removeLTokens(bytes32[] calldata currencyKeys) external onlyOwner {
        uint numKeys = currencyKeys.length;

        for (uint i = 0; i < numKeys; i++) {
            _removeLToken(currencyKeys[i]);
        }
    }

    function mintLiquidityTokens(
        bytes32 currencyKey,
        address destAccount,
        uint amountOfSettleToken
    ) external lock onlyRouter override returns (uint){
        ILiquidityToken token = lTokens[currencyKey];

        require(token != ILiquidityToken(address(0)), "LToken doest not exist.");

        address settleTokenAddress = token.settleTokenAddress();

        uint settleTokenDecimals = IERC20(settleTokenAddress).decimals();

        _issueLTokens(token, destAccount, amountOfSettleToken * 10**(18 - settleTokenDecimals));

        return amountOfSettleToken;
    }

    function burnLiquidityTokens(
        bytes32 currencyKey,
        address destAccount,
        uint amountOfLTokenToBurn
        ) external lock onlyRouter override returns(uint256, uint256){
        ILiquidityToken token = lTokens[currencyKey];

        (uint256 amountOfSettleTokenToReceive, uint256 amountOfLTokenShouldBurn) = _calculateAmountOfSettleTokenToReceive(currencyKey, amountOfLTokenToBurn);

        _burnLTokens(token, address(this), amountOfLTokenShouldBurn);

        token.transferSettleToken(destAccount, amountOfSettleTokenToReceive);

        return (amountOfSettleTokenToReceive, amountOfLTokenShouldBurn);
    }

    /* ========== INTERNAL FUNCTIONS ========== */
    function _issueLTokens(
        ILiquidityToken token,
        address destAccount,
        uint amountOfSettleTokenToAdd
    ) internal {
        token.issue(destAccount, amountOfSettleTokenToAdd);
    }

    function _burnLTokens(
        ILiquidityToken token,
        address sourceAccount,
        uint amountOfLTokenToBurn
     ) internal returns (bool) {
        require(token.burn(sourceAccount, amountOfLTokenToBurn), "CBBC: Burning liquidityToken failed.");

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

    event LiquidityTokenAdded(bytes32 currencyKey, address lToken);
    event LiquidityTokenRemoved(bytes32 currencyKey, address lToken);
}
