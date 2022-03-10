pragma solidity 0.8.3;

// https://docs.synthetix.io/contracts/source/interfaces/isynth
interface ICharmToken{

    // Views
//    function approve(address spender, uint value) external returns (bool);
    // Restricted: used internally to Synthetix
    function burn(address account, uint amount) external returns (bool);
    function issue(address account, uint amount) external;
    function mint(address _to, uint256 _amount) external;
}
