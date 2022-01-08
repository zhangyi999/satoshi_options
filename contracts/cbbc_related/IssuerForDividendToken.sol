pragma solidity 0.8.3;

// Inheritance
import "./Owned.sol";
//import "./MixinResolver.sol";
import "./MixinSystemSettings.sol";
//import "./ExternStateToken.sol";

// Libraries
//import "./libraries/SafeCast.sol";
import "./libraries/SafeDecimalMath.sol";

// Internal references
import "./interfaces/ISystemStatus.sol";
import "./interfaces/IIssuerForDividendToken.sol";
import "./interfaces/IIssuerForCbbcToken.sol";
import "./interfaces/IIssuerForLiquidityToken.sol";
import "./interfaces/ICharmToken.sol";
import "./interfaces/IBaseToken.sol";
import "./interfaces/IDividendToken.sol";
import "./interfaces/ILiquidityToken.sol";
import "./interfaces/IERC20.sol";
//import "./Proxyable.sol";
/*
interface IProxy {
    function target() external view returns (address);
}
*/
// https://docs.synthetix.io/contracts/source/contracts/issuer
contract IssuerForDividendToken is Owned, MixinSystemSettings, IIssuerForDividendToken {
    using SafeDecimalMath for uint;

    bytes32 public constant CONTRACT_NAME = "IssuerForDividendToken";

    // Available Synths which can be used with the system
    IDividendToken[] public availableDTokens;
    mapping(bytes32 => IDividendToken) public override dTokens;
    mapping(address => bytes32) public override dTokensByAddress;
    mapping(bytes32 => IDividendToken) public override dTokensForSettleToken;

    /* ========== ENCODED NAMES ========== */
    bytes32 internal constant CHARM = "CHARM";

    // Flexible storage names
//    bytes32 internal constant LAST_ISSUE_EVENT = "lastIssueEvent";

    /* ========== ADDRESS RESOLVER CONFIGURATION ========== */
    bytes32 private constant CONTRACT_SYSTEMSTATUS = "SystemStatus";
//    bytes32 private constant CONTRACT_CHARM = "CharmToken";
    bytes32 private constant CONTRACT_ROUTER = "Router";
    bytes32 private constant CONTRACT_ISSUER_FOR_CBBC_TOKEN = "IssuerForCbbcToken";
    bytes32 private constant CONTRACT_ISSUER_FOR_LIQUIDITY_TOKEN = "IssuerForLiquidityToken";

    constructor(address _owner, address _resolver) Owned(_owner) MixinSystemSettings(_resolver) {}

    /* ========== VIEWS ========== */
    function resolverAddressesRequired() public view override returns (bytes32[] memory addresses) {
        bytes32[] memory existingAddresses = MixinSystemSettings.resolverAddressesRequired();
        bytes32[] memory newAddresses = new bytes32[](5);
        newAddresses[0] = CONTRACT_SYSTEMSTATUS;
        newAddresses[1] = CHARM;
        newAddresses[2] = CONTRACT_ROUTER;
        newAddresses[3] = CONTRACT_ISSUER_FOR_CBBC_TOKEN;
        newAddresses[4] = CONTRACT_ISSUER_FOR_LIQUIDITY_TOKEN;

        return combineArrays(existingAddresses, newAddresses);
    }

    function systemStatus() internal view returns (ISystemStatus) {
        return ISystemStatus(requireAndGetAddress(CONTRACT_SYSTEMSTATUS));
    }

    function charm() internal view returns (ICharmToken) {
        return ICharmToken(requireAndGetAddress(CHARM));
    }

    function router() internal view returns (address) {
        return requireAndGetAddress(CONTRACT_ROUTER);
    }

    function issuerForCbbcToken() internal view returns (IIssuerForCbbcToken) {
        return IIssuerForCbbcToken(requireAndGetAddress(CONTRACT_ISSUER_FOR_CBBC_TOKEN));
    }

    function issuerForLiquidityToken() internal view returns (IIssuerForLiquidityToken) {
        return IIssuerForLiquidityToken(requireAndGetAddress(CONTRACT_ISSUER_FOR_LIQUIDITY_TOKEN));
    }

    function _settleTokenKey(IDividendToken token) internal view returns (bytes32) {
        return token.settleTokenKey();
    }

    function _claimableProfits(bytes32 settleTokenKey) internal view returns (uint) {
        return issuerForCbbcToken().claimableProfits(settleTokenKey);
    }

    function _availableDTokenKeys() internal view returns (bytes32[] memory) {
        bytes32[] memory currencyKeys = new bytes32[](availableDTokens.length);

        for (uint i = 0; i < availableDTokens.length; i++) {
            currencyKeys[i] = dTokensByAddress[address(availableDTokens[i])];
        }

        return currencyKeys;
    }


    function availableDTokenKeys() external view override returns (bytes32[] memory) {
        return _availableDTokenKeys();
    }

    function availableDTokenCount() external view override returns (uint) {
        return availableDTokens.length;
    }

    function availableDToken(uint index) external view override returns (IDividendToken) {
        require(index < availableDTokens.length, "Length of availableLTokens is less than index");
        return availableDTokens[index];
    }


    function getDTokensByKeys(bytes32[] calldata currencyKeys) external view override returns (IDividendToken[] memory) {
        uint numKeys = currencyKeys.length;
        IDividendToken[] memory addresses = new IDividendToken[](numKeys);

        for (uint i = 0; i < numKeys; i++) {
            addresses[i] = dTokens[currencyKeys[i]];
        }

        return addresses;
    }

    function getAvailableDTokens() external view override returns (IDividendToken[] memory) {
        IDividendToken[] memory tokens = new IDividendToken[](availableDTokens.length);

        for (uint i = 0; i < availableDTokens.length; i++) {
            tokens[i] = availableDTokens[i];
        }

        return tokens;
    }

    function _isSettleTokenSuspended(bytes32 settleTokenKey) internal view returns (bool) {
        (bool suspended, ) = systemStatus().settleTokenSuspension(settleTokenKey);
        return suspended;
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    function _addDToken(IDividendToken dToken) internal {
        bytes32 currencyKey = IBaseToken(address(dToken)).currencyKey();

        require(dTokens[currencyKey] == IDividendToken(address(0)), "dToken exists");
        require(dTokensByAddress[address(dToken)] == bytes32(0), "dToken address already exists");
        require(dTokensForSettleToken[dToken.settleTokenKey()] == IDividendToken(address(0)), "dToken for this settleToken already exists");

        availableDTokens.push(dToken);
        dTokens[currencyKey] = dToken;
        dTokensByAddress[address(dToken)] = currencyKey;
        dTokensForSettleToken[dToken.settleTokenKey()] = dToken;

        emit DTokenAdded(currencyKey, address(dToken));
    }

    function addDToken(IDividendToken dToken) external onlyOwner {
        _addDToken(dToken);
    }

    function addDTokens(IDividendToken[] calldata dTokensToAdd) external onlyOwner {
        uint numSynths = dTokensToAdd.length;
        for (uint i = 0; i < numSynths; i++) {
            _addDToken(dTokensToAdd[i]);
        }
    }

    function _removeDToken(bytes32 currencyKey) internal {
        address dTokenToRemove = address(dTokens[currencyKey]);
        require(dTokenToRemove != address(0), "Synth does not exist");

        uint dTokenSupply = IERC20(dTokenToRemove).totalSupply();

        if (dTokenSupply > 0) { //TODO: what action will be taken if there is a supply?
//            ISynthRedeemer _synthRedeemer = synthRedeemer();
//            synths[sUSD].issue(address(_synthRedeemer), amountOfsUSD);
            // ensure the debt cache is aware of the new sUSD issued
//            debtCache().updateCachedsUSDDebt(SafeCast.toInt256(amountOfsUSD));
//            _synthRedeemer.deprecate(IERC20(address(Proxyable(address(synthToRemove)).proxy())), rateToRedeem);
        }

        // Remove the synth from the availableSynths array.
        for (uint i = 0; i < availableDTokens.length; i++) {
            if (address(availableDTokens[i]) == dTokenToRemove) {
                delete availableDTokens[i];

                // Copy the last synth into the place of the one we just deleted
                // If there's only one synth, this is synths[0] = synths[0].
                // If we're deleting the last one, it's also a NOOP in the same way.
                availableDTokens[i] = availableDTokens[availableDTokens.length - 1];

                // Decrease the size of the array by one.
                availableDTokens.pop();

                break;
            }
        }

        // And remove it from the synths mapping
        delete dTokensByAddress[dTokenToRemove];
        delete dTokens[currencyKey];
        delete dTokensForSettleToken[IDividendToken(dTokenToRemove).settleTokenKey()];

        emit DTokenRemoved(currencyKey, dTokenToRemove);
    }

    function removeDToken(bytes32 currencyKey) external onlyOwner {
        _removeDToken(currencyKey);
    }

    function removeDTokens(bytes32[] calldata currencyKeys) external onlyOwner {
        uint numKeys = currencyKeys.length;

        for (uint i = 0; i < numKeys; i++) {
            _removeDToken(currencyKeys[i]);
        }
    }

    function mintDividendTokens(
        bytes32 currencyKey,
        address to,
        uint amountOfCharmToBurn
    ) external lock onlyRouter override returns (uint){
        IDividendToken dToken = dTokens[currencyKey];

        require(dToken != IDividendToken(address(0)), "dToken doest not exist.");

        return _issueDTokens(dToken, to, amountOfCharmToBurn);
    }

    function burnDividendTokens(
        bytes32 currencyKey,
        address from,
        uint amountOfDTokenToBurn
        ) external lock onlyRouter override returns(uint256){
        IDividendToken dToken = dTokens[currencyKey];

        return _burnDTokens(dToken, from, amountOfDTokenToBurn);
    }

    /* ========== INTERNAL FUNCTIONS ========== */
    function _issueDTokens(
        IDividendToken dToken,
        address destAccount,
        uint amountOfCharmToBurn
    ) internal returns (uint) {
        uint256 totalSupplyOfCharm = IERC20(address(charm())).totalSupply();

        uint256 burnedCharm = dToken.burnedCharm();

        uint256 amountOfDToken = amountOfCharmToBurn.divideDecimal(totalSupplyOfCharm + burnedCharm);

        bool success = charm().burn(address(this), amountOfCharmToBurn);
        require(success, "Failed to burn Charm.");

        dToken.issue(destAccount, amountOfDToken, amountOfCharmToBurn);

        return amountOfDToken;
    }

    function _burnDTokens(
        IDividendToken dToken,
       address destAccount,
        uint amountOfDTokenToBurn
     ) internal returns (uint profitsClaimed) {
         bytes32 settleTokenKey = dToken.settleTokenKey();

         bool isTradeTokenSuspended = _isSettleTokenSuspended(settleTokenKey);

         uint256 claimableProfits = _claimableProfits(settleTokenKey);

         uint256 shareOfDToken = amountOfDTokenToBurn.divideDecimal(IERC20(address(dToken)).totalSupply());

         uint256 amountOfCharm = dToken.burnedCharm().multiplyDecimal(shareOfDToken);

        if (isTradeTokenSuspended) {
            profitsClaimed = claimableProfits.multiplyDecimal(shareOfDToken);
        } else {
            profitsClaimed = claimableProfits.multiplyDecimal(shareOfDToken).multiplyDecimal(shareOfDToken + SafeDecimalMath.UNIT)/2;
        }

        require(profitsClaimed > 0 && profitsClaimed <= claimableProfits, "Profits claim amount must be greater than 0 and less than claimable profits.");

        ILiquidityToken lToken = issuerForLiquidityToken().lTokensForSettleToken(settleTokenKey);

        require(dToken.burn(address(this), amountOfDTokenToBurn, amountOfCharm), "CBBC: Failed to burn DToken.");

        lToken.transferSettleToken(destAccount, profitsClaimed);

    }


    /* ========== MODIFIERS ========== */
    function _onlyRouter() internal view {
        require(msg.sender == router(), "Issuer: Only the router contract can perform this action");
    }

    modifier onlyRouter() {
        _onlyRouter(); // Use an internal function to save code size.
        _;
    }

    uint private unlocked = 1;
    modifier lock() {
        require(unlocked == 1, 'CBBC: LOCKED');
        unlocked = 0;
        _;
        unlocked = 1;
    }
    /* ========== EVENTS ========== */

    event DTokenAdded(bytes32 currencyKey, address dToken);
    event DTokenRemoved(bytes32 currencyKey, address dToken);
}
