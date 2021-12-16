pragma solidity >=0.4.24;

import "./ILiquidityToken.sol";

// https://docs.synthetix.io/contracts/source/interfaces/iissuer
interface IIssuerForLiquidityToken {
    // Views

    function getAvailableLTokens() external view returns (ILiquidityToken[] memory);

    function availableLTokenKeys() external view returns (bytes32[] memory);

    function lTokens(bytes32 key) external view returns (ILiquidityToken);

    function lTokensByAddress(address cTokenAddress) external view returns (bytes32);

    function getLTokensByKeys(bytes32[] calldata currencyKeys) external view returns (ILiquidityToken[] memory);

    function lTokensForSettleToken(bytes32 settleTokenKey) external view returns (ILiquidityToken);

    function availableLTokenCount() external view returns (uint);

    function availableLToken(uint index) external view returns (ILiquidityToken);

/*
    function issuedCTokens(bytes32 currencyKey) external view returns (uint);

    function totalIssuedCTokens(bytes32 currencyKey) external view returns (uint);
*/
    // Restricted: used internally to Synthetix
    function mintLiquidityTokens(
        bytes32 currencyKey,
        address destAccount,
        uint amountOfCharmToBurn
    ) external returns (uint);

    function burnLiquidityTokens(
        bytes32 currencyKey,
        address destAccount,
        uint amountOfDTokenToBurn
        ) external returns(uint256);
}
