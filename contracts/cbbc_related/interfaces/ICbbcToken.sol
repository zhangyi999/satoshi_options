pragma solidity =0.8.3;

interface ICbbcToken{
    enum CbbcType {
    bear,
    bull
    }

    enum tradeDirection{
        buyCbbc,
        sellCbbc
    }

    struct CbbcTokenSettings{
        bytes32 _settleTokenKey;
        bytes32 _tradeTokenKey;
        uint8 _leverage;
        CbbcType _cbbcType;
    }


//    function approve(address spender, uint value) external returns (bool);
    function transfer(address to, uint value) external returns (bool);
    function transferFrom(address from, address to, uint value) external returns (bool);

    //function owner() external view returns (address);
    function currencyKey() external view returns(bytes32);

    function tradeTokenKey() external view returns(bytes32);
    
    function settleTokenKey() external view returns(bytes32);
    
    function leverage() external view returns(uint8);
    
    function cbbcType() external view returns(CbbcType);
    
    function settleTokenAddress() external view returns (address);
/*    
    function tradeTokenAddress() external view returns (address);
*/
    function currentCbbcPrice() external view returns(uint);
    function getCbbcPrice(
        uint settleAmount,
        uint cbbcAmount,
        tradeDirection direction)
        external view returns (uint);

    function rebasePrice() external view returns(uint);
    function rebaseTimestamp() external view returns(uint);
//    function totalSupply() external view returns (uint256);
    function rebase(uint256 epoch, int256 supplyDelta) external returns (uint256);

    function rebasePolicy() external view returns(address);
//    function setRebasePolicy(address rebasePolicy_) external;

    function issue(address account, uint amount) external;
    function burn(address account, uint amount) external returns (bool);
}