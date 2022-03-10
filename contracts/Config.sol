//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

contract Config is Ownable {
    // 开仓费率
    int128 public depositFee;
    // 平仓费率
    int128 public withdrawFee;

    int128 public sigma; // 大写Σ，小写σ
    int128 public lambda; // λ
    int128 public eta1; // η1
    int128 public eta2; //η2
    int128 private _p; //
    int128 private _q; //

    int128 public phi; //ϕ
    // int128 alpha; //
    int128 private _pcpct; // pccp价格
    int128 public r; //SettlementBTCPrice 参数 0.03

    struct DeltaItem {
        int128 L1; //2**64  int128
        int128 L2; //2**64  int128
        int128 L3; //2**64  int128
        int128 L4; //2**64  int128
    }
    mapping(int128 => DeltaItem) private _deltaTable;

    mapping(address => mapping(uint128 => bool)) private _checkDelta;

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
    function setConfig(uint128[] calldata _config) public onlyOwner {
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
    function setLTable(DeltaItemInput[] calldata _deltaItem) public onlyOwner {
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

    function addTokenDelta(address _token, uint128[] calldata _dels) external onlyOwner {
        for(uint i = 0; i < _dels.length; i++) {
            _checkDelta[_token][_dels[i]] = true;
        }
    }

    function remvoTokenDelta(address _token, uint128[] calldata _dels) external onlyOwner {
        for(uint i = 0; i < _dels.length; i++) {
            _checkDelta[_token][_dels[i]] = false;
        }
    }

    function checkDelta(address _token, uint128 _delta) external returns(bool) {
        return _checkDelta[_token][_delta];
    }

}