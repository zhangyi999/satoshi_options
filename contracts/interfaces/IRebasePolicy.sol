pragma solidity 0.8.3;

interface IRebasePolicy{
    function cTokenKey() external view returns(bytes32);
    function rebase() external;
}