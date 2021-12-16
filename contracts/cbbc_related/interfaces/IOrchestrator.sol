pragma solidity 0.8.3;

import "./ICbbcToken.sol";

interface IOrchestrator {
    function rebase(ICbbcToken) external;
}