// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IIssuerForSatoshiOptions {
    struct SignedPriceInput {
        address tradeToken;
        uint128 tradePrice;
        uint256 nonce;
        uint256 deadline;
        bytes signature;
    }

    function mintTo(
        address _to,
        bool _direction,
        uint128 _delta,
        uint128 _bk,
        uint128 _cppcNum,
        address _strategy,
        SignedPriceInput calldata signedPr
    ) external returns (uint256 pid, uint256 mintBalance);

    function burnFor(
        address _from,
        uint256 _pid,
        uint128 _cAmount,
        SignedPriceInput calldata signedPr
    ) external returns(uint256 _liquidationNum);
}
