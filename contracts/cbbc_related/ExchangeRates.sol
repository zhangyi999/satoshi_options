pragma solidity 0.8.3;

// Inheritance
import "./Owned.sol";
import "./MixinResolver.sol";
import "./MixinSystemSettings.sol";
import "./interfaces/IExchangeRates.sol";

// Libraries
import "./libraries/SafeDecimalMath.sol";

// Internal references
// AggregatorInterface from Chainlink represents a decentralized pricing network for a single currency key
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV2V3Interface.sol";
// FlagsInterface from Chainlink addresses SIP-76
import "@chainlink/contracts/src/v0.8/interfaces/FlagsInterface.sol";
//import "./interfaces/IExchanger.sol";

// https://docs.synthetix.io/contracts/source/contracts/exchangerates
contract ExchangeRates is Owned, MixinSystemSettings, IExchangeRates {
    using SafeDecimalMath for uint256;

    bytes32 public constant CONTRACT_NAME = "ExchangeRates";

    // Exchange rates and update times stored by currency code, e.g. 'SNX', or 'sUSD'
    mapping(bytes32 => mapping(uint => RateAndUpdatedTime)) private _rates;

    // The address of the oracle which pushes rate updates to this contract
//    address public override oracle;

    // Decentralized oracle networks that feed into pricing aggregators
    mapping(bytes32 => AggregatorV2V3Interface) public override aggregators;

    mapping(bytes32 => uint8) public currencyKeyDecimals;

    mapping(bytes32 => uint) public override currentRoundForRate;

    // List of aggregator keys for convenient iteration
    bytes32[] public aggregatorKeys;

    // Do not allow the oracle to submit times any further forward into the future than this constant.
    uint private constant ORACLE_FUTURE_LIMIT = 10 minutes;


    /* ========== ADDRESS RESOLVER CONFIGURATION ========== */
      bytes32 private constant CONTRACT_MARKET_ORACLE = "MarketOracle";

    //
    // ========== CONSTRUCTOR ==========

    constructor(
        address _owner,
        address _resolver,
        bytes32[] memory _currencyKeys,
        uint[] memory _newRates
    ) Owned(_owner) MixinSystemSettings(_resolver) {
        require(_currencyKeys.length == _newRates.length, "Currency key length and rate length must match.");

        internalUpdateRates(_currencyKeys, _newRates, block.timestamp);
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    function updateRate(
        bytes32 currencyKey,
        uint newRate,
        uint timeSent
    ) external override onlyOracle returns (bool) {
        return internalUpdateRate(currencyKey, newRate, timeSent);
    }

    function updateRates(
        bytes32[] calldata currencyKeys,
        uint[] calldata newRates,
        uint timeSent
    ) external override onlyOracle returns (bool) {
        return internalUpdateRates(currencyKeys, newRates, timeSent);
    }

    function deleteRate(bytes32 currencyKey) external override onlyOracle {
        require(_getRate(currencyKey) > 0, "Rate is zero");

        delete _rates[currencyKey][currentRoundForRate[currencyKey]];

        currentRoundForRate[currencyKey]--;

        emit RateDeleted(currencyKey);
    }

    function addAggregator(bytes32 currencyKey, address aggregatorAddress) external override onlyOwner {
        AggregatorV2V3Interface aggregator = AggregatorV2V3Interface(aggregatorAddress);
        // This check tries to make sure that a valid aggregator is being added.
        // It checks if the aggregator is an existing smart contract that has implemented `latestTimestamp` function.

        require(aggregator.latestRound() >= 0, "Given Aggregator is invalid");
        uint8 decimals = aggregator.decimals();
        require(decimals <= 18, "Aggregator decimals should be lower or equal to 18");
        if (address(aggregators[currencyKey]) == address(0)) {
            aggregatorKeys.push(currencyKey);
        }
        aggregators[currencyKey] = aggregator;
        currencyKeyDecimals[currencyKey] = decimals;
        emit AggregatorAdded(currencyKey, address(aggregator));
    }

    function removeAggregator(bytes32 currencyKey) external override onlyOwner {
        address aggregator = address(aggregators[currencyKey]);
        require(aggregator != address(0), "No aggregator exists for key");
        delete aggregators[currencyKey];
        delete currencyKeyDecimals[currencyKey];

        bool wasRemoved = removeFromArray(currencyKey, aggregatorKeys);

        if (wasRemoved) {
            emit AggregatorRemoved(currencyKey, aggregator);
        }
    }

    /* ========== VIEWS ========== */

    function resolverAddressesRequired() public view override returns (bytes32[] memory addresses) {
        bytes32[] memory existingAddresses = MixinSystemSettings.resolverAddressesRequired();
        bytes32[] memory newAddresses = new bytes32[](1);
        newAddresses[0] = CONTRACT_MARKET_ORACLE;
        addresses = combineArrays(existingAddresses, newAddresses);
    }

    function marketOracle() internal view returns (address) {
        return requireAndGetAddress(CONTRACT_MARKET_ORACLE);
    }

    function currenciesUsingAggregator(address aggregator) external view override returns (bytes32[] memory currencies) {
        uint count = 0;
        currencies = new bytes32[](aggregatorKeys.length);
        for (uint i = 0; i < aggregatorKeys.length; i++) {
            bytes32 currencyKey = aggregatorKeys[i];
            if (address(aggregators[currencyKey]) == aggregator) {
                currencies[count++] = currencyKey;
            }
        }
    }

    function rateStalePeriod() external view override returns (uint) {
        return getRateStalePeriod();
    }

    function aggregatorWarningFlags() external view override returns (address) {
        return getAggregatorWarningFlags();
    }

    function rateAndUpdatedTime(bytes32 currencyKey) external view override returns (uint rate, uint time) {
        RateAndUpdatedTime memory rateAndTime = _getRateAndUpdatedTime(currencyKey);
        return (rateAndTime.rate, rateAndTime.time);
    }

    function getLastRoundIdBeforeElapsedSecs(
        bytes32 currencyKey,
        uint startingRoundId,
        uint startingTimestamp,
        uint timediff
    ) external view override returns (uint) {
        uint roundId = startingRoundId;
        uint nextTimestamp = 0;
        while (true) {
            (, nextTimestamp) = _getRateAndTimestampAtRound(currencyKey, roundId + 1);
            // if there's no new round, then the previous roundId was the latest
            if (nextTimestamp == 0 || nextTimestamp > startingTimestamp + timediff) {
                return roundId;
            }
            roundId++;
        }
        return roundId;
    }

    function getCurrentRoundId(bytes32 currencyKey) external view override returns (uint) {
        return _getCurrentRoundId(currencyKey);
    }

    function rateAndTimestampAtRound(bytes32 currencyKey, uint roundId) external view override returns (uint rate, uint time) {
        return _getRateAndTimestampAtRound(currencyKey, roundId);
    }

    function lastRateUpdateTimes(bytes32 currencyKey) external view override returns (uint256) {
        return _getUpdatedTime(currencyKey);
    }

    function lastRateUpdateTimesForCurrencies(bytes32[] calldata currencyKeys) external view returns (uint[] memory) {
        uint[] memory lastUpdateTimes = new uint[](currencyKeys.length);

        for (uint i = 0; i < currencyKeys.length; i++) {
            lastUpdateTimes[i] = _getUpdatedTime(currencyKeys[i]);
        }

        return lastUpdateTimes;
    }

    function rateForCurrency(bytes32 currencyKey) external view override returns (uint) {
        return _getRateAndUpdatedTime(currencyKey).rate;
    }

    function ratesAndUpdatedTimeForCurrencyLastNRounds(bytes32 currencyKey, uint numRounds)
        external
        view
        override
        returns (uint[] memory rates, uint[] memory times)
    {
        rates = new uint[](numRounds);
        times = new uint[](numRounds);

        uint roundId = _getCurrentRoundId(currencyKey);
        for (uint i = 0; i < numRounds; i++) {
            // fetch the rate and treat is as current, so inverse limits if frozen will always be applied
            // regardless of current rate
            (rates[i], times[i]) = _getRateAndTimestampAtRound(currencyKey, roundId);

            if (roundId == 0) {
                // if we hit the last round, then return what we have
                return (rates, times);
            } else {
                roundId--;
            }
        }
    }

    function ratesForCurrencies(bytes32[] calldata currencyKeys) external view override returns (uint[] memory) {
        uint[] memory _localRates = new uint[](currencyKeys.length);

        for (uint i = 0; i < currencyKeys.length; i++) {
            _localRates[i] = _getRate(currencyKeys[i]);
        }

        return _localRates;
    }

    function rateAndInvalid(bytes32 currencyKey) external view override returns (uint rate, bool isInvalid) {
        RateAndUpdatedTime memory rateAndTime = _getRateAndUpdatedTime(currencyKey);

        return (
            rateAndTime.rate,
            _rateIsStaleWithTime(getRateStalePeriod(), rateAndTime.time) ||
                _rateIsFlagged(currencyKey, FlagsInterface(getAggregatorWarningFlags()))
        );
    }

    function ratesAndInvalidForCurrencies(bytes32[] calldata currencyKeys)
        external
        view
        override
        returns (uint[] memory rates, bool anyRateInvalid)
    {
        rates = new uint[](currencyKeys.length);

        uint256 _rateStalePeriod = getRateStalePeriod();

        // fetch all flags at once
        bool[] memory flagList = getFlagsForRates(currencyKeys);

        for (uint i = 0; i < currencyKeys.length; i++) {
            // do one lookup of the rate & time to minimize gas
            RateAndUpdatedTime memory rateEntry = _getRateAndUpdatedTime(currencyKeys[i]);
            rates[i] = rateEntry.rate;
            if (!anyRateInvalid) {
                anyRateInvalid = flagList[i] || _rateIsStaleWithTime(_rateStalePeriod, rateEntry.time);
            }
        }
    }

    function rateIsStale(bytes32 currencyKey) external view  override returns (bool) {
        return _rateIsStale(currencyKey, getRateStalePeriod());
    }

    function rateIsInvalid(bytes32 currencyKey) external view override returns (bool) {
        return
            _rateIsStale(currencyKey, getRateStalePeriod()) ||
            _rateIsFlagged(currencyKey, FlagsInterface(getAggregatorWarningFlags()));
    }

    function rateIsFlagged(bytes32 currencyKey) external view override returns (bool) {
        return _rateIsFlagged(currencyKey, FlagsInterface(getAggregatorWarningFlags()));
    }

    function anyRateIsInvalid(bytes32[] calldata currencyKeys) external view override returns (bool) {
        // Loop through each key and check whether the data point is stale.

        uint256 _rateStalePeriod = getRateStalePeriod();
        bool[] memory flagList = getFlagsForRates(currencyKeys);

        for (uint i = 0; i < currencyKeys.length; i++) {
            if (flagList[i] || _rateIsStale(currencyKeys[i], _rateStalePeriod)) {
                return true;
            }
        }

        return false;
    }

    /* ========== INTERNAL FUNCTIONS ========== */
    function getFlagsForRates(bytes32[] memory currencyKeys) internal view returns (bool[] memory flagList) {
        FlagsInterface _flags = FlagsInterface(getAggregatorWarningFlags());

        // fetch all flags at once
        if (_flags != FlagsInterface(address(0))) {
            address[] memory _aggregators = new address[](currencyKeys.length);

            for (uint i = 0; i < currencyKeys.length; i++) {
                _aggregators[i] = address(aggregators[currencyKeys[i]]);
            }

            flagList = _flags.getFlags(_aggregators);
        } else {
            flagList = new bool[](currencyKeys.length);
        }
    }

    function _setRate(
        bytes32 currencyKey,
        uint256 rate,
        uint256 time
    ) internal {
        // Note: this will effectively start the rounds at 1, which matches Chainlink's Agggregators
        currentRoundForRate[currencyKey]++;

        _rates[currencyKey][currentRoundForRate[currencyKey]] = RateAndUpdatedTime({
            rate: uint216(rate),
            time: uint40(time)
        });
    }
    function internalUpdateRate(
        bytes32 currencyKey,
        uint newRate,
        uint timeSent
    ) internal returns (bool) {
        require(timeSent < (block.timestamp + ORACLE_FUTURE_LIMIT), "Time is too far into the future");

        require(newRate != 0, "Zero is not a valid rate, please call deleteRate instead.");

            // We should only update the rate if it's at least the same age as the last rate we've got.
        if (timeSent < _getUpdatedTime(currencyKey)) {
            return false;
        }
            // Ok, go ahead with the update.
        _setRate(currencyKey, newRate, timeSent);

        emit RateUpdated(currencyKey, newRate);

        return true;
    }

    function internalUpdateRates(
        bytes32[] memory currencyKeys,
        uint[] memory newRates,
        uint timeSent
    ) internal returns (bool) {
        require(currencyKeys.length == newRates.length, "Currency key array length must match rates array length.");
        require(timeSent < (block.timestamp + ORACLE_FUTURE_LIMIT), "Time is too far into the future");

        // Loop through each key and perform update.
        for (uint i = 0; i < currencyKeys.length; i++) {
            bytes32 currencyKey = currencyKeys[i];

            // Should not set any rate to zero ever, as no asset will ever be
            // truely worthless and still valid. In this scenario, we should
            // delete the rate and remove it from the system.
            require(newRates[i] != 0, "Zero is not a valid rate, please call deleteRate instead.");

            // We should only update the rate if it's at least the same age as the last rate we've got.
            if (timeSent < _getUpdatedTime(currencyKey)) {
                continue;
            }

            // Ok, go ahead with the update.
            _setRate(currencyKey, newRates[i], timeSent);
        }

        emit RatesUpdated(currencyKeys, newRates);

        return true;
    }

    function removeFromArray(bytes32 entry, bytes32[] storage array) internal returns (bool) {
        for (uint i = 0; i < array.length; i++) {
            if (array[i] == entry) {
                delete array[i];

                // Copy the last key into the place of the one we just deleted
                // If there's only one key, this is array[0] = array[0].
                // If we're deleting the last one, it's also a NOOP in the same way.
                array[i] = array[array.length - 1];

                // Decrease the size of the array by one.
                array.pop();

                return true;
            }
        }
        return false;
    }

    function _formatAggregatorAnswer(bytes32 currencyKey, int256 rate) internal view returns (uint) {
        require(rate >= 0, "Negative rate not supported");
        if (currencyKeyDecimals[currencyKey] > 0) {
            uint multiplier = 10**uint(18- currencyKeyDecimals[currencyKey]);
            return uint(uint(rate) * multiplier);
        }
        return uint(rate);
    }

    function _getRateAndUpdatedTime(bytes32 currencyKey) internal view returns (RateAndUpdatedTime memory) {
        AggregatorV2V3Interface aggregator = aggregators[currencyKey];

        if (aggregator != AggregatorV2V3Interface(address(0))) {
            // this view from the aggregator is the most gas efficient but it can throw when there's no data,
            // so let's call it low-level to suppress any reverts
            bytes memory payload = abi.encodeWithSignature("latestRoundData()");
            // solhint-disable avoid-low-level-calls
            (bool success, bytes memory returnData) = address(aggregator).staticcall(payload);

            if (success) {
                (uint80 roundId, int256 answer, , uint256 updatedAt, ) =
                    abi.decode(returnData, (uint80, int256, uint256, uint256, uint80));
                return
                    RateAndUpdatedTime({
                        rate: uint216(_formatAggregatorAnswer(currencyKey, answer)),
                        time: uint40(updatedAt)
                    });
            }
        } else {
            uint roundId = currentRoundForRate[currencyKey];
            RateAndUpdatedTime memory entry = _rates[currencyKey][roundId];

            return RateAndUpdatedTime({rate: uint216(entry.rate), time: entry.time});
        }
    }

    function _getCurrentRoundId(bytes32 currencyKey) internal view returns (uint) {
        AggregatorV2V3Interface aggregator = aggregators[currencyKey];

        if (aggregator != AggregatorV2V3Interface(address(0))) {
            return aggregator.latestRound();
        } else {
            return currentRoundForRate[currencyKey];
        }
    }

    function _getRateAndTimestampAtRound(bytes32 currencyKey, uint roundId) internal view returns (uint rate, uint time) {
        AggregatorV2V3Interface aggregator = aggregators[currencyKey];

        if (aggregator != AggregatorV2V3Interface(address(0))) {
            // this view from the aggregator is the most gas efficient but it can throw when there's no data,
            // so let's call it low-level to suppress any reverts
            bytes memory payload = abi.encodeWithSignature("getRoundData(uint80)", roundId);
            // solhint-disable avoid-low-level-calls
            (bool success, bytes memory returnData) = address(aggregator).staticcall(payload);

            if (success) {
                (, int256 answer, , uint256 updatedAt, ) =
                    abi.decode(returnData, (uint80, int256, uint256, uint256, uint80));
                return (_formatAggregatorAnswer(currencyKey, answer), updatedAt);
            }
        } else {
            RateAndUpdatedTime memory update = _rates[currencyKey][roundId];
            return (update.rate, update.time);
        }
    }

    function _getRate(bytes32 currencyKey) internal view returns (uint256) {
        return _getRateAndUpdatedTime(currencyKey).rate;
    }

    function _getUpdatedTime(bytes32 currencyKey) internal view returns (uint256) {
        return _getRateAndUpdatedTime(currencyKey).time;
    }


    function _rateIsStale(bytes32 currencyKey, uint _rateStalePeriod) internal view returns (bool) {
        // sUSD is a special case and is never stale (check before an SLOAD of getRateAndUpdatedTime)

        return _rateIsStaleWithTime(_rateStalePeriod, _getUpdatedTime(currencyKey));
    }

    function _rateIsStaleWithTime(uint _rateStalePeriod, uint _time) internal view returns (bool) {
        return _time + _rateStalePeriod < block.timestamp;
    }


    function _rateIsFlagged(bytes32 currencyKey, FlagsInterface flags) internal view returns (bool) {

        address aggregator = address(aggregators[currencyKey]);
        // when no aggregator or when the flags haven't been setup
        if (aggregator == address(0) || flags == FlagsInterface(address(0))) {
            return false;
        }
        return flags.getFlag(aggregator);
    }

    /* ========== MODIFIERS ========== */

    modifier onlyOracle {
        _onlyOracle();
        _;
    }

    function _onlyOracle() internal view {
        require(msg.sender == marketOracle(), "Only the oracle can perform this action");
    }

    /* ========== EVENTS ========== */

    event OracleUpdated(address newOracle);
    event RatesUpdated(bytes32[] currencyKeys, uint[] newRates);
    event RateUpdated(bytes32 currencyKey, uint newRate);
    event RateDeleted(bytes32 currencyKey);
    event AggregatorAdded(bytes32 currencyKey, address aggregator);
    event AggregatorRemoved(bytes32 currencyKey, address aggregator);
}
