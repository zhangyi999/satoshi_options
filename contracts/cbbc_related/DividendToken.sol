pragma solidity 0.8.3;

// Inheritance
import "./BaseToken.sol";

// Internal references
import "./interfaces/IIssuerForDividendToken.sol";
import "./interfaces/IDividendToken.sol";
import "./interfaces/ISystemStatus.sol";

// https://docs.synthetix.io/contracts/source/contracts/synth
contract DividendToken is BaseToken, IDividendToken {
    bytes32 public constant CONTRACT_NAME = "DividendToken";

    /* ========== STATE VARIABLES ========== */

    // Currency key which identifies this Synth to the Synthetix system
    bytes32 public override settleTokenKey;

    uint256 public override burnedCharm;

    /* ========== ADDRESS RESOLVER CONFIGURATION ========== */
    bytes32 private constant CONTRACT_ISSUER = "IssuerForDividendToken";
    bytes32 private constant CONTRACT_SYSTEMSTATUS = "SystemStatus";

    /* ========== CONSTRUCTOR ========== */

    constructor(
        address payable _proxy,
        TokenState _tokenState,
        string memory _tokenName,
        string memory _tokenSymbol,
        address _owner,
        bytes32 _currencyKey,
        bytes32 _settleTokeKey,
        uint _totalSupply,
        address _resolver
    ) BaseToken(_proxy, _tokenState, _tokenName, _tokenSymbol, _owner, _currencyKey, _totalSupply, _resolver){
        settleTokenKey = _settleTokeKey;
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    function issue(address account, uint amount, uint _burnedCharm) external override onlyInternalContracts {
        burnedCharm += _burnedCharm;
        _internalIssue(account, amount);
    }

    function burn(address account, uint amount, uint _burnedCharm) external override onlyInternalContracts returns(bool) {
        burnedCharm -= _burnedCharm;

        return _internalBurn(account, amount);
    }

    // Allow owner to set the burned Charm on import.
    function setBurnedCharm(uint amount) external optionalProxy_onlyOwner {
        burnedCharm = amount;
    }

    /* ========== VIEWS ========== */

    // Note: use public visibility so that it can be invoked in a subclass
    function resolverAddressesRequired() public pure override returns (bytes32[] memory addresses) {
        addresses = new bytes32[](2);
        addresses[0] = CONTRACT_SYSTEMSTATUS;
        addresses[1] = CONTRACT_ISSUER;
    }

    function systemStatus() internal view returns (ISystemStatus) {
        return ISystemStatus(requireAndGetAddress(CONTRACT_SYSTEMSTATUS));
    }

    function issuer() internal view returns (IIssuerForDividendToken) {
        return IIssuerForDividendToken(requireAndGetAddress(CONTRACT_ISSUER));
    }

    function settleTokenAddress() public view override returns (address) {
        return resolver.requireAndGetAddress(settleTokenKey, "CbbcToken: settleToken does not exist");
    }


    /* ========== MODIFIERS ========== */

    modifier onlyInternalContracts() {
        bool isIssuer = msg.sender == address(issuer());

        require(isIssuer, "Only Issuer contracts allowed");
        _;
    }

}
