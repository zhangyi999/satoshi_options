pragma solidity =0.8.3;

interface ICbbcCallee {
    function cbbcCall(address sender, uint amount0, uint amount1, bytes calldata data) external;
}
