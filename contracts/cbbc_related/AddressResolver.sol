pragma solidity 0.8.3;

// Inheritance
import "./Owned.sol";
import "./MixinResolver.sol";

// Internal references
import "./interfaces/IAddressResolver.sol";
import "./interfaces/IIssuerForCbbcToken.sol";
import "./interfaces/IIssuerForDividendToken.sol";
import "./interfaces/IIssuerForLiquidityToken.sol";


// https://docs.synthetix.io/contracts/source/contracts/addressresolver
contract AddressResolver is Owned, IAddressResolver {
    mapping(bytes32 => address) public repository;

    constructor(address _owner)  Owned(_owner) {}

    /* ========== RESTRICTED FUNCTIONS ========== */

    function importAddresses(bytes32[] calldata names, address[] calldata destinations) external onlyOwner {
        require(names.length == destinations.length, "Input lengths must match");

        for (uint i = 0; i < names.length; i++) {
            bytes32 name = names[i];
            address destination = destinations[i];
            repository[name] = destination;
            emit AddressImported(name, destination);
        }
    }

    /* ========= PUBLIC FUNCTIONS ========== */

    function rebuildCaches(MixinResolver[] calldata destinations) external {
        for (uint i = 0; i < destinations.length; i++) {
            destinations[i].rebuildCache();
        }
    }

    /* ========== VIEWS ========== */

    function areAddressesImported(bytes32[] calldata names, address[] calldata destinations) external view returns (bool) {
        for (uint i = 0; i < names.length; i++) {
            if (repository[names[i]] != destinations[i]) {
                return false;
            }
        }
        return true;
    }

    function getAddress(bytes32 name) external view override returns (address) {
        return repository[name];
    }

    function requireAndGetAddress(bytes32 name, string calldata reason) external view override returns (address) {
        address _foundAddress = repository[name];
        require(_foundAddress != address(0), reason);
        return _foundAddress;
    }


    function getCbbcTokenAddress(bytes32 key) external view override returns (address) {
        IIssuerForCbbcToken issuer = IIssuerForCbbcToken(repository["IssuerForCbbcToken"]);
        require(address(issuer) != address(0), "Cannot find Issuer address");
        return address(issuer.cTokens(key));
    }

    function getDividendTokenAddress(bytes32 key) external view override returns (address) {
        IIssuerForDividendToken issuer = IIssuerForDividendToken(repository["IssuerForDividendToken"]);
        require(address(issuer) != address(0), "Cannot find Issuer address");
        return address(issuer.dTokens(key));
    }

    function getLiquidityTokenAddress(bytes32 key) external view override returns (address) {
        IIssuerForLiquidityToken issuer = IIssuerForLiquidityToken(repository["IssuerForLiquidityToken"]);
        require(address(issuer) != address(0), "Cannot find Issuer address");
        return address(issuer.lTokens(key));
    }
    /* ========== EVENTS ========== */

    event AddressImported(bytes32 name, address destination);
}
