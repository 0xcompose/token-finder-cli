# ERC20 Token Finder CLI

Find ERC20 tokens across chains by symbol right in your terminal!

## Usage Examples:

Search by chain id and symbol

```bash
❯ token 1 USDC
USDC (USDCoin)
  Chain: 1
  Address: 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48
  Decimals: 6
```

2. Search by chain id

```bash
❯ token 42161
1INCH (1inch)
  Chain: 42161
  Address: 0x6314C31A7a1652cE482cffe247E9CB7c3f4BB9aF
  Decimals: 18

AAVE (Aave)
  Chain: 42161
  Address: 0xba5DdD1f9d7F570dc94a51479a000E3BCE967196
  Decimals: 18
```

3. Search by symbol (case insensitive)

```bash
❯ token USDc
USDC (USDCoin)
  Chain: 1
  Address: 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48
  Decimals: 6

USDC (USDCoin)
  Chain: 10
  Address: 0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85
  Decimals: 6

```

4. Find and output token address. Useful in chain of terminal commands

```bash
❯ token -a 1 USDC
0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48
```

## Getting started

```bash
sudo make install
```

`sudo` is required to put `./token.sh` to `/usr/local/bin`

After that you can use:

```bash
token 1 USDC
```

## Quick Address Lookup

Use `-a` or `--only-address` flag to get only the token address (perfect for `cast` commands):

```bash
# Get USDC address on Ethereum
token -a 1 USDC

# Use directly in cast commands
cast call $(token -a 1 USDC) "totalSupply()(uint256)"
cast send $(token -a 42161 USDC) "transfer(address,uint256)" 0x... 1000

# Exit code 1 if not exactly 1 match (0 or multiple)
token -a 1 ETH  # Multiple matches → exits with code 1
```

## How that works?

The script pulls data from `https://tokenlists.org/`, specifically default token list is [Uniswap Labs Default](https://tokenlists.org/token-list?url=https://ipfs.io/ipns/tokens.uniswap.org), which doesn't have a USDT on Arbitrum for some reason 🤷‍♂️

### Custom Token Lists

Provide your own token list via `TOKEN_LIST_URL` environment variable. The cache auto-clears when switching lists:

```bash
# Use Zerion's token list (ENS names auto-resolve via IPFS)
TOKEN_LIST_URL=tokenlist.zerion.eth token 1 USDC

# Or use direct URLs
TOKEN_LIST_URL=https://... token 1 USDC

# Force refresh
token --refresh
```

## Uninstall

```bash
sudo make uninstall
```

`sudo` is required to remove `./token.sh` from `/usr/local/bin`
