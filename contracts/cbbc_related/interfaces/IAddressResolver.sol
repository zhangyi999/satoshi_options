pragma solidity >=0.4.24;

// https://docs.synthetix.io/contracts/source/interfaces/iaddressresolver
interface IAddressResolver {
    function getAddress(bytes32 name) external view returns (address);

    function getCbbcTokenAddress(bytes32 key) external view returns (address);

    function getDividendTokenAddress(bytes32 key) external view returns (address) ;

    function getLiquidityTokenAddress(bytes32 key) external view returns (address);

    function requireAndGetAddress(bytes32 name, string calldata reason) external view returns (address);
}
