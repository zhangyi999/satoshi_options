pragma solidity = 0.8.3;

//import "../interfaces/ILiquidityToken.sol";
import "../interfaces/ICbbcToken.sol";
//import "../interfaces/ICbbcRouter.sol";
//import "../interfaces/IRebasePolicy.sol";
//import "../interfaces/IMarketOracle.sol";
//import "./Ownable.sol";
//import "../interfaces/IERC20.sol";

import "./Math.sol";
//import "./SafeMath.sol";
import "./SafeMathInt.sol";

library CbbcLibrary {
    struct marketData {
            int beta ; // real beta * 10**3; beta = coefficient of regressiong (tradeToken/USDT return) on (settleToken/USDT return)
            uint alpha_buy; // uint, initially alpha = 4; price impact coefficient
            uint alpha_sell; // uint, initially alpha = 6;
            uint baSpread; // bid-ask spread; real * 10**18; bid-ask spread of tradeToken/USDT price
            uint iRate; // interest rate of tradeToken; = actual interest rate * 10 ** 6, e.g., 10% => 10**5;
            uint sigma; // daily price volatility, real * 10**18; usually 2000 for BTC
            uint dailyVolume; // daily tradinng volume; in tradeToken decimal; usually 2000 * 10**18 for BTC
    }
    struct priceData{
        uint settleTokenPrice; // price of settleToken in USDT; real * 10**18;
        uint rebasePrice; // tradeToken price at rebaseTimestamp
        uint rebaseTimestamp; // timestamp of last rebasing operation
        uint currentPrice; // tradeToken price at currentTimestamp
        uint currentTimestamp; // timestamp of current block
    }
    struct cbbcTokenData{
        bytes32 settleToken;
        bytes32 tradeToken;
        uint leverage;
        ICbbcToken.CbbcType cbbcType; // bear or bull
        uint settleTokenDecimals;
        uint tradeTokenDecimals;
    }
//    uint constant private BLOCKNUMBER_DIFF = 1;// traders are required to use current or previous tradeToken price; stale price may cause risk-free arbitrage
/*
    // calculates the CREATE2 address for a cbbc without making any external calls
    function liquidityTokenFor(address owner,
                                address factory,
                                address settleToken)
                internal pure returns (address liquidityToken) {
        liquidityToken = address(bytes20(keccak256(abi.encodePacked(
                hex'ff',
                owner,
                keccak256(abi.encodePacked(factory, settleToken)),
                hex'3c248ace674bd24855bda2a577e502562c0687c9fbf9b676452b95df823a8394' //TODO: init code hash
            ))));
    }

    function cbbcTokenFor(address factory,
                          address settleToken,
                          address tradeToken,
                          uint8 leverage,
                          ICbbcToken.CbbcType cbbcType)
                 internal pure returns (address cbbc) {
        cbbc = address(bytes20(keccak256(abi.encodePacked(
                hex'ff',
                factory,
                keccak256(abi.encodePacked(settleToken,
                                          tradeToken,
                                          leverage,
                                          cbbcType)), // TODO: check this? do we need _uintToString
                hex'96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f' //TODO: init code hash, replace with cbbcToken init code hash?
            ))));
    }
*/
    /**
    * @dev Compute price impact. We simulate the trading process in centralized exchanges, like NYSE, SHSE, SZSE.  Trading brings in price impact. The more you trade, the larger the price impact is. For the price impact formula, see, https://mfe.baruch.cuny.edu/wp-content/uploads/2017/05/Chicago2016OptimalExecution.pdf
    * @param priceData_ priceData
    * @param cbbcTokenData_ cbbcTokenData
    * @param marketData_ marketData
    * @param settleAmount A uint256 value. The amount of settletoken you spend on buying cbbc.
    * @param cbbcAmount A uint256 value. The amount of cbbc you are selling.
    * @param direction tradeDirection. Buy or sell cbbc.
    * @return priceImpact A uint256 value
    */
    function _computePriceImpact(priceData memory priceData_,
                                    cbbcTokenData memory cbbcTokenData_,
                                    marketData memory marketData_,
                                    uint settleAmount,
                                    uint cbbcAmount,
                                    ICbbcToken.tradeDirection direction)
                internal pure returns(uint priceImpact){
        uint alpha;
        if((direction == ICbbcToken.tradeDirection.buyCbbc && cbbcTokenData_.cbbcType == ICbbcToken.CbbcType.bull) || (direction == ICbbcToken.tradeDirection.sellCbbc && cbbcTokenData_.cbbcType == ICbbcToken.CbbcType.bear)){
            alpha = marketData_.alpha_buy;
        }else{
            alpha = marketData_.alpha_sell;
        }

        if(settleAmount == 0 && cbbcAmount == 0){
            priceImpact = 0;
        }else{
            uint tempCbbcPrice =  _computeCbbcPrice(priceData_,
                            cbbcTokenData_,
                            marketData_,
                            0,
                            direction);
            uint settlePrice = priceData_.settleTokenPrice; //settle token price
            uint amountAdjusted = (settleAmount + cbbcAmount * tempCbbcPrice / (10**18) * (10 ** cbbcTokenData_.settleTokenDecimals) /(10**18)) * cbbcTokenData_.leverage * settlePrice / (10 ** cbbcTokenData_.settleTokenDecimals) * (10 ** 18) / priceData_.currentPrice;
            priceImpact = marketData_.baSpread + alpha * marketData_.sigma * Math.sqrt(amountAdjusted * (10**18) / marketData_.dailyVolume)/(10**9);
        }
    }

    /**
    * @dev Compute cbbc price, given the price impact calculated using _computePriceImpact
    * @param priceData_ priceData
    * @param cbbcTokenData_ cbbcTokenData
    * @param marketData_ marketData
    * @param priceImpact A uint256 value.
    * @param direction tradeDirection. Buy or sell cbbc.
    * @return cbbcPrice A uint256 value
    */
    function _computeCbbcPrice(priceData memory priceData_,
                                cbbcTokenData memory cbbcTokenData_,
                                marketData memory marketData_,
                                uint priceImpact,
                                ICbbcToken.tradeDirection direction)
                internal pure returns (uint cbbcPrice){
            uint rebasePrice = priceData_.rebasePrice;
            uint currentPrice = priceData_.currentPrice;
            uint leverage = cbbcTokenData_.leverage;
            int beta = marketData_.beta;
            uint highPrice;
            uint lowPrice;
            uint tempNum;
            uint tempDen;

            if(cbbcTokenData_.cbbcType == ICbbcToken.CbbcType.bull){
                highPrice = (leverage * 10 + 5) * rebasePrice / leverage / 10;
                lowPrice = (leverage * 10 - 7) * rebasePrice / leverage / 10;

                if(currentPrice < lowPrice){
                    currentPrice = lowPrice;
                }else if(currentPrice > highPrice){
                    currentPrice = highPrice;
                }

                if(direction == ICbbcToken.tradeDirection.buyCbbc){
                    currentPrice += priceImpact;
                    require(currentPrice <= highPrice, "CBBC: PRICE_IMPACT_TOO_HIGH");
                }else{
                    currentPrice -= adjustLiability(priceImpact, currentPrice);
                }
                if(beta > 0){
                    tempNum = currentPrice * 1000 + SafeMathInt.abs(beta) * (highPrice - currentPrice) * (currentPrice - lowPrice) / currentPrice;
                    tempDen = rebasePrice * 1000 + SafeMathInt.abs(beta) * (highPrice - rebasePrice) * (rebasePrice - lowPrice) / rebasePrice;
                } else {
                    tempNum = currentPrice * 1000 - SafeMathInt.abs(beta) * (highPrice - currentPrice) * (currentPrice - lowPrice) / currentPrice;
                    tempDen = rebasePrice * 1000 - SafeMathInt.abs(beta) * (highPrice - rebasePrice) * (rebasePrice - lowPrice) / rebasePrice;
                }

                cbbcPrice = leverage * tempNum * (10**18) / tempDen > (leverage - 1) * (10**12) * (1000000*365*86400 + marketData_.iRate * (priceData_.currentTimestamp - priceData_.rebaseTimestamp)) / (365*86400) + 10**14 ? leverage * tempNum * (10**18) / tempDen - (leverage - 1) * (10**12) * (1000000*365*86400 + marketData_.iRate * (priceData_.currentTimestamp - priceData_.rebaseTimestamp)) / (365*86400) : 10**14;// 12 = 18 - 6
            }else if(cbbcTokenData_.cbbcType == ICbbcToken.CbbcType.bear){
                highPrice = (leverage * 10 + 7) * rebasePrice / leverage / 10;
                lowPrice = (leverage * 10 - 5) * rebasePrice / leverage / 10;

                if(currentPrice < lowPrice){
                    currentPrice = lowPrice;
                }else if(currentPrice > highPrice){
                    currentPrice = highPrice;
                }

                if(direction == ICbbcToken.tradeDirection.buyCbbc){
                    currentPrice -= adjustLiability(priceImpact, currentPrice);
               }else{
                   currentPrice += priceImpact;
                   require(currentPrice <= highPrice, "CBBC: PRICE_IMPACT_TOO_HIGH");
               }
                if(beta > 0){
                    tempNum = (currentPrice * 1000 + SafeMathInt.abs(beta) * (highPrice - currentPrice) * (currentPrice - lowPrice) / currentPrice) * (marketData_.iRate * (priceData_.currentTimestamp - priceData_.rebaseTimestamp) + 1000000*365*86400) / (1000000*365*86400);
                    tempDen = rebasePrice * 1000 + SafeMathInt.abs(beta) * (highPrice - rebasePrice) * (rebasePrice - lowPrice) / rebasePrice;
                }else{
                    tempNum = (currentPrice * 1000 - SafeMathInt.abs(beta) * (highPrice - currentPrice) * (currentPrice - lowPrice) / currentPrice) * (marketData_.iRate * (priceData_.currentTimestamp - priceData_.rebaseTimestamp) + 1000000*365*86400) / (1000000*365*86400);
                    tempDen = rebasePrice * 1000 - SafeMathInt.abs(beta) * (highPrice - rebasePrice) * (rebasePrice - lowPrice) / rebasePrice;
                }

                cbbcPrice = (leverage + 1) * (10**18) > leverage * tempNum * (10**18) / tempDen + (10**14) ? (leverage + 1) * (10**18) - leverage * tempNum * (10**18) / tempDen : 10**14;
            }else{
                revert("CBBC:WRONG_TYPE");
            }
    }

    /**
    * @dev adjust totalLiabilities, to make sure totalLiabilities <= 0.99 * balance.
    * @param totalLiabilities A uint256 value. The amount of liability the pool owes
    * @param balance A uint256 value. The amount of asset the pool owns
    * @return adjusted liability. A uint256 value
    */
    function adjustLiability(uint totalLiabilities, uint balance) internal pure returns(uint){
        uint liabilityAdjusted;
        if(balance == 0){
            return 0; // liabilityAdjusted would be 0 if totalLiabilities = 0.
        }
        if(totalLiabilities < balance * 19 / 20){
            liabilityAdjusted = totalLiabilities;
        }else{
            liabilityAdjusted = balance * 19 / 20 + balance * (totalLiabilities - balance * 19 / 20) * 4 / (100 * totalLiabilities);
        }
        assert(liabilityAdjusted < balance);
        return liabilityAdjusted;
    }

}