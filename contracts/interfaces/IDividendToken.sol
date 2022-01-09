pragma solidity >=0.4.24;

// https://docs.synthetix.io/contracts/source/interfaces/isynth
interface IDividendToken {

    function settleTokenKey() external view returns (bytes32);

    function settleTokenAddress() external view returns (address);

    function burnedCharm() external view returns (uint256);

    // Restricted: used internally to Synthetix
    function burn(address account, uint amount, uint _burnedCharm) external returns (bool);

    function issue(address account, uint amount, uint _burnedCharm) external;
}
