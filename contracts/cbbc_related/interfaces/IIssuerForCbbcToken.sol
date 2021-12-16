pragma solidity >=0.4.24;

import "./ICbbcToken.sol";

// https://docs.synthetix.io/contracts/source/interfaces/iissuer
interface IIssuerForCbbcToken {
    // Views

    function getAvailableCTokens() external view returns (ICbbcToken[] memory);

    function availableCTokenKeys() external view returns (bytes32[] memory);

    function cTokens(bytes32 key) external view returns (ICbbcToken);

    function cTokensByAddress(address cTokenAddress) external view returns (bytes32);

    function getCTokens(bytes32, bytes32, uint8, ICbbcToken.CbbcType) external view returns (ICbbcToken);

    function getCTokensByKeys(bytes32[] calldata currencyKeys) external view returns (ICbbcToken[] memory);

    function cTokenKeysForSettleToken(bytes32 settleTokenKey) external view returns (bytes32[] memory);

    function availableCTokenCount() external view returns (uint);

    function availableCToken(uint index) external view returns (ICbbcToken);

    function issuedCTokens(bytes32 currencyKey) external view returns (uint);

    function totalIssuedCTokens(bytes32 currencyKey) external view returns (uint);

    function claimableProfits(bytes32 settleTokenKey) external view returns (uint);

    function getPurchaseCost(bytes32 cToken, address account) external view returns (uint);

    // Restricted: used internally to Synthetix
    function mintCbbc(bytes32, address from, uint amount) external returns(uint cbbcAmount);

    function burnCbbc(bytes32, address from, uint amount) external returns(uint settleAmount);

}
