//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import "@openzeppelin/contracts/utils/math/Math.sol";

import "abdk-libraries-solidity/ABDKMath64x64.sol";

import "./libraries/ECDSA.sol";
import "./libraries/SafeToken.sol";
import "./interfaces/IConfig.sol";

// import "./public/LinearOptions.sol";


// import "hardhat/console.sol";

interface IStrategy {
    struct GetPBCTInfo {
        bool direction;
        int128 delta;
        int128 t;
        int128 BK;
        int128 K;
        int128 BT;
    }

    struct GetPurchaseQuantityInfo {
        bool direction;
        int128 bk;
        int128 delta;
        int128 _i;
    }

    struct GetEInfo {
        bool direction;
        int128 delta;
        int128 bk;
    }

    function getLiquidationNum(
        GetPBCTInfo memory BTCInfo,
        IConfig.DeltaItem memory _DeltaItem,
        int128 eta1,
        int128 eta2,
        int128 phi,
        int128 withdrawFee,
        int128 r,
        int128 Q
    ) external view returns (int128);

    function getBk(int128 currBtc, int128 bk) external pure returns (int128);

    function getPurchaseQuantity(
        GetPurchaseQuantityInfo memory _getPurchaseQuantityInfo,
        IConfig.DeltaItem memory deltaItem,
        int128 eta1,
        int128 eta2,
        int128 currBtc
    ) external pure returns (int128);
}

contract SatoshiOptions_Charm is
    ERC1155Upgradeable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable
{
    using SafeToken for address;
    using ECDSA for bytes32;

    //////////// config ////////////
    IConfig public config;

    //////////// token ////////////
    address public charm;

    //////////// route ////////////
    address public route;

    //////////// signer ////////////
    mapping(address => mapping(uint256 => bool)) private seenNonces;
    address public DATA_PROVIDER;

    //////////// nft ////////////
    uint256 private _totalSupply;
    // user => [ids]
    mapping(address => uint256[]) private _idBalance;

    struct NftData {
        int128 delta;
        uint256 createTime;
        int128 openPrice;
        bool direction;
        int128 bk;
        int128 K;
        address strategy;
        address tradeToken;
    }
    mapping(uint256 => NftData) private _nftStore;

    //////////// strategy ////////////
    mapping(address => bool) private _isStrategy;

    modifier onlySigner(SignedPriceInput calldata signedPr) {
        require(checkIdentity(signedPr), "Price Error.");
        _;
    }

    modifier checkStrategy(address _strategy) {
        require(_isStrategy[_strategy], "strategy Error.");
        _;
    }

    modifier onlyRoute() {
        require(route == _msgSender(), "Price Error.");
        _;
    }

    event Open(address indexed owner, uint256 indexed pid, uint256 btcPrice);
    event Cloes(
        address indexed owner,
        uint256 indexed pid,
        uint256 btcPrice,
        uint256 closeAmount
    );

    function initialize(
        string memory uri_,
        IConfig _config
    ) public initializer {
        __Ownable_init();
        __ReentrancyGuard_init();
        __ERC1155_init(uri_);
        config = _config;
    }

    //////////// signer ////////////
    function setDataProvider(address _provider) external onlyOwner {
        DATA_PROVIDER = _provider; // 0x9548B3682cD65D3265C92d5111a9782c86Ca886d
    }

    function setStrategy(address _strategy) external onlyOwner {
        _isStrategy[_strategy] = true;
    }

    function setRoute(address _route) external onlyOwner {
        route = _route;
    }
 
    //验证前端价格是否正确
    // 开仓
    struct SignedPriceInput {
        address tradeToken;
        uint128 tradePrice;
        uint256 nonce;
        uint256 deadline;
        bytes signature;
    }

    function checkIdentity(SignedPriceInput calldata signedPr)
        public
        returns (bool success)
    {
        // This recreates the message hash that was signed on the client.
        int128 tradePrice = int128(signedPr.tradePrice);
        uint256 nonce = signedPr.nonce;
        uint256 deadline = signedPr.deadline;
        bytes calldata signature = signedPr.signature;
        bytes32 hash = keccak256(
            abi.encodePacked(
                signedPr.tradeToken,
                tradePrice,
                nonce,
                deadline,
                DATA_PROVIDER
            )
        );
        bytes32 messageHash = hash.toEthSignedMessageHash();

        // Verify that the message's signer is the data provider
        address signer = messageHash.recover(signature);
        require(deadline >= block.timestamp, "Prices have expired");
        require(signer == DATA_PROVIDER, "INVALID_SIGNER.");
        require(!seenNonces[signer][nonce], "USED_NONCE");
        seenNonces[signer][nonce] = true;

        success = true;
        return success;
    }

    //////////// nft ////////////
    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function getNftInfoFor(uint256 _pid) public view returns (NftData memory) {
        return _nftStore[_pid];
    }

    function mintTo(
        address _to,
        bool direction,
        uint128 _delta,
        uint128 _bk,
        uint128 _cppcNum,
        address _strategy,
        SignedPriceInput calldata signedPr
    )
        public
        onlySigner(signedPr)
        checkStrategy(_strategy)
        onlyRoute
        nonReentrant
        returns (uint256 pid)
    {
        int128 tradePrice = int128(signedPr.tradePrice);

        IStrategy strategy = IStrategy(_strategy);
        // int128 K = strategy.getBk(tradePrice, int128(_bk));
        int128 _pbc = strategy.getPurchaseQuantity(
            IStrategy.GetPurchaseQuantityInfo(
                direction,
                int128(_bk),
                int128(_delta),
                int128(_cppcNum)
            ),
            getDeltaTable(int128(_delta)),
            config.eta1(),
            config.eta2(),
            tradePrice
        );

        // pbc int128 64*64
        // mintBalance = uint128(_pbc);
        pid = _mintNft(_to, uint128(_pbc));

        NftData storage nftData = _nftStore[pid];
        nftData.delta = int128(_delta);
        nftData.direction = direction;
        nftData.createTime = block.timestamp;
        nftData.openPrice = tradePrice;
        nftData.bk = int128(_bk);
        nftData.K = strategy.getBk(tradePrice, int128(_bk));
        nftData.strategy = _strategy;
        nftData.tradeToken = signedPr.tradeToken;

        // _burnFor(_to, _cppcNum / (1 << 64));
        emit Open(_to, pid, signedPr.tradePrice);
    }

    // 通过Delta获取配置
    function getDeltaTable(int128 _delta)
        public
        view
        returns (IConfig.DeltaItem memory)
    {
        return config.delta(_delta);
    }

    // 平仓
    function burnFor(
        address _from,
        uint256 _pid,
        uint128 _cAmount,
        SignedPriceInput calldata signedPr
    )
        public
        onlySigner(signedPr)
        onlyRoute
        nonReentrant
        returns (uint256 _liquidationNum)
    {
        NftData storage nftData = _nftStore[_pid];
        require(nftData.tradeToken == signedPr.tradeToken, "tradeToken error");

        IStrategy strategy = IStrategy(nftData.strategy);
        nftData.tradeToken = signedPr.tradeToken;

        int128 LiquidationNum = strategy.getLiquidationNum(
            IStrategy.GetPBCTInfo(
                nftData.direction,
                nftData.delta,
                int128(uint128((block.timestamp - nftData.createTime) << 64)),
                nftData.bk,
                nftData.K,
                int128(signedPr.tradePrice)
            ),
            getDeltaTable(nftData.delta),
            config.eta1(),
            config.eta2(),
            config.phi(),
            config.withdrawFee(),
            config.r(),
            int128(_cAmount)
        );

        _liquidationNum = uint128(LiquidationNum / (1 << 64));

        _burnNft(_from, _pid, _cAmount);
        // _mintCppc(_from, _liquidationNum);
        emit Cloes(_from, _pid, signedPr.tradePrice, _cAmount);
    }

    function _mintNft(address _to, uint256 _amount) internal returns (uint256) {
        _mint(_to, _totalSupply, _amount, "");
        return _totalSupply++;
    }

    function _burnNft(
        address from,
        uint256 id,
        uint256 amount
    ) internal {
        _burn(from, id, amount);
    }

    // function _mintCppc(address to, uint256 amount) internal {
    //     IERC20Interface(charm).issue(to, amount);
    // }

    // function _burnFor(address from, uint256 amount) internal {
    //     charm.safeTransferFrom(from, address(this), amount);
    //     IERC20Interface(charm).burn(amount);
    // }
}
