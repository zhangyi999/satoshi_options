pragma solidity 0.8.3;

// Inheritance
import "./BaseToken.sol";
import "./interfaces/ICharmToken.sol";

// Internal references
import "./interfaces/ISystemStatus.sol";
//import "./interfaces/IIssuerForCbbcToken.sol";

// https://docs.synthetix.io/contracts/source/contracts/synth
contract CharmToken is BaseToken, ICharmToken {
//    bytes32 public constant CONTRACT_NAME = "CharmToken";

    /* ========== STATE VARIABLES ========== */

    /* ========== ADDRESS RESOLVER CONFIGURATION ========== */

    bytes32 private constant CONTRACT_SYSTEMSTATUS = "SystemStatus";
    bytes32 private constant CONTRACT_ISSUER_FOR_LIQUIDITY_TOKEN = "IssuerForLiquidityToken";
    bytes32 private constant CONTRACT_ISSUER_FOR_CBBC_TOKEN = "IssuerForCbbcToken";
    bytes32 private constant CONTRACT_ISSUER_FOR_DIVIDEND_TOKEN = "IssuerForDividendToken";
    bytes32 private constant CONTRACT_ISSUER_FOR_SATOSHI = "IssuerForSatoshiToken";
    bytes32 private constant CONTRACT_MASTER_CHEF = "MasterChef";

    /* ========== CONSTRUCTOR ========== */

    constructor(
        address payable _proxy,
        TokenState _tokenState,
        //string memory _tokenName, // Charm Derivatives Platform Token
        //string memory _tokenSymbol,//Charm
        //bytes32 _currencyKey,
        //uint _totalSupply,
        address _owner,
        address _resolver
    )
        BaseToken(_proxy, _tokenState, "Charm Derivatives Platform Token", "CHARM", _owner, bytes32("CHARM"), 0, _resolver){}

    /* ========== MUTATIVE FUNCTIONS ========== */

    function issue(address account, uint amount) external override onlyInternalContracts{
        _internalIssue(account, amount);
    }

    function burn(address account, uint amount) external override onlyInternalContracts returns(bool){
        return _internalBurn(account, amount);
    }

    /* ========== VIEWS ========== */

    // Note: use public visibility so that it can be invoked in a subclass
    function resolverAddressesRequired() public pure override returns (bytes32[] memory addresses) {
        addresses = new bytes32[](6);
        addresses[0] = CONTRACT_SYSTEMSTATUS;
        addresses[1] = CONTRACT_ISSUER_FOR_CBBC_TOKEN;
        addresses[2] = CONTRACT_ISSUER_FOR_DIVIDEND_TOKEN;
        addresses[3] = CONTRACT_ISSUER_FOR_LIQUIDITY_TOKEN;
        addresses[4] = CONTRACT_ISSUER_FOR_SATOSHI;
        addresses[5] = CONTRACT_MASTER_CHEF;
    }

    function systemStatus() internal view returns (ISystemStatus) {
        return ISystemStatus(requireAndGetAddress(CONTRACT_SYSTEMSTATUS));
    }

   function issuerForLiquidityToken() internal view returns (address) {
        return requireAndGetAddress(CONTRACT_ISSUER_FOR_LIQUIDITY_TOKEN);
    }

    function issuerForCbbcToken() internal view returns (address) {
        return requireAndGetAddress(CONTRACT_ISSUER_FOR_CBBC_TOKEN);
    }

    function issuerForDividendToken() internal view returns (address) {
        return requireAndGetAddress(CONTRACT_ISSUER_FOR_DIVIDEND_TOKEN);
    }

    function issuerForSatoshi() internal view returns (address) {
        return requireAndGetAddress(CONTRACT_ISSUER_FOR_SATOSHI);
    }

    function masterChef() internal view returns (address) {
        return requireAndGetAddress(CONTRACT_MASTER_CHEF);
    }

    /* ========== MODIFIERS ========== */

    modifier onlyInternalContracts() {
        bool isIssuerForCbbcToken = msg.sender == issuerForCbbcToken();
        
        bool isIssuerForDividendToken = msg.sender == issuerForDividendToken();

        bool isIssuerForLiquidityToken = msg.sender == issuerForLiquidityToken();

        bool isIssuerForSatoshi = msg.sender == issuerForSatoshi();
        
        bool isMasterChef = msg.sender == masterChef();

        require(isIssuerForCbbcToken || isIssuerForDividendToken || isIssuerForLiquidityToken || isIssuerForSatoshi || isMasterChef, "Charm: Only Issuer or MasterChef contracts allowed");
        _;
    }

}
