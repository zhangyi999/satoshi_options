//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

contract Config is Ownable {
    // 开仓费率
    int128 depositFee;
    // 平仓费率
    int128 withdrawFee;

    int128 sigma; // 大写Σ，小写σ
    int128 lambda; // λ
    int128 eta1; // η1
    int128 eta2; //η2
    int128 _p; //
    int128 _q; //

    int128 phi; //ϕ
    // int128 alpha; //
    int128 _pcpct; // pccp价格
    int128 r; //SettlementBTCPrice 参数 0.03

    struct DeltaItem {
        int128 delta; //2**64  int128
        int128 L1; //2**64  int128
        int128 L2; //2**64  int128
        int128 L3; //2**64  int128
        int128 L4; //2**64  int128
    }
    mapping(int128 => DeltaItem) private _deltaTable;

    function p() external view returns(int128) {
        return _p;
    }

    function q() external view returns(int128) {
        return _q;
    }

    function delta(int128 _d) external view returns(DeltaItem memory) {
        return _deltaTable[_d];
    }

    // Only the owner can configureThe parameter type can be controlled
    function SetConfig(uint128[] calldata _config) public onlyOwner {
        depositFee = int128(_config[0]);
        withdrawFee = int128(_config[1]);
        sigma = int128(_config[2]);
        lambda = int128(_config[3]);
        eta1 = int128(_config[4]);
        eta2 = int128(_config[5]);
        _p = int128(_config[6]);
        _q = int128(_config[7]);
        phi = int128(_config[8]);
        _pcpct = int128(_config[9]);
        r = int128(_config[10]);
    }

    struct DeltaItemInput {
        uint128 delta; //2**64  int128
        uint128 L1; //2**64  int128
        uint128 L2; //2**64  int128
        uint128 L3; //2**64  int128
        uint128 L4; //2**64  int128
    }
    function SetLTable(DeltaItemInput[] calldata _deltaItem) public onlyOwner {
        uint256 length = _deltaItem.length;
        for (uint256 i = 0; i < length; i++) {
            DeltaItemInput memory deltaItem = _deltaItem[i];
            int128 _delta = int128(deltaItem.delta);
            _deltaTable[_delta].L1 = int128(deltaItem.L1);
            _deltaTable[_delta].L2 = int128(deltaItem.L2);
            _deltaTable[_delta].L3 = int128(deltaItem.L3);
            _deltaTable[_delta].L4 = int128(deltaItem.L4);
        }
    }

}