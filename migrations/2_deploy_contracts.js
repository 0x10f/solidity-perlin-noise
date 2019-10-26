const PerlinNoise = artifacts.require("PerlinNoise");
const PerlinNoiseMock = artifacts.require("PerlinNoiseMock");

module.exports = function(deployer) {
    deployer.deploy(PerlinNoise);
    deployer.link(PerlinNoise, PerlinNoiseMock);
    deployer.deploy(PerlinNoiseMock);
};