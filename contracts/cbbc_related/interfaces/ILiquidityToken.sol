pragma solidity >=0.4.24;

// https://docs.synthetix.io/contracts/source/interfaces/isynth
interface ILiquidityToken{

    // Views
//    function approve(address spender, uint value) external returns (bool);

    function settleTokenKey() external view returns (bytes32);

    function initialSupply() external view returns (uint);

    function settleTokenAddress() external view returns (address);

    // Restricted: used internally to Synthetix
    function burn(address account, uint amount) external returns (bool);

    function issue(address account, uint amount) external;

    function transferSettleToken(address to, uint256 value) external;
}
