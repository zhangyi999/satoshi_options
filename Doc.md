# SatoshiOptions docs

## 合约

* `contracts/Route.sol`: 路由合约
* `contracts/SatoshiOptions_Charm.sol`: 期权合约，管理 nft
* `contracts/public/BinaryOptions.sol`: 指数期权算法
* `contracts/public/LinearOption.sol`: 指数线性算法

## 接口

数据类型转换 `getInt128`

```js
// uint256 -> int128
const BigNumber = require('bignumber.js');
function getInt128(num) {
    let _num = (new BigNumber(num).multipliedBy(new BigNumber(2).pow(64))).toString(10);
    _num = _num.split('.')[0];
    return _num
}
```

价格签名 `getPriceData`

```js
const web3 = new Web3();
const abi = require('ethereumjs-abi');
const PRIVATE_KEY = "0x1b502936fcfa1381d1bc454dac74f1a2d2c7e4ed7634fe1acc57b0fa32c5f26e";  
let nonce = new BigNumber(0);
const SIGNER_ADDRESS = web3.eth.accounts.privateKeyToAccount(PRIVATE_KEY).address; //2109

// tokenAddress: string, tradePrice: uint128, nonce: number
function getPriceData(tokenAddress, tradePrice, nonce) {
    const parameterTypes = ["address", "uint128", "uint256", "address"];
    const parameterValues = [tokenAddress, tradePrice.toString(), nonce, SIGNER_ADDRESS];
    const hash = "0x" + abi.soliditySHA3(parameterTypes, parameterValues).toString("hex");
    const signature_ = web3.eth.accounts.sign(hash, PRIVATE_KEY);

    return {
        tokenAddress,
        tradePrice: tradePrice.toString(),
        nonce,
        signature: signature_.signature
    };
}
```

开仓 `buyOptions(bool direction,uint128 _delta,uint128 _bk,uint128 _cppcNum,address _strategy,IIssuerForSatoshiOptions.SignedPriceInput) -> (uint256 pid, uint256 mintBalance)`

```js
const web3 = new Web3();

// Route.sol
const options = Router()

// 根据参数获得开仓数量
const signature = getPriceData(tokenAddress, tradePrice, nonce)
const methods = await options.methods.buyOptions(
    true, // true 开多，false 看空
    getInt128(delta), // delta
    getInt128(2), // 杠杆
    getInt128(1e18), // 金额
    strategyAddress, // 策略 合约地址 ：contracts/public/BinaryOptions.sol | contracts/public/LinearOption.sol
    [
        tokenAddress, // 标的币种
        tradePrice, // 交易价格
        nonce, // 签名 有效 nonce
        signature // 签名
    ]
)


const calls = await methods.call()
// 开仓数量 wei
calls.mintBalance
// 仓位 id
calls.pid

// 开仓上链
const tx = await methods.send()
```

获取仓位数量 `balanceOf(address, uint256) -> string`
```js
// SatoshiOpstion_Charm.sol
const options = SatoshiOpstion_Charm()

// 获得开仓数量
let balanceNFT = await SatoshiOpstion_Charm.methods.balanceOf(ownerAddress, pid).call()
```

获取仓位详情 `getNftInfoFor(uint256 _pid) -> NftData`
```js
// SatoshiOpstion_Charm.sol
const options = SatoshiOpstion_Charm()

// 获得开仓详情
const NftData = await SatoshiOpstion_Charm.methods.getNftInfoFor(pid).call()

// NftData.delta : delta
// NftData.createTime : 开仓时间
// NftData.openPrice : 开仓价格
// NftData.direction : 方向
// NftData.bk : 杠杆
// NftData.K : 目标价
// NftData.tradeToken : 交易 token
// NftData.strategy : 期权策略合约地址
```



平仓 `sellOptions(uint256 pid, uint128 amount, IIssuerForSatoshiOptions.SignedPriceInput) -> string`

```js
const web3 = new Web3();

// Route.sol
const options = Router()

// 根据参数获得开仓数量
const signature = getPriceData(tokenAddress, tradePrice, nonce)
const methods = await options.methods.sellOptions(
    pid, // 仓位id: number
    amount, // 平仓数量: string
    [
        tokenAddress, // 标的币种
        tradePrice, // 交易价格
        nonce, // 签名 有效 nonce
        signature // 签名
    ]
)


// 平仓后可以获得的代币奖励
const tokens = await methods.call()

// 平仓上链
const tx = await methods.send()
```


<!-- WETH  0x791229928Be5F33194E779787b63555D32F8AA9E
BTC  0x1d8E11b10e35AC2E355b39D8e0798D25Cd621837
Charm  0x38c2A5a38365b50383f51cfD500a04501e4a6109
config address:  0x1E9a5746a4ba4355bf89CAF331Ae51ce00fF9eb8
set config hash:  0x1869c3e0fd7cbf6f5f49aad57cb7fd60e71661bbc9c70fa6dfe431bd34eb08ea
set LTable hash:  0x2a6665a3c647f32e6cd2bbe8979f13035ec844bd202fe0bf8e975cc63dc4aaa1
addTokenDelta hash:  0xf576a8af9aca5ccd3184ac8ed44a7b60ce998202d28916987d39e2baaaa9e7a9
BinaryOptions tp:  0x0Ee4454F6FD8c64e5633f34bF844105450257009
LinearOptions tp:  0xEd95A8a9421AbBC5474a922bF6736C37292aF68C
SatoshiOpstion_Charm to:  0xaBDA68F785Dc76e8556B6cF4f9e4D7CD215BD1dd
set siger hash:  0xec8316b388b8505ff5611b4fcc1e5f38a4d5954954bbdfcc96fdf10be40ec975
setStrategy hash:  0x884874e748926a28a94dec941e16aa2d18b86993f8a167d7b766bdd96b785b6a
setStrategy hash:  0x5b83a734ef6ed7562a2886ae1e6cf19c7f97415eb30f0849315f74fc32f04bb2
router to  0x34E248C842354669E38532Ec5d9c906c5018B54E
setRoute hash:  0x6b1480eb60a4eddc79069a14e3c7b56b7878d2e1b2ef898e0d31765fe353e473
setupMinterRole hash:  0x394991ad6ee0233e8b482546918b85ee6d525f12dbebae95057397ce8473c54d
BTC mint hash:  0x6ee6823f36aa3b6926957a299dfeacce3a2e92a93135503f085d5526377ae337 -->