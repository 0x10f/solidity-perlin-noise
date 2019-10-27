const { BN }     = require('@openzeppelin/test-helpers');
const { expect } = require('chai');

const util = require('util');

const PerlinNoiseMock = artifacts.require("PerlinNoiseMock");

contract("PerlinNoise", () => {
    beforeEach(async function() {
        this.noise = await PerlinNoiseMock.new();
    });
});