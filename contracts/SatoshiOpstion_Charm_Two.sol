//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import "@openzeppelin/contracts/utils/math/Math.sol";

import "abdk-libraries-solidity/ABDKMath64x64.sol";

import "./libraries/ECDSA.sol";
import "./libraries/SafeToken.sol";
import "./interface/IConfig.sol";

contract SatoshiOpstion_Charm_Two is
    ERC721Upgradeable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable
{
    using SafeToken for address;
    using ECDSA for bytes32;

    int128 public immutable SECONDS_IN_A_YEAR =
        ABDKMath64x64.fromUInt(31536000);

    int128 public currBtc;

    //////////// config ////////////
    IConfig public config;

    //////////// token ////////////
    address public charm;

    //////////// signer ////////////
    mapping(address => mapping(uint256 => bool)) private seenNonces;
    address public DATA_PROVIDER;

    //////////// nft ////////////
    uint256 private _totalSupply = 0;
    // user => [ids]
    mapping(address => uint256[]) private _idBalance;

    struct NftData {
        int128 delta;
        int128 cppcNum;
        uint256 createTime;
        int128 openPrice;
        bool direction;
        bool isEnable;
        int128 bk;
        int128 K;
    }
    mapping(uint256 => NftData) private _nftStore;

    modifier isMyNFTPid(uint256 _pid) {
        require(ownerOf(_pid) == msg.sender, "pid No access");
        _;
    }

    modifier checkIdentity(SignedPriceInput calldata signedPr) {
        require(_checkIdentity(signedPr), "Price Error.");
        _;
    }

    struct GetPBCTInfo {
        bool direction;
        int128 delta;
        int128 t;
        int128 BK;
        int128 K;
    }

    event Open(address indexed owner, uint256 indexed pid, uint256 amount);
    event Cloes(address indexed owner, uint256 indexed pid, uint256 btcPrice);

    function initialize(
        string memory name_,
        string memory symbol_,
        address _charm,
        IConfig _config
    ) public initializer {
        __Ownable_init();
        __ReentrancyGuard_init();
        __ERC721_init(name_, symbol_);
        charm = _charm;
        config = _config;
    }

    //////////// signer ////////////
    function setDataProvider(address _provider) external onlyOwner {
        DATA_PROVIDER = _provider; // 0x9548B3682cD65D3265C92d5111a9782c86Ca886d
    }

    //验证前端价格是否正确
    // 开仓
    struct SignedPriceInput {
        address tradeToken;
        uint128 tradePrice;
        uint256 nonce;
        bytes signature;
    }

    function _checkIdentity(SignedPriceInput calldata signedPr)
        public
        returns (bool success)
    {
        // This recreates the message hash that was signed on the client.
        int128 tradePrice = int128(signedPr.tradePrice);
        uint256 nonce = signedPr.nonce;
        bytes calldata signature = signedPr.signature;
        bytes32 hash = keccak256(
            abi.encodePacked(
                signedPr.tradeToken,
                tradePrice,
                nonce,
                DATA_PROVIDER
            )
        );
        bytes32 messageHash = hash.toEthSignedMessageHash();

        // Verify that the message's signer is the data provider
        address signer = messageHash.recover(signature);
        require(signer == DATA_PROVIDER, "CBBC: INVALID_SIGNER.");
        require(!seenNonces[signer][nonce], "CBBC: USED_NONCE");
        seenNonces[signer][nonce] = true;

        success = true;
        return success;
    }

    //////////// nft ////////////
    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function balanceOfOwner(address _owner)
        external
        view
        returns (uint256[] memory ids)
    {
        uint256[] memory idAll = _idBalance[_owner];
        uint256 len = balanceOf(_owner);
        ids = new uint256[](len);
        uint256 index;
        for (uint256 i = 0; i < idAll.length; i++) {
            if (ownerOf(idAll[i]) == _owner) {
                ids[index] = idAll[i];
                index++;
            }
        }
    }

    //////////// 64x64 ////////////
    function pow64x64(int128 a, int128 pow) public pure returns (int128) {
        return
            ABDKMath64x64.exp_2(ABDKMath64x64.mul(pow, ABDKMath64x64.log_2(a)));
    }

    // 设置当前BTC价格
    function _SetCurrBtcPrice(uint128 _currBtc) internal {
        currBtc = int128(_currBtc);
    }

    function getNftInfoFor(uint256 _pid) public view returns (NftData memory) {
        return _nftStore[_pid];
    }

    // 获取开仓算数量
    struct GetPurchaseQuantityInfo {
        bool direction;
        int128 bk;
        int128 delta;
        int128 _i;
    }

    function open(
        bool direction,
        uint128 _delta,
        uint128 _bk,
        uint128 _cppcNum,
        SignedPriceInput calldata signedPr
    ) public checkIdentity(signedPr) returns (uint256 pid) {
        int128 delta = int128(_delta);
        int128 bk = int128(_bk);
        int128 cppcNum = int128(_cppcNum);

        _SetCurrBtcPrice(signedPr.tradePrice);

        int128 _omg;
        int128 _pbc;

        if (direction) {
            _omg = getUpOmg(delta);
        } else {
            _omg = getDownOmg(delta);
        }
        int128 K = getBk(bk);
        GetPurchaseQuantityInfo
            memory _getPurchaseQuantityInfo = GetPurchaseQuantityInfo(
                direction,
                bk,
                delta,
                cppcNum
            );
        _pbc = getPurchaseQuantity(_getPurchaseQuantityInfo);
        pid = _mintNft(_msgSender());
        NftData storage nftData = _nftStore[pid];
        nftData.delta = delta;
        nftData.direction = direction;
        nftData.cppcNum = cppcNum;
        nftData.createTime = (block.timestamp / 1000);
        nftData.openPrice = currBtc;
        nftData.bk = bk;
        nftData.K = K;
        nftData.isEnable = true;
        _burnFor(_msgSender(), ABDKMath64x64.mulu(cppcNum, 1));
        emit Open(_msgSender(), pid, signedPr.tradePrice);
        return pid;
    }

    // 通过Delta获取配置
    function getDeltaTable(int128 _delta)
        public
        view
        returns (IConfig.DeltaItem memory _DeltaItem)
    {
        return config.delta(_delta);
    }

    // 获取牛证Omg值
    function getUpOmg(int128 _delta) public view returns (int128) {
        int128 _eta1_128 = config.eta1();
        IConfig.DeltaItem memory _DeltaItem = getDeltaTable(_delta);
        int128 L1 = _DeltaItem.L1;
        int128 L2 = _DeltaItem.L2;
        int128 _omg = ABDKMath64x64.mul(
            ABDKMath64x64.div(ABDKMath64x64.sub(_eta1_128, L1), _eta1_128),
            ABDKMath64x64.div(L2, ABDKMath64x64.sub(L2, L1))
        );
        return _omg;
    }

    // 获取熊证Omg值
    function getDownOmg(int128 _delta) public view returns (int128) {
        int128 _eta2_128 = config.eta2();
        IConfig.DeltaItem memory _DeltaItem = getDeltaTable(_delta);
        int128 L3 = _DeltaItem.L3;
        int128 L4 = _DeltaItem.L4;
        int128 _omg = ABDKMath64x64.mul(
            ABDKMath64x64.div(ABDKMath64x64.sub(_eta2_128, L3), _eta2_128),
            ABDKMath64x64.div(L4, ABDKMath64x64.sub(L4, L3))
        );
        return _omg;
    }

    // 获取K
    function getBk(int128 bk) public view returns (int128) {
        return ABDKMath64x64.mul(currBtc, bk);
    }

    function getPurchaseQuantity(
        GetPurchaseQuantityInfo memory _getPurchaseQuantityInfo
    ) public view returns (int128) {
        IConfig.DeltaItem memory deltaItem = getDeltaTable(
            _getPurchaseQuantityInfo.delta
        );
        int128 delta = _getPurchaseQuantityInfo.delta;
        int128 omg = getUpOmg(delta);
        if (!_getPurchaseQuantityInfo.direction) {
            omg = getDownOmg(delta);
        }

        int128 omg1 = ABDKMath64x64.div(
            omg,
            pow64x64(_getPurchaseQuantityInfo.bk, deltaItem.L1)
        );
        int128 omg2 = ABDKMath64x64.div(
            ABDKMath64x64.sub(1 * 2**64, omg),
            pow64x64(_getPurchaseQuantityInfo.bk, deltaItem.L2)
        );

        if (!_getPurchaseQuantityInfo.direction) {
            omg1 = ABDKMath64x64.div(
                omg,
                pow64x64(_getPurchaseQuantityInfo.bk, deltaItem.L3)
            );
            omg2 = ABDKMath64x64.div(
                ABDKMath64x64.sub(1 * 2**64, omg),
                pow64x64(_getPurchaseQuantityInfo.bk, deltaItem.L4)
            );
        }
        int128 _Q = ABDKMath64x64.div(
            _getPurchaseQuantityInfo._i,
            ABDKMath64x64.add(omg1, omg2)
        );
        return _Q;
    }

    // 平仓
    function close(uint256 _pid,  uint128 _cAmount, SignedPriceInput calldata signedPr)
        public
        payable
        isMyNFTPid(_pid)
        checkIdentity(signedPr)
    {
        _SetCurrBtcPrice(signedPr.tradePrice);
        NftData memory nftData = getNftInfoFor(_pid);
        nftData.isEnable = false;
        bool direction = nftData.direction;
        int128 delta = nftData.delta;

        int128 bk = nftData.bk;
        int128 cppcNum = int128(_cAmount);

        nftData.cppcNum -= cppcNum;

        int128 K = nftData.K;
        GetPBCTInfo memory _getPBCTInfo = GetPBCTInfo(
            direction,
            bk,
            delta,
            cppcNum,
            K
        );
        int128 pbct = getPBCT(_getPBCTInfo);

        GetRlInfo memory _GetRlInfo = GetRlInfo(direction, delta);
        int128 rl = getRL(_GetRlInfo);

        GetPriceimpactInfo memory _GetPriceimpactInfo = GetPriceimpactInfo(
            rl,
            pbct,
            cppcNum
        );
        int128 priceimpact = getPriceimpact(_GetPriceimpactInfo);
        GetLiquidationNumInfo
            memory _getLiquidationNumInfo = GetLiquidationNumInfo(
                pbct,
                cppcNum,
                rl,
                priceimpact
            );
        int128 LiquidationNum = getLiquidationNum(_getLiquidationNumInfo);
        _mintCppc(_msgSender(), ABDKMath64x64.mulu(LiquidationNum, 1));
        emit Cloes(_msgSender(), _pid, signedPr.tradePrice);
    }

    function downLiquidation() private view returns (int128) {}

    //  获取TB
    function getTB(bool direction, int128 K)
        public
        view
        returns (int128 _TB_int128)
    {
        uint256 B_uint256 = ABDKMath64x64.mulu(currBtc, 1);
        uint256 K_uint256 = ABDKMath64x64.mulu(K, 1);
        if (direction) {
            // 牛证
            uint256 _TB_uint256 = Math.min(B_uint256, K_uint256);
            _TB_int128 = ABDKMath64x64.fromUInt(_TB_uint256);
        } else {
            // 熊证
            uint256 _TB_uint256 = Math.max(B_uint256, K_uint256);
            _TB_int128 = ABDKMath64x64.fromUInt(_TB_uint256);
        }
    }

    function getPBCT(GetPBCTInfo memory _getPBCTInfo)
        public
        view
        returns (int128)
    {
        int128 l1Orl3;
        int128 l2Orl4;
        int128 omg;
        IConfig.DeltaItem memory _DeltaItem = getDeltaTable(_getPBCTInfo.delta);
        if (_getPBCTInfo.direction) {
            l1Orl3 = _DeltaItem.L1;
            l2Orl4 = _DeltaItem.L2;
            omg = getUpOmg(_getPBCTInfo.delta);
        } else {
            l1Orl3 = _DeltaItem.L3;
            l2Orl4 = _DeltaItem.L4;
            omg = getDownOmg(_getPBCTInfo.delta);
        }
        int128 _tb = getTB(_getPBCTInfo.direction, _getPBCTInfo.K);
        int128 _a1 = ABDKMath64x64.div(_tb, _getPBCTInfo.K);
        int128 _a1_l1 = pow64x64(_a1, l1Orl3);
        int128 _a1_w_l1 = ABDKMath64x64.mul(omg, _a1_l1);
        int128 _a2_l2 = pow64x64(_a1, l2Orl4);
        int128 _a2_w_l2 = ABDKMath64x64.mul(
            ABDKMath64x64.sub(1 * 2**64, omg),
            _a2_l2
        );
        if (!_getPBCTInfo.direction) {
            _a1_w_l1 = ABDKMath64x64.div(omg, _a1_l1);
            _a2_w_l2 = ABDKMath64x64.div(
                ABDKMath64x64.sub(1 * 2**64, omg),
                _a2_l2
            );
        }

        int128 _a = ABDKMath64x64.add(_a1_w_l1, _a2_w_l2);
        int128 _t = ABDKMath64x64.div(_getPBCTInfo.t, SECONDS_IN_A_YEAR);
        int128 _deltaT = ABDKMath64x64.mul(_getPBCTInfo.delta, _t);
        int128 _b = ABDKMath64x64.exp(_deltaT);
        int128 _pbct = ABDKMath64x64.div(_a, _b);
        return _pbct;
    }

    struct GetRlInfo {
        bool direction;
        int128 delta;
    }

    function getRL(GetRlInfo memory _getRlInfo) public view returns (int128) {
        int128 l1Orl3;
        int128 l2Orl4;
        int128 _eta;
        IConfig.DeltaItem memory _DeltaItem = getDeltaTable(_getRlInfo.delta);
        if (_getRlInfo.direction) {
            l1Orl3 = _DeltaItem.L1;
            l2Orl4 = _DeltaItem.L2;
            _eta = config.eta1();
        } else {
            l1Orl3 = _DeltaItem.L3;
            l2Orl4 = _DeltaItem.L4;
            _eta = config.eta2();
        }
        int128 _rl = ABDKMath64x64.div(ABDKMath64x64.mul(l1Orl3, l2Orl4), _eta);
        return _rl;
    }

    // 获取RL
    struct GetRlInfo1 {
        bool direction;
        int128 delta;
        int128 BK;
        int128 K;
    }

    function getRL1(GetRlInfo1 memory _getRlInfo) public view returns (int128) {
        int128 l1Orl3;
        int128 l2Orl4;
        int128 omg;
        IConfig.DeltaItem memory _DeltaItem = getDeltaTable(_getRlInfo.delta);
        if (_getRlInfo.direction) {
            l1Orl3 = _DeltaItem.L1;
            l2Orl4 = _DeltaItem.L2;
            omg = getUpOmg(_getRlInfo.delta);
        } else {
            l1Orl3 = _DeltaItem.L3;
            l2Orl4 = _DeltaItem.L4;
            omg = getDownOmg(_getRlInfo.delta);
        }

        int128 _tb = getTB(true, _getRlInfo.K);

        int128 _a1_l1 = ABDKMath64x64.pow(
            ABDKMath64x64.div(_tb, _getRlInfo.K),
            ABDKMath64x64.mulu(l1Orl3, 1)
        );
        int128 _a1 = ABDKMath64x64.mul(ABDKMath64x64.mul(l1Orl3, omg), _a1_l1);

        int128 _a2_l2 = ABDKMath64x64.pow(
            ABDKMath64x64.div(_tb, _getRlInfo.K),
            ABDKMath64x64.mulu(l2Orl4, 1)
        );
        int128 _a2 = ABDKMath64x64.mul(
            ABDKMath64x64.mul(l2Orl4, ABDKMath64x64.sub(1 * 2**64, omg)),
            _a2_l2
        );
        int128 _b1 = ABDKMath64x64.mul(omg, _a1_l1);
        int128 _b2 = ABDKMath64x64.mul(
            ABDKMath64x64.sub(1 * 2**64, omg),
            _a2_l2
        );
        if (!_getRlInfo.direction) {
            _a1 = ABDKMath64x64.div(ABDKMath64x64.mul(l1Orl3, omg), _a1_l1);
            _a2 = ABDKMath64x64.div(
                ABDKMath64x64.mul(l2Orl4, ABDKMath64x64.sub(1 * 2**64, omg)),
                _a2_l2
            );
            _b1 = ABDKMath64x64.div(omg, _a1_l1);
            _b2 = ABDKMath64x64.div(ABDKMath64x64.sub(1 * 2**64, omg), _a2_l2);
        }
        int128 _a = ABDKMath64x64.add(_a1, _a2);
        int128 _b = ABDKMath64x64.add(_b1, _b2);
        int128 _rl = ABDKMath64x64.div(_a, _b);
        return _rl;
    }

    struct GetPriceimpactInfo {
        int128 rl;
        int128 pbct;
        int128 Q;
    }

    function getPriceimpact(GetPriceimpactInfo memory _GetPriceimpactInfo)
        public
        view
        returns (int128)
    {
        int128 a1 = config.phi();
        int128 _b = ABDKMath64x64.mul(
            _GetPriceimpactInfo.Q,
            _GetPriceimpactInfo.pbct
        );
        int128 _c = ABDKMath64x64.mul(_GetPriceimpactInfo.rl, _b);
        int128 a2 = ABDKMath64x64.sqrt(_c);
        int128 _priceimpact = ABDKMath64x64.mul(a1, a2);
        return _priceimpact;
    }

    struct GetLiquidationNumInfo {
        int128 pbct;
        int128 Q;
        int128 rl;
        int128 priceimpact;
    }

    // 获取平仓价值
    function getLiquidationNum(
        GetLiquidationNumInfo memory _getLiquidationNumInfo
    ) public view returns (int128) {
        int128 _a = ABDKMath64x64.mul(
            ABDKMath64x64.sub(1 * 2**64, config.withdrawFee()),
            ABDKMath64x64.mul(
                _getLiquidationNumInfo.pbct,
                _getLiquidationNumInfo.Q
            )
        );
        int128 _b_1 = ABDKMath64x64.mul(
            _getLiquidationNumInfo.rl,
            _getLiquidationNumInfo.priceimpact
        );
        int128 _b_3 = min128(
            _b_1,
            config.r() // 0.03数值转换
        );
        int128 _b = ABDKMath64x64.add(1 * 2**64, _b_3);
        int128 _liquidationNum = ABDKMath64x64.div(_a, _b);
        return _liquidationNum;
    }

    function min128(int128 a, int128 b) public pure returns (int128) {
        return a < b ? a : b;
    }

    function _mintNft(address _to) internal returns (uint256) {
        _mint(_to, _totalSupply);
        return _totalSupply++;
    }

    function _beforeTokenTransfer(
        address,
        address to,
        uint256 tokenId
    ) internal override {
        _idBalance[to].push(tokenId);
    }

    function _mintCppc(address to, uint256 amount) internal {
        IERC20Interface(charm).issue(to, amount);
    }

    function _burnFor(address from, uint256 amount) internal {
        charm.safeTransferFrom(from, address(this), amount);
        IERC20Interface(charm).burn(amount);
    }
}
