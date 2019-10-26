pragma solidity ^0.5.0;

import "../PerlinNoise.sol";

contract PerlinNoiseMock {
    function noise2d(int256 x, int256 y) public pure returns (int256) {
        return PerlinNoise.noise2d(x, y);
    }

    function noise3d(int256 x, int256 y, int256 z) public pure returns (int256) {
        return PerlinNoise.noise3d(x, y, z);
    }

    function ptable(int256 i) public pure returns (int256) {
        return PerlinNoise.ptable(i);
    }
}