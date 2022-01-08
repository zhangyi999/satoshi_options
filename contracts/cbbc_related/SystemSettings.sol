pragma solidity 0.8.3;

// Inheritance
import "./Owned.sol";
import "./MixinResolver.sol";
import "./MixinSystemSettings.sol";
import "./interfaces/ISystemSettings.sol";

// Libraries
import "./libraries/SafeDecimalMath.sol";

// https://docs.synthetix.io/contracts/source/contracts/systemsettings
contract SystemSettings is Owned, MixinSystemSettings, ISystemSettings {
    using SafeDecimalMath for uint;

    bytes32 public constant CONTRACT_NAME = "SystemSettings";
    uint public constant MAX_CROSS_DOMAIN_GAS_LIMIT = 8e6;
    uint public constant MIN_CROSS_DOMAIN_GAS_LIMIT = 3e6;

    constructor(address _owner, address _resolver) Owned(_owner) MixinSystemSettings(_resolver) {}

    // ========== VIEWS ==========

    // SIP-65 Decentralized Circuit Breaker
    // The factor amount expressed in decimal format
    // E.g. 3e18 = factor 3, meaning movement up to 3x and above or down to 1/3x and below
    function priceDeviationThresholdFactor() external view override returns (uint) {
        return getPriceDeviationThresholdFactor();
    }

  // How long will the ExchangeRates contract assume the rate of any asset is correct
    function rateStalePeriod() external view override returns (uint) {
        return getRateStalePeriod();
    }


    function aggregatorWarningFlags() external view override returns (address) {
        return getAggregatorWarningFlags();
    }


    function crossDomainMessageGasLimit(CrossDomainMessageGasLimits gasLimitType) external view returns (uint) {
        return getCrossDomainMessageGasLimit(gasLimitType);
    }

    // ========================================================
    function rebaseLag() external view override returns (uint) {
        return getRebaseLag();
    }

    function minRebaseTimeIntervalSec() external view override returns (uint) {
        return getMinRebaseTimeIntervalSec();
    }

    function rebaseWindowOffsetSec() external view override returns (uint) {
        return getRebaseWindowOffsetSec();
    }

    function rebaseWindowLengthSec() external view override returns (uint) {
        return getRebaseWindowLengthSec();
    }

    function deviationThreshold() external view override returns (uint) {
        return getDeviationThreshold();
    }

    function alphaForBuy() external view override returns (uint) {
        return getAlphaForBuy();
    }

    function alphaForSell() external view override returns (uint) {
        return getAlphaForSell();
    }

    function upperRebaseThreshold() external view override returns (uint) {
        return getUpperRebaseThreshold();
    }

    function lowerRebaseThreshold() external view override returns (uint) {
        return getLowerRebaseThreshold();
    }

    // ========== RESTRICTED ==========

    function setCrossDomainMessageGasLimit(CrossDomainMessageGasLimits _gasLimitType, uint _crossDomainMessageGasLimit)
        external
        onlyOwner
    {
        require(
            _crossDomainMessageGasLimit >= MIN_CROSS_DOMAIN_GAS_LIMIT &&
                _crossDomainMessageGasLimit <= MAX_CROSS_DOMAIN_GAS_LIMIT,
            "Out of range xDomain gasLimit"
        );
        flexibleStorage().setUIntValue(
            SETTING_CONTRACT_NAME,
            _getGasLimitSetting(_gasLimitType),
            _crossDomainMessageGasLimit
        );
        emit CrossDomainMessageGasLimitChanged(_gasLimitType, _crossDomainMessageGasLimit);
    }

    function setPriceDeviationThresholdFactor(uint _priceDeviationThresholdFactor) external onlyOwner {
        flexibleStorage().setUIntValue(
            SETTING_CONTRACT_NAME,
            SETTING_PRICE_DEVIATION_THRESHOLD_FACTOR,
            _priceDeviationThresholdFactor
        );
        emit PriceDeviationThresholdUpdated(_priceDeviationThresholdFactor);
    }

    function setRateStalePeriod(uint period) external onlyOwner {
        flexibleStorage().setUIntValue(SETTING_CONTRACT_NAME, SETTING_RATE_STALE_PERIOD, period);

        emit RateStalePeriodUpdated(period);
    }

    function setAggregatorWarningFlags(address _flags) external onlyOwner {
        require(_flags != address(0), "Valid address must be given");
        flexibleStorage().setAddressValue(SETTING_CONTRACT_NAME, SETTING_AGGREGATOR_WARNING_FLAGS, _flags);
        emit AggregatorWarningFlagsUpdated(_flags);
    }

// ========== ========= ==========
    /**
     * @notice Sets the rebase lag parameter.
               It is used to dampen the applied supply adjustment by 1 / rebaseLag
               If the rebase lag R, equals 1, the smallest value for R, then the full supply
               correction is applied on each rebase cycle.
               If it is greater than 1, then a correction of 1/R of is applied on each rebase.
     * @param rebaseLag_ The new rebase lag parameter.
     */
    function setRebaseLag(uint256 rebaseLag_) external onlyOwner {
        require(rebaseLag_ > 0,
                    "CbbcRebasePolicy::setRebaseLag: rebaseLag must be greater than 0.");
        flexibleStorage().setUIntValue(SETTING_CONTRACT_NAME, SETTING_REBASE_LAG, rebaseLag_);
        emit SetRebaseLag(rebaseLag_);
    }

    /**
     * @notice Sets the parameters which control the timing and frequency of
     *         rebase operations.
     *         a) the minimum time period that must elapse between rebase cycles.
     *         b) the rebase window offset parameter.
     *         c) the rebase window length parameter.
     * @param minRebaseTimeIntervalSec_ More than this much time must pass between rebase
     *        operations, in seconds.
     * @param rebaseWindowOffsetSec_ The number of seconds from the beginning of
              the rebase interval, where the rebase window begins.
     * @param rebaseWindowLengthSec_ The length of the rebase window in seconds.
     */
    function setRebaseTimingParameters(
        uint256 minRebaseTimeIntervalSec_,
        uint256 rebaseWindowOffsetSec_,
        uint256 rebaseWindowLengthSec_
    ) external onlyOwner
    {
        require(minRebaseTimeIntervalSec_ > 0,
        "CbbcRebasePolicy: minRebaseTimeIntervalSec must be greater than 0.");
        require(rebaseWindowOffsetSec_ < minRebaseTimeIntervalSec_,
        "CbbcRebasePolicy: minRebaseTimeIntervalSec must be greater than rebaseWindowOffsetSec.");

        flexibleStorage().setUIntValue(SETTING_CONTRACT_NAME, SETTING_MIN_REBASE_TIME_INTERVAL_SEC, minRebaseTimeIntervalSec_);
        flexibleStorage().setUIntValue(SETTING_CONTRACT_NAME, SETTING_REBASE_WINDOW_OFFSET_SEC, rebaseWindowOffsetSec_);
        flexibleStorage().setUIntValue(SETTING_CONTRACT_NAME, SETTING_REBASE_WINDOW_LENGTH_SEC, rebaseWindowLengthSec_);

        emit SetRebaseTimingParameters(
        minRebaseTimeIntervalSec_,
        rebaseWindowOffsetSec_,
        rebaseWindowLengthSec_
        );
    }

    /**
     * @notice Changes the deviation thereshold. Currently, we intionally let deviationThreshold = 0, so that the users can rebase at any time they would like to. In the future, we may change deviationThreshold to 5%.
     * @param deviationThreshold_ The new deviationThreshold.
     */
    function setDeviationThreshold(uint deviationThreshold_) external onlyOwner{
        flexibleStorage().setUIntValue(SETTING_CONTRACT_NAME, SETTING_DEVIATION_THRESHOLD, deviationThreshold_);
        emit SetDeviationThreshold(deviationThreshold_);
    }

    function setAlphas(uint alphaForBuy_, uint alphaForSell_) external onlyOwner{
        flexibleStorage().setUIntValue(SETTING_CONTRACT_NAME, SETTING_ALPHA_FOR_BUY, alphaForBuy_);
        flexibleStorage().setUIntValue(SETTING_CONTRACT_NAME, SETTING_ALPHA_FOR_SELL, alphaForSell_);

        emit SetAlphas(alphaForBuy_, alphaForSell_);
    }

    function setRebaseThresholds(uint upperRebaseThreshold_, uint lowerRebaseThreshold_) external onlyOwner{
        flexibleStorage().setUIntValue(SETTING_CONTRACT_NAME, SETTING_UPPER_REBASE_THRESHOLD, upperRebaseThreshold_);

        flexibleStorage().setUIntValue(SETTING_CONTRACT_NAME, SETTING_LOWER_REBASE_THRESHOLD, lowerRebaseThreshold_);

        emit SetRebaseThresholds(upperRebaseThreshold_, lowerRebaseThreshold_);
    }


    // ========== EVENTS ==========
    event CrossDomainMessageGasLimitChanged(CrossDomainMessageGasLimits gasLimitType, uint newLimit);
    event PriceDeviationThresholdUpdated(uint threshold);
    event AggregatorWarningFlagsUpdated(address flags);
    event RateStalePeriodUpdated(uint rateStalePeriod);
    event SetRebaseLag(uint256 rebaseLag_);
    event SetRebaseTimingParameters(
        uint256 minRebaseTimeIntervalSec_,
        uint256 rebaseWindowOffsetSec_,
        uint256 rebaseWindowLengthSec_
    );
    event SetDeviationThreshold(uint deviationThreshold_);
    event SetAlphas(uint alphaForBuy_, uint alphaForSell_);
    event SetRebaseThresholds(uint256 upperRebaseThreshold_, uint256 lowerRebaseThreshold_);

}
