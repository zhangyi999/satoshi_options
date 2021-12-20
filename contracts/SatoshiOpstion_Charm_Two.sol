//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import "@openzeppelin/contracts/utils/math/Math.sol";

import "abdk-libraries-solidity/ABDKMath64x64.sol";

import "./libraries/ECDSA.sol";
import "./libraries/SafeToken.sol";
import "./interface/IConfig.sol";

import "./public/BinaryOptions.sol";

contract SatoshiOpstion_Charm_Two is
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
    }
    mapping(uint256 => NftData) private _nftStore;

    modifier onlySigner(SignedPriceInput calldata signedPr) {
        require(checkIdentity(signedPr), "Price Error.");
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
        address _charm,
        IConfig _config
    ) public initializer {
        __Ownable_init();
        __ReentrancyGuard_init();
        __ERC1155_init(uri_);
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

    function checkIdentity(SignedPriceInput calldata signedPr)
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

    function open(
        bool direction,
        uint128 _delta,
        uint128 _bk,
        uint128 _cppcNum,
        SignedPriceInput calldata signedPr
    ) public onlySigner(signedPr) returns (uint256 pid) {
        int128 tradePrice = int128(signedPr.tradePrice);
        int128 K = BinaryOptions.getBk(tradePrice, int128(_bk));

        int128 _pbc = BinaryOptions.getPurchaseQuantity(
            BinaryOptions.GetPurchaseQuantityInfo(
                direction,
                int128(_bk),
                int128(_delta),
                int128(_cppcNum)
            ),
            getDeltaTable(int128(_delta)),
            config.eta1(),
            config.eta2()
        );

        // pbc int128 64*64
        pid = _mintNft(_msgSender(), uint128(_pbc));
        NftData storage nftData = _nftStore[pid];
        nftData.delta = int128(_delta);
        nftData.direction = direction;
        nftData.createTime = block.timestamp;
        nftData.openPrice = tradePrice;
        nftData.bk = int128(_bk);
        nftData.K = K;

        _burnFor(_msgSender(), _cppcNum / (1 << 64));
        emit Open(_msgSender(), pid, signedPr.tradePrice);
        return pid;
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
    function close(
        uint256 _pid,
        uint128 _cAmount,
        SignedPriceInput calldata signedPr
    ) public payable onlySigner(signedPr) {
        NftData storage nftData = _nftStore[_pid];
        int128 LiquidationNum = BinaryOptions.getLiquidationNum(
            BinaryOptions.GetPBCTInfo(
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

        _burnNft(_msgSender(), _pid, _cAmount);
        _mintCppc(_msgSender(), uint128(LiquidationNum / (1 << 64)));
        emit Cloes(_msgSender(), _pid, signedPr.tradePrice, _cAmount);
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

    function _mintCppc(address to, uint256 amount) internal {
        IERC20Interface(charm).issue(to, amount);
    }

    function _burnFor(address from, uint256 amount) internal {
        charm.safeTransferFrom(from, address(this), amount);
        IERC20Interface(charm).burn(amount);
    }
}
