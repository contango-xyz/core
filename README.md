# Contango Protocol

Contango is bringing expirables to DeFi. Buy or sell assets at a set price and date in the future without order books or liquidity pools. When a trader opens a position, the protocol borrows on the fixed-rate market, swaps on the spot market, then lends back on the fixed-rate market. Contango offers physical delivery and a minimal price impact for larger trades. Join us at [contango.xyz](https://contango.xyz). 


## Smart Contracts

The smart contracts use an UUSP proxy as entry point, and rely on external libraries to split code/responsibilities whilst keeping the execution context under a single address.
At the moment there's a single implementation of underlying Spot (Uniswap V3), and a single implementation of fixed rate market (Yield Protocol)

## Warning
This code is provided as-is, with no guarantees of any kind.

### Pre Requisites
Before running any command, make sure to install dependencies:

```
$ npm i
$ forge install
```

### Lint

```
$ npm run lint
```

### Coverage
Generate the code coverage report:

```
$ npm run coverage
```

### Test
Be sure to have an `.env` file located at root (or to have the following ENV variables)
`MAINNET_URL=<your rpc url>` 
`ARBITRUM_URL=<your rpc url>` 

Compile and test the smart contracts with [Foundry](https://getfoundry.sh/):

```
$ npm run test
```

## Bug Bounty
Contango is not offering bounties for bugs disclosed whilst our audits are in place, but if you wish to report a bug, please do so at [security@contango.xyz](mailto:security@contango.xyz). Please include full details of the vulnerability and steps/code to reproduce. We ask that you permit us time to review and remediate any findings before public disclosure.

## License
Unless the opposite is explicitly stated on the file header, all files in this repository are released under the [BSL 1.1](https://github.com/contango-xyz/core/blob/master/LICENSE.md) license. 
