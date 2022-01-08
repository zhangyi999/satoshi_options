pragma solidity 0.8.3;

import "./interfaces/ICbbcToken.sol";
import "./interfaces/IRebasePolicy.sol";
import "./interfaces/ISystemStatus.sol";
import "./interfaces/IIssuerForCbbcToken.sol";
import "./interfaces/IMarketOracle.sol";
import "./interfaces/IERC20.sol";

import "./libraries/SafeMathInt.sol";
import "./libraries/CbbcLibrary.sol";

import "./Owned.sol";
import "./ExternCbbcStateToken.sol";
import "./MixinSystemSettings.sol";

/**
 * @title CBBC ERC20 token
 * @dev This is part of an implementation of the uFragments Ideal Money protocol.
 *      uFragments is a normal ERC20 token, but its supply can be adjusted by splitting and
 *      combining tokens proportionally across all wallets.
 *
 *      uFragment balances are internally represented with a hidden denomination, 'gons'.
 *      We support splitting the currency in expansion and combining the currency on contraction by
 *      changing the exchange rate between the hidden 'gons' and the public 'fragments'.
 * @dev Update: This is part of an implementation of the Peggedcoin Ideal Money protocol.
 *      Peggedcoin is a normal ERC20 token, its supply can adjust by combining tokens proportionally
 *      across all wallets during contraction and splitting tokens across all wallets during contraction
 *      during expansion.
 * @dev Update: Extend peggedcoin token by implementing burn and mint
 */
