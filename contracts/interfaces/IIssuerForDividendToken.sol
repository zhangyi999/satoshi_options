pragma solidity >=0.4.24;

import "../interfaces/IDividendToken.sol";

// https://docs.synthetix.io/contracts/source/interfaces/iissuer
interface IIssuerForDividendToken {
    // Views
    function getAvailableDTokens() external view returns (IDividendToken[] memory);

    function availableDTokenKeys() external view returns (bytes32[] memory);

    function dTokens(bytes32 key) external view returns (IDividendToken);

    function dTokensByAddress(address cTokenAddress) external view returns (bytes32);

    function getDTokensByKeys(bytes32[] calldata currencyKeys) external view returns (IDividendToken[] memory);

    function dTokensForSettleToken(bytes32 settleTokenKey) external view returns (IDividendToken);

    function availableDTokenCount() external view returns (uint);

    function availableDToken(uint index) external view returns (IDividendToken);

/*
    function issuedCTokens(bytes32 currencyKey) external view returns (uint);

    function totalIssuedCTokens(bytes32 currencyKey) external view returns (uint);
*/
    // Restricted: used internally to Synthetix
    function mintDividendTokens(
        bytes32 currencyKey,
        address from,
        uint amountOfCharmToBurn
    ) external returns (uint);

}
