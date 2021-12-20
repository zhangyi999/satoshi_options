// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IConfig {
    struct DeltaItem {
        int128 L1; //2**64  int128
        int128 L2; //2**64  int128
        int128 L3; //2**64  int128
        int128 L4; //2**64  int128
    }
    function depositFee() external view returns(int128);
    function withdrawFee() external view returns(int128);
    function sigma() external view returns(int128);
    function lambda() external view returns(int128);
    function eta1() external view returns(int128);
    function eta2() external view returns(int128);
    function p() external view returns(int128);
    function q() external view returns(int128);
    function phi() external view returns(int128);
    function r() external view returns(int128);
    function delta(int128 _d) external view returns(DeltaItem memory);
}
