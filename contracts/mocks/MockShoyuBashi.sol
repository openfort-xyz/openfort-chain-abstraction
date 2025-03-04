import {IAdapter} from "@hashi/interfaces/IAdapter.sol";
import {IHashi} from "@hashi/interfaces/IHashi.sol";
import {IShoyuBashi} from "@hashi/interfaces/IShoyuBashi.sol";

contract MockShoyuBashi is IShoyuBashi {
    // https://sepolia.basescan.org/block/22479849
    bytes32 public constant BASE_SEPOLIA_BLOCK_22479849_HASH = 0xbe3b16f865b4bd897ceb1000521148a78cf4b3028a4669bb5e67059308d0e561;

    function getThresholdHash(uint256, uint256) external view returns (bytes32) {
        return BASE_SEPOLIA_BLOCK_22479849_HASH;
    }

    function disableAdapters(uint256, IAdapter[] memory) external {
        revert("Not implemented");
    }

    function enableAdapters(uint256, IAdapter[] memory, uint256) external {
        revert("Not implemented");
    }

    function getUnanimousHash(uint256, uint256) external view returns (bytes32) {
        revert("Not implemented");
    }

    function getHash(uint256, uint256, IAdapter[] memory) external view returns (bytes32) {
        revert("Not implemented");
    }

    function setThreshold(uint256, uint256) external {
        revert("Not implemented");
    }

    function setHashi(IHashi) external {
        revert("Not implemented");
    }

    // IShuSho
    function checkAdapterOrderAndValidity(uint256, IAdapter[] memory) external view {
        revert("Not implemented");
    }

    function getAdapterLink(uint256, IAdapter) external view returns (Link memory) {
        revert("Not implemented");
    }

    function getAdapters(uint256) external view returns (IAdapter[] memory) {
        revert("Not implemented");
    }

    function getDomain(uint256) external view returns (Domain memory) {
        revert("Not implemented");
    }

    function getThresholdAndCount(uint256) external view returns (uint256, uint256) {
        revert("Not implemented");
    }

    function hashi() external view returns (IHashi) {
        revert("Not implemented");
    }
}
