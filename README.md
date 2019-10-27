# solidity-perlin-noise

A Solidity library that implements the Perlin Noise algorithm using 16 bit fixed point arithmetic.

## Design

### Fixed Point Arithmetic

Solidity does not support floating point arithmetic to emulate floating point arithmetic this implementation instead
uses 16 bit fixed point arithmetic. 16 bits arithmetic chosen because it is transferable to 32 bit and 
64 bit architectures.

### Constant Arrays

The library uses unrolled binary lookup trees as a substitute for constant arrays. This allows the code 
to be put in a library instead of having to be deployed as a separate contract.

## Usage

To use the library import it into your code and call one of the noise functions:


```solidity
import "../libraries/PerlinNoise.sol"

contract ExampleContract {
    function sampleNoise() public pure {
        int256 n2d = PerlinNoise.noise2d(32768, 32768);
        int256 n3d = PerlinNoise.noise3d(32768, 32768, 32768);
    }
}
```


All numbers passed to the noise functions must be represented in 16 bit fixed point form. In 16 bit fixed point
form 1.0 is equal to 65536, 0.5 is equal to 32768 and so on. 

To convert the result to a floating point value divide the result 65536.

```js
const nf = (await PerlinNoise.noise2d.call(32768, 32768)).toNumber() / 65536;
```

## Costs

All the costs in this table are approximate and may be within ±100 of the listed value.

| Function | EVM Version | Gas\*     |  
|----------|-------------|-----------|
| Deploy   | Petersburg  | 2,844,459 |
| noise2d  | Petersburg  | 2,651     |
| noise3d  | Petersburg  | 6,403     |

\*Deployment gas cost is the entire estimated transaction amount, all other values are only the execution cost.

## License

The software is released under the [MIT License](LICENSE).