contract CbbcToken is Owned, ExternCbbcStateToken, MixinSystemSettings, ICbbcToken{
    // PLEASE READ BEFORE CHANGING ANY ACCOUNTING OR MATH
    // Anytime there is division, there is a risk of numerical instability from rounding errors.
    //
    // We make the following guarantees:
    // - If address 'A' transfers x Fragments to address 'B'. A's resulting external balance will
    //   be decreased by precisely x Fragments, and B's external balance will be precisely
    //   increased by x Fragments.
    //
    // We do not guarantee that the sum of all balances equals the result of calling totalSupply().
    // This is because, for any conversion function 'f()' that has non-zero rounding error,
    // f(x0) + f(x1) + ... + f(xn) is not always equal to f(x0 + x1 + ... xn).
    using SafeMathInt for int256;

    /* ========== STATE VARIABLES ========== */
    bytes32 public constant CONTRACT_NAME = "CbccToken";

    // MAX_SUPPLY = maximum integer < (sqrt(4*TOTAL_GONS + 1) - 1) / 2
    uint256 private constant MAX_SUPPLY = type(uint128).max; // (2^128) - 1
    uint256 private constant MAX_GONS_PER_FRAGMENT = type(uint256).max / MAX_SUPPLY;

    // Currency key which identifies this Synth to the Synthetix system
    bytes32 public override currencyKey;
    // Used for authentication
    bytes32 public override tradeTokenKey;
    bytes32 public override settleTokenKey;
    uint8   public override leverage;
    CbbcType  public override cbbcType;

    uint8 public constant DECIMALS = 18; // all CBBCs decimals = 18;

    address public override rebasePolicy;

    // Flexible storage names

    /* ========== ADDRESS RESOLVER CONFIGURATION ========== */

    bytes32 private constant CONTRACT_SYSTEMSTATUS = "SystemStatus";
    bytes32 private constant CONTRACT_ISSUER = "IssuerForCbbcToken";
    bytes32 private constant CONTRACT_MARKETORACLE = "MarketOracle";

    // keep tracking of the number of rebase operations
//    uint256 private _rebaseEpoch;
    uint256 public override rebaseTimestamp; // tracking initializing or rebase timestamp
    uint256 public override rebasePrice; // tracking initializing or rebase trade token price

    constructor(
        CbbcTokenSettings memory cbbcTokenSettings,
        address payable _proxy,
        TokenState _tokenState,
        bytes32 _currencyKey,
        uint _totalSupply,
        uint _gonsPerFragment,
        address _owner,
        address _resolver) ExternCbbcStateToken(_proxy, _tokenState, getName(cbbcTokenSettings), getSymbol(cbbcTokenSettings), _totalSupply, _gonsPerFragment, DECIMALS, _owner) MixinSystemSettings(_resolver){

        currencyKey = _currencyKey;
        settleTokenKey = cbbcTokenSettings._settleTokenKey;
        tradeTokenKey = cbbcTokenSettings._tradeTokenKey;
        leverage = cbbcTokenSettings._leverage;
        cbbcType = cbbcTokenSettings._cbbcType;

        emit CbbcCreated(settleTokenKey, tradeTokenKey, address(this), leverage, cbbcType);
    }

// ============== MUTATIVE FUNCTIONS ==============
    /**
     * @param rebasePolicy_ The address of the monetary policy contract to use for authentication.
     */
    function setRebasePolicy(address rebasePolicy_) external onlyOwner{
        rebasePolicy = rebasePolicy_;
        require(IRebasePolicy(rebasePolicy_).cTokenKey() == currencyKey, "CBBC: SET_REBASE_POLICY_FORBIDDEN.");
        emit LogRebasePolicyUpdated(rebasePolicy_);
    }

    /**
     * @dev Notifies Fragments contract about a new rebase cycle.
     * @param supplyDelta The number of new fragment tokens to add into circulation via expansion.
     * @return The total number of fragments after the supply adjustment.
     */
    function rebase(uint256 epoch, int256 supplyDelta)
        external
        override
        onlyRebasePolicy
        returns (uint256)
    {
        if (supplyDelta == 0) {
        // when supplyDelta = 0, rebase does not change totalSupply, but update rebasePrice and rebaseTimestamp
            rebaseTimestamp = block.timestamp; // update rebase timestamp
            (rebasePrice, ) = marketOracle().priceAndTimestamp(tradeTokenKey);
            emit LogRebase(epoch, rebaseTimestamp, rebasePrice, totalSupply);
            return totalSupply;
        }

        uint256 totalSupply_;
        uint256 tempTS = totalSupply; // gas saving
        uint256 totalGons = tempTS * gonsPerFragment;

        if (supplyDelta < 0) {
            totalSupply_ = tempTS - uint256(supplyDelta.abs());
        } else {
            totalSupply_ = tempTS + uint256(supplyDelta);
            if (totalSupply_ > MAX_SUPPLY) {
                totalSupply_ = MAX_SUPPLY;
            }
        }

        gonsPerFragment = gonsPerFragment * tempTS / totalSupply_;
        if (gonsPerFragment > MAX_GONS_PER_FRAGMENT) {
            gonsPerFragment = MAX_GONS_PER_FRAGMENT;
        }

        totalSupply = totalGons / gonsPerFragment; // to make total supply consistent with gonsPerFragment

        rebaseTimestamp = block.timestamp; // update rebase timestamp
        (rebasePrice,) = marketOracle().priceAndTimestamp(tradeTokenKey);

        emit LogRebase(epoch, rebaseTimestamp, rebasePrice, totalSupply_);

        return totalSupply_;
    }

    /**
     * @dev Transfer tokens to a specified address.
     * @param to The address to transfer to.
     * @param value The amount to be transferred.
     * @return True on success, false otherwise.
     */
    function transfer(address to, uint256 value) public optionalProxy override returns (bool)
    {
        if (to == address(0)) {
            return _internalBurn(messageSender, value);
        }

        return super._internalTransfer(messageSender, to, value);
    }

    /**
     * @dev Transfer tokens from one address to another.
     * @param from The address you want to send tokens from.
     * @param to The address you want to transfer to.
     * @param value The amount of tokens to be transferred.
     */
    function transferFrom(
        address from,
        address to,
        uint value
    ) public optionalProxy override returns (bool) {
        return _internalTransferFrom(from, to, value);
    }

    /**
     * @notice Approves spender to transfer on the message sender's behalf.
     */
/*
    function approve(address spender, uint value) public optionalProxy override(ICbbcToken, ExternCbbcStateToken) returns (bool) {
        return super.approve(spender, value);
    }
*/
    function issue(address account, uint amount) external override lock onlyInternalContracts {
        if(totalSupply == 0){ //first-time mint cbbc
            rebaseTimestamp = block.timestamp; // record the initial timestamp
            (rebasePrice, ) = marketOracle().priceAndTimestamp(tradeTokenKey); // record the initial price, tradeToken/USDT
            require(rebasePrice > 0, "CBBC: ILLEGAL_TRADE_PRICE.");
        }

        _internalIssue(account, amount);
    }

    function burn(address account, uint amount) external override lock onlyInternalContracts returns (bool) {
        return _internalBurn(account, amount);
    }

    function _internalIssue(address account, uint amount) internal {
        uint oldBalance = tokenState.balanceOf(account);

        uint accountNumberOfGPFChange = numberOfGPFChangeForIndividual[account];

        if(accountNumberOfGPFChange < numberOfGPFChange){
            oldBalance = updateGons(oldBalance, accountNumberOfGPFChange);
            numberOfGPFChangeForIndividual[account] = numberOfGPFChange;
        }

        tokenState.setBalanceOf(account, oldBalance + amount * gonsPerFragment);

        totalSupply = totalSupply + amount;
        require(totalSupply <= MAX_SUPPLY, "CBBC: TOO_MANY_CBBCs");

        emitTransfer(address(0), account, amount);
        emitIssued(account, amount);
    }

    function _internalBurn(address account, uint amount) internal returns (bool) {
        uint oldBalance = tokenState.balanceOf(account);

        uint accountNumberOfGPFChange = numberOfGPFChangeForIndividual[account];

        if(accountNumberOfGPFChange < numberOfGPFChange){
            oldBalance = updateGons(oldBalance, accountNumberOfGPFChange);

            numberOfGPFChangeForIndividual[account] = numberOfGPFChange;
        }

        tokenState.setBalanceOf(account, oldBalance - amount * gonsPerFragment);

        totalSupply = totalSupply - amount;
        emitTransfer(account, address(0), amount);
        emitBurned(account, amount);

        return true;
    }

    // Allow owner to set the total supply on import.
    function setTotalSupply(uint amount) external optionalProxy_onlyOwner {
        totalSupply = amount;
    }

    // Allow owner to adjust the gonsPerFragment in certain occasion.
    function setGonsPerFragment(uint amount) external optionalProxy_onlyOwner {
        numberOfGPFChange++; // starts from 1;

        GPFChanges[numberOfGPFChange] = GPFChange({
            newGonsPerFragment: amount,
            oldGonsPerFragment: gonsPerFragment,
            timeStampForChange: block.timestamp
        });

        gonsPerFragment = amount;
    }

    /* ========== INTERNAL FUNCTIONS ========== */

    function _internalTransferFrom(
        address from,
        address to,
        uint value
    ) internal returns (bool) {
        // Skip allowance update in case of infinite allowance
        if (tokenState.allowance(from, messageSender) != type(uint256).max) {
            // Reduce the allowance by the amount we're transferring.
            // The safeSub call will handle an insufficient allowance.
            tokenState.setAllowance(from, messageSender, tokenState.allowance(from, messageSender) - value);
        }

        return super._internalTransfer(from, to, value);
    }

    /* ========== VIEWS ========== */

    // Note: use public visibility so that it can be invoked in a subclass
    function resolverAddressesRequired() public view override returns (bytes32[] memory addresses) {
        bytes32[] memory existingAddresses = MixinSystemSettings.resolverAddressesRequired();
        bytes32[] memory newAddresses = new bytes32[](3);

        newAddresses[0] = CONTRACT_SYSTEMSTATUS;
        newAddresses[1] = CONTRACT_ISSUER;
        newAddresses[2] = CONTRACT_MARKETORACLE;

        addresses = combineArrays(existingAddresses, newAddresses);
    }

    function systemStatus() internal view returns (ISystemStatus) {
        return ISystemStatus(requireAndGetAddress(CONTRACT_SYSTEMSTATUS));
    }

    function issuer() internal view returns (IIssuerForCbbcToken) {
        return IIssuerForCbbcToken(requireAndGetAddress(CONTRACT_ISSUER));
    }

    function marketOracle() internal view returns (IMarketOracle) {
        return IMarketOracle(requireAndGetAddress(CONTRACT_MARKETORACLE));
    }

    /**
     * @param who The address to query.
     * @return The gon balance of the specified address.
     */
    function scaledBalanceOf(address who) external view returns (uint256) {
        return super.balanceOf(who) * gonsPerFragment;
    }

    /**
     * @return the total number of gons.
     */
    function scaledTotalSupply() external view returns (uint256) {
        return totalSupply * gonsPerFragment;
    }

    function getName(
        CbbcTokenSettings memory cbbcTokenSettings
    ) internal pure returns (string memory name) {
        bytes32 settleTokenKey_ = cbbcTokenSettings._settleTokenKey;
        bytes32 tradeTokenKey_ = cbbcTokenSettings._tradeTokenKey;
        uint8 leverage_ = cbbcTokenSettings._leverage;
        CbbcType cbbcType_ = cbbcTokenSettings._cbbcType;

        if (cbbcType_ == ICbbcToken.CbbcType.bear){
            name = string(abi.encodePacked(
                uintToString(leverage_), 
                "X ",
                "Inverse ",
                bytes32ToString(tradeTokenKey_),
                " ",
                bytes32ToString(settleTokenKey_)));
        }else if (cbbcType_ == ICbbcToken.CbbcType.bull){
            name = string(abi.encodePacked(
                uintToString(leverage_),
                "X ",
                bytes32ToString(tradeTokenKey_),
                " ",
                bytes32ToString(settleTokenKey_)));
        }

        return name;
    }

    function getSymbol(
        CbbcTokenSettings memory cbbcTokenSettings
    ) internal pure returns (string memory symbol) {
        bytes32 settleTokenKey_ = cbbcTokenSettings._settleTokenKey;
        bytes32 tradeTokenKey_ = cbbcTokenSettings._tradeTokenKey;
        uint8 leverage_ = cbbcTokenSettings._leverage;
        CbbcType cbbcType_ = cbbcTokenSettings._cbbcType;

        if (cbbcType_ == ICbbcToken.CbbcType.bear){
            symbol = string(abi.encodePacked(
                "c",
                uintToString(leverage_),
                "I",
                bytes32ToString(tradeTokenKey_),
                bytes32ToString(settleTokenKey_)));
        }else if (cbbcType_ == ICbbcToken.CbbcType.bull){
            symbol = string(abi.encodePacked(
                "c",
                uintToString(leverage_),
                bytes32ToString(tradeTokenKey_),
                bytes32ToString(settleTokenKey_)));
        }

        return symbol;
    }

    function settleTokenAddress() public view override returns (address) {
        return resolver.requireAndGetAddress(settleTokenKey, "CbbcToken: settleToken does not exist");
    }
/*
    function tradeTokenAddress() public view override returns (address) {
        return resolver.requireAndGetAddress(tradeTokenKey, "CbbcToken: tradeToken does not exist");
    }
*/
    /**
     * @return Current price of the cbbc token.
     */
    function currentCbbcPrice() external override view returns(uint){
        if(totalSupply == 0){
            return 10**DECIMALS; // the initial price of CBBC, = 1.
        }else{
            return getCbbcPrice(0, 0, tradeDirection.buyCbbc);
        }
    }

 /**
    * @dev Compute cbbc price
    * @param settleAmount A uint256 value. The amount of settleToken used to buy cbbc
    * @param cbbcAmount A uint256 value. The amount of cbbc you are selling
    * @param direction tradeDirection. Buy or sell cbbc.
    * @return cbbcPrice A uint256 value
    */
    function getCbbcPrice(
        uint settleAmount,
        uint cbbcAmount,
        tradeDirection direction)
        public view override returns (uint) {
            require(settleAmount == 0 || cbbcAmount == 0, "CBBC: BUY_AND_SELL_AT_THE_SAME_TIME.");
            CbbcLibrary.priceData memory priceData_;
            CbbcLibrary.marketData memory marketData_;
            CbbcLibrary.cbbcTokenData memory cbbcTokenData_;
            {
            cbbcTokenData_.settleToken = settleTokenKey;
            cbbcTokenData_.tradeToken = tradeTokenKey;
            cbbcTokenData_.leverage = uint(leverage);
            cbbcTokenData_.cbbcType = cbbcType;
            cbbcTokenData_.settleTokenDecimals = IERC20(settleTokenAddress()).decimals();
            cbbcTokenData_.tradeTokenDecimals = 18;//IERC20(tradeTokenAddress()).decimals(); TODO: to remove
            }
            {
            priceData_.settleTokenPrice = marketOracle().settleTokenPrices(settleTokenKey);
            priceData_.rebasePrice = rebasePrice;
            priceData_.rebaseTimestamp= rebaseTimestamp;
            priceData_.currentTimestamp = block.timestamp;
            (priceData_.currentPrice, ) = marketOracle().priceAndTimestamp(tradeTokenKey); //trade token price, denoted in USDT, real * 10**18
            require(priceData_.currentPrice > 0, "CBBC: ILLEGAL_TRADE_PRICE.");
            if(priceData_.rebasePrice == 0){
                priceData_.rebasePrice = priceData_.currentPrice; // Using currentPrice instead if trade price is not initiated.
                priceData_.rebaseTimestamp = priceData_.currentTimestamp;
                }
            }
            {
            marketData_.beta = marketOracle().betas(settleTokenKey, tradeTokenKey); // real * 10**3
            marketData_.alpha_buy = getAlphaForBuy(); // uint, initially alpha = 4
            marketData_.alpha_sell = getAlphaForSell(); // uint, initially alpha = 6
            marketData_.iRate = marketOracle().interestRates(settleTokenKey); // interest rate of settle token; = actual interest rate * 10 ** 6, e.g., 10% => 10**5;

            (marketData_.baSpread, marketData_.sigma, marketData_.dailyVolume) = marketOracle().tradeTokenDatas(tradeTokenKey); // bid-ask spread; real * 10**18
            // daily price volatility; real * 10**18
            // daily tradinng volume; in tradeToken decimal
            require(marketData_.dailyVolume > 0, "CBBC: ILLEGAL_DAILY_VOLUME.");
            }

            if(settleAmount == 0 && cbbcAmount == 0){
                return CbbcLibrary._computeCbbcPrice(priceData_,
                                            cbbcTokenData_,
                                            marketData_,
                                            0,
                                            direction);
            } else {
                {
                uint priceImpact = CbbcLibrary._computePriceImpact(priceData_,
                                                        cbbcTokenData_,
                                                        marketData_,
                                                        settleAmount,
                                                        cbbcAmount,
                                                        direction);
                return CbbcLibrary._computeCbbcPrice(priceData_,
                                            cbbcTokenData_,
                                            marketData_,
                                            priceImpact,
                                            direction);
                }
            }
    }

  /**
     * @dev auxiliary function converting an uint256 to string.
     * @return str string(v)
     * @param v an uint256 value
     */
    function uintToString(uint v) internal pure returns (string memory str) { // TODO: testing?
        uint maxlength = 100;
        bytes memory reversed = new bytes(maxlength);
        uint i = 0;
        while (v != 0) {
            uint remainder = v % 10;
            v = v / 10;
            reversed[i++] = bytes1(uint8(48 + remainder));
        }
        bytes memory s = new bytes(i);
        for (uint j = 0; j < i; j++) {
            s[j] = reversed[i - 1 - j];
        }
        str = string(s);
    }

    function bytes32ToString(bytes32 _bytes32) public pure returns (string memory) {
        uint8 i = 0;
        while(i < 32 && _bytes32[i] != 0) {
            i++;
        }
        bytes memory bytesArray = new bytes(i);
        for (i = 0; i < 32 && _bytes32[i] != 0; i++) {
            bytesArray[i] = _bytes32[i];
        }
        return string(bytesArray);
    }
    /* ========== MODIFIERS ========== */
    uint private unlocked = 1;
    modifier lock() {
        require(unlocked == 1, 'CBBC: LOCKED');
        unlocked = 0;
        _;
        unlocked = 1;
    }

    modifier onlyInternalContracts() {
        bool isIssuer = msg.sender == address(issuer());

        require(isIssuer, "Only the Issuer contracts allowed");
        _;
    }

    modifier onlyRebasePolicy() {
        require(msg.sender == address(rebasePolicy), "CBBC: NOT_REBASE_POLICY");
        _;
    }

    /* ========== EVENTS ========== */
    event Issued(address indexed account, uint value);
    bytes32 private constant ISSUED_SIG = keccak256("Issued(address,uint256)");

    function emitIssued(address account, uint value) internal {
        proxy._emit(abi.encode(value), 2, ISSUED_SIG, addressToBytes32(account), 0, 0);
    }

    event Burned(address indexed account, uint value);
    bytes32 private constant BURNED_SIG = keccak256("Burned(address,uint256)");

    function emitBurned(address account, uint value) internal {
        proxy._emit(abi.encode(value), 2, BURNED_SIG, addressToBytes32(account), 0, 0);
    }

    event LogRebase(uint256 indexed epoch, uint256, uint256 price, uint256 totalSupply);

    event LogRebasePolicyUpdated(address rebasePolicy);
    
    event CbbcCreated(bytes32 settleToken,
                      bytes32 tradeToken,
                      address cbbc,
                      uint8 leverage,
                      ICbbcToken.CbbcType cbbcType);
}