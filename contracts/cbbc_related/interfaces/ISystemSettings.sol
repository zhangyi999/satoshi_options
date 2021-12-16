pragma solidity >=0.4.24;

// https://docs.synthetix.io/contracts/source/interfaces/isystemsettings
interface ISystemSettings {
    // Views
    function priceDeviationThresholdFactor() external view returns (uint);

    function rateStalePeriod() external view returns (uint);

    function aggregatorWarningFlags() external view returns (address);

    // ================
    function rebaseLag() external view returns (uint) ;

    function minRebaseTimeIntervalSec() external view returns (uint) ;

    function rebaseWindowOffsetSec() external view returns (uint) ;

    function rebaseWindowLengthSec() external view returns (uint);

    function deviationThreshold() external view returns (uint) ;

    function alphaForBuy() external view returns (uint);

    function alphaForSell() external view returns (uint);

    function upperRebaseThreshold() external view returns (uint);

    function lowerRebaseThreshold() external view returns (uint);

}
