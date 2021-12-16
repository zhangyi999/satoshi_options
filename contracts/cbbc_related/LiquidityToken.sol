pragma solidity 0.8.3;

// Inheritance
import "./BaseToken.sol";

// Internal references
import "./interfaces/ISystemStatus.sol";
import "./interfaces/IIssuerForLiquidityToken.sol";
import "./interfaces/ILiquidityToken.sol";

// https://docs.synthetix.io/contracts/source/contracts/synth
contract LiquidityToken is BaseToken, ILiquidityToken {
    bytes32 public constant CONTRACT_NAME = "LiquidityToken";
    //bytes32 public constant ETH = "ETH";

    /* ========== STATE VARIABLES ========== */
    bytes4 private constant SELECTOR = bytes4(keccak256(bytes('transfer(address,uint256)')));

    // Currency key which identifies this Synth to the Synthetix system
    bytes32 public override settleTokenKey;
    uint256 public override initialSupply;

    /* ========== ADDRESS RESOLVER CONFIGURATION ========== */

    bytes32 private constant CONTRACT_SYSTEMSTATUS = "SystemStatus";
    bytes32 private constant CONTRACT_ISSUER_FOR_LIQUIDITY_TOKEN = "IssuerForLiquidityToken";
    bytes32 private constant CONTRACT_ISSUER_FOR_CBBC_TOKEN = "IssuerForCbbcToken";
    bytes32 private constant CONTRACT_ISSUER_FOR_DIVIDEND_TOKEN = "IssuerForDividendToken";
    bytes32 private constant CONTRACT_ROUTER = "Router";

    /* ========== CONSTRUCTOR ========== */

    constructor(
        address payable _proxy,
        TokenState _tokenState,
        string memory _tokenName,
        string memory _tokenSymbol,
        bytes32 _currencyKey,
        bytes32 _settleTokenKey,
        uint _totalSupply,
        address _owner,
        address _resolver
    )
        BaseToken(_proxy, _tokenState, _tokenName, _tokenSymbol, _owner, _currencyKey, _totalSupply, _resolver)
    {
        settleTokenKey = _settleTokenKey;
    }

    /* ========== MUTATIVE FUNCTIONS ========== */
    function issueInitialSupply(address destAccount, uint amount) external onlyOwner{
        bool isDuringSettingUp = true;
        require(settleTokenKey == bytes32("ETH") && isDuringSettingUp, "CBBC: ONLY ETH and DURINNG SETTINGUP IS ALLOWED.");
        _internalIssue(destAccount, amount);
        initialSupply = amount;
        isDuringSettingUp = false;
    }

    function issue(address account, uint amount) external override onlyIssuer {
        _internalIssue(account, amount);
    }

    function burn(address account, uint amount) external override onlyIssuerOrRouter returns(bool){
        return _internalBurn(account, amount);
    }

    function transferSettleToken(address to, uint256 value) external override lock onlyInternalContracts {
        _safeTransfer(settleTokenAddress(), to, value);
    }

    function _safeTransfer(address token, address to, uint value) private {
        require (to != address (0), "CBBC: TRANSFER_TO_ZERO_ADDRESS_NOT_ALLOWED" );
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(SELECTOR, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'CBBC: TRANSFER_FAILED');
    }

    /* ========== VIEWS ========== */
    // Note: use public visibility so that it can be invoked in a subclass
    function resolverAddressesRequired() public pure override returns (bytes32[] memory addresses) {
        addresses = new bytes32[](5);
        addresses[0] = CONTRACT_SYSTEMSTATUS;
        addresses[1] = CONTRACT_ISSUER_FOR_CBBC_TOKEN;
        addresses[2] = CONTRACT_ISSUER_FOR_DIVIDEND_TOKEN;
        addresses[3] = CONTRACT_ISSUER_FOR_LIQUIDITY_TOKEN;
        addresses[4] = CONTRACT_ROUTER;
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

    function router() internal view returns (address) {
        return requireAndGetAddress(CONTRACT_ROUTER);
    }

    function settleTokenAddress() public view override returns (address) {
        return resolver.requireAndGetAddress(settleTokenKey, "CbbcToken: settleToken does not exist");
    }

    /* ========== MODIFIERS ========== */
    uint private unlocked = 1;
    modifier lock() {
        require(unlocked == 1, 'CBBC: LOCKED');
        unlocked = 0;
        _;
        unlocked = 1;
    }

    modifier onlyIssuer() {
        bool isIssuerForLiquidityToken = msg.sender == issuerForLiquidityToken();

        require(isIssuerForLiquidityToken, "Only Issuer contracts allowed");
        _;
    }

    modifier onlyIssuerOrRouter() {
        bool isIssuerForLiquidityToken = msg.sender == issuerForLiquidityToken();
        bool isRouter = msg.sender == router();

        require(isIssuerForLiquidityToken || isRouter, "Only Issuer contracts allowed");
        _;
    }

    modifier onlyInternalContracts() {
        bool isIssuerForCbbcToken = msg.sender == issuerForCbbcToken();
        bool isIssuerForDividendToken = msg.sender == issuerForDividendToken();
        bool isIssuerForLiquidityToken = msg.sender == issuerForLiquidityToken();

        require(isIssuerForCbbcToken || isIssuerForDividendToken || isIssuerForLiquidityToken, "Only internal contracts allowed");
        _;
    }

}
