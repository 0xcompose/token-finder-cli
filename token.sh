#!/bin/bash

# Configuration
CACHE_DIR="$HOME/.cache/token-cli"
CACHE_FILE="$CACHE_DIR/tokens.json"
CACHE_URL_FILE="$CACHE_DIR/tokens.url"
CACHE_MAX_AGE=86400  # 24 hours in seconds

# Token list URL (can be overridden with TOKEN_LIST_URL env var)
TOKEN_LIST_URL="${TOKEN_LIST_URL:-https://ipfs.io/ipns/tokens.uniswap.org}"

# Auto-detect ENS names and prepend IPFS gateway
if [[ "$TOKEN_LIST_URL" =~ \.eth$ ]]; then
    TOKEN_LIST_URL="https://ipfs.io/ipns/$TOKEN_LIST_URL"
fi

# Fallback to local files if exists
FALLBACK_DIR="$(dirname "$0")"

# Function to show usage
usage() {
    echo "Usage: token [OPTIONS] [CHAIN_ID] [SYMBOL]"
    echo ""
    echo "Options:"
    echo "  --refresh         Force refresh token list from web"
    echo "  -a, --only-address  Output only address (exits with code 1 if not exactly 1 match)"
    echo "  -h, --help        Show this help"
    echo ""
    echo "Arguments:"
    echo "  CHAIN_ID     Chain ID (number, optional)"
    echo "  SYMBOL       Token symbol (optional, case-insensitive)"
    echo ""
    echo "Environment Variables:"
    echo "  TOKEN_LIST_URL    Custom token list URL (supports ENS names)"
    echo "                    Default: https://ipfs.io/ipns/tokens.uniswap.org"
    echo ""
    echo "Examples:"
    echo "  token USDC                                    # Find USDC on all chains"
    echo "  token 1 USDC                                  # Find USDC on Ethereum"
    echo "  token 42161                                   # All tokens on Arbitrum"
    echo "  token 1 ETH                                   # Find ETH tokens on Ethereum"
    echo "  token --refresh                               # Update token list from web"
    echo "  TOKEN_LIST_URL=https://... token USDC         # Use custom token list"
    echo "  TOKEN_LIST_URL=tokenlist.zerion.eth token 1   # Use ENS name (auto-resolves)"
    echo ""
    echo "  # Use with cast commands:"
    echo "  cast call \$(token -a 1 USDC) \"totalSupply()(uint256)\""
    echo "  cast send \$(token -a 42161 USDC) \"transfer(address,uint256)\" 0x... 1000"
    exit 1
}

# Parse arguments
CHAIN=""
SYMBOL=""
FORCE_REFRESH=0
ONLY_ADDRESS=0

while [[ $# -gt 0 ]]; do
    case $1 in
        --refresh)
            FORCE_REFRESH=1
            shift
            ;;
        -a|--only-address)
            ONLY_ADDRESS=1
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            # Positional arguments
            if [[ -z "$CHAIN" && -z "$SYMBOL" ]]; then
                if [[ "$1" =~ ^[0-9]+$ ]]; then
                    CHAIN="$1"
                else
                    SYMBOL="$1"
                fi
            elif [[ -n "$CHAIN" || -n "$SYMBOL" ]] && [[ $# -eq 1 ]]; then
                if [[ -z "$SYMBOL" ]]; then
                    SYMBOL="$1"
                fi
            else
                echo "Error: Invalid arguments"
                usage
            fi
            shift
            ;;
    esac
done

# Check dependencies
if ! command -v jq &> /dev/null; then
    echo "Error: jq is not installed. Install it with: brew install jq"
    exit 1
fi

if ! command -v curl &> /dev/null; then
    echo "Error: curl is not installed. Install it with: brew install curl"
    exit 1
fi

# Ensure cache directory exists
mkdir -p "$CACHE_DIR"

# Function to fetch token list
fetch_token_list() {
    echo "Fetching token list from $TOKEN_LIST_URL..." >&2
    if curl -s -f -o "$CACHE_FILE.tmp" "$TOKEN_LIST_URL"; then
        mv "$CACHE_FILE.tmp" "$CACHE_FILE"
        echo "$TOKEN_LIST_URL" > "$CACHE_URL_FILE"
        echo "✓ Token list updated" >&2
        return 0
    else
        rm -f "$CACHE_FILE.tmp"
        echo "✗ Failed to fetch token list" >&2
        return 1
    fi
}

# Determine which token list to use
TOKEN_FILE=""

# Check if cache URL matches current URL
CACHE_INVALID=0
if [[ -f "$CACHE_URL_FILE" ]]; then
    CACHED_URL=$(cat "$CACHE_URL_FILE")
    if [[ "$CACHED_URL" != "$TOKEN_LIST_URL" ]]; then
        echo "⚠ Token list URL changed, invalidating cache..." >&2
        CACHE_INVALID=1
        rm -f "$CACHE_FILE" "$CACHE_URL_FILE"
    fi
fi

if [[ $FORCE_REFRESH -eq 1 ]]; then
    # Force refresh requested
    if fetch_token_list; then
        TOKEN_FILE="$CACHE_FILE"
    fi
elif [[ -f "$CACHE_FILE" ]] && [[ $CACHE_INVALID -eq 0 ]]; then
    # Check cache age
    CACHE_AGE=$(($(date +%s) - $(stat -f %m "$CACHE_FILE" 2>/dev/null || stat -c %Y "$CACHE_FILE" 2>/dev/null)))
    
    if [[ $CACHE_AGE -lt $CACHE_MAX_AGE ]]; then
        # Cache is fresh
        TOKEN_FILE="$CACHE_FILE"
    else
        # Cache is stale, try to refresh
        if fetch_token_list; then
            TOKEN_FILE="$CACHE_FILE"
        else
            # Use stale cache if refresh failed
            echo "⚠ Using stale cache (failed to refresh)" >&2
            TOKEN_FILE="$CACHE_FILE"
        fi
    fi
else
    # No cache exists, fetch it
    if fetch_token_list; then
        TOKEN_FILE="$CACHE_FILE"
    fi
fi

# Fallback to local files if network fetch failed
if [[ -z "$TOKEN_FILE" ]] || [[ ! -f "$TOKEN_FILE" ]]; then
    echo "⚠ Using local fallback files" >&2
    # Search local JSON files as fallback
    for file in "$FALLBACK_DIR"/*.json; do
        if [[ -f "$file" ]]; then
            TOKEN_FILE="$file"
            break
        fi
    done
fi

# Check if we have any token file to work with
if [[ -z "$TOKEN_FILE" ]] || [[ ! -f "$TOKEN_FILE" ]]; then
    echo "Error: No token list available. Try: token --refresh" >&2
    exit 1
fi

# If only --refresh was passed, exit after updating
if [[ $FORCE_REFRESH -eq 1 ]] && [[ -z "$CHAIN" ]] && [[ -z "$SYMBOL" ]]; then
    exit 0
fi

# Build jq filter
FILTER=".tokens[]"

if [[ -n "$CHAIN" ]]; then
    FILTER="$FILTER | select(.chainId == $CHAIN)"
fi

if [[ -n "$SYMBOL" ]]; then
    SYMBOL_UPPER=$(echo "$SYMBOL" | tr '[:lower:]' '[:upper:]')
    FILTER="$FILTER | select(.symbol | ascii_upcase | contains(\"$SYMBOL_UPPER\"))"
fi

# Search tokens
if [[ $ONLY_ADDRESS -eq 1 ]]; then
    # For only-address mode, get addresses (compatible with bash 3.x)
    ADDRESSES=$(jq -r "$FILTER | .address" "$TOKEN_FILE" 2>/dev/null)
    COUNT=$(echo "$ADDRESSES" | grep -c '^0x' || true)
    
    if [[ $COUNT -eq 1 ]]; then
        # Exactly one match - output address
        echo "$ADDRESSES"
        exit 0
    elif [[ $COUNT -eq 0 ]]; then
        # No matches
        echo "Error: No tokens found" >&2
        exit 1
    else
        # Multiple matches
        echo "Error: Multiple tokens found ($COUNT matches). Be more specific." >&2
        exit 1
    fi
else
    # Normal mode - full output
    RESULTS=$(jq -r "$FILTER | \"\\(.symbol) (\\(.name))\n  Chain: \\(.chainId)\n  Address: \\(.address)\n  Decimals: \\(.decimals)\n\"" "$TOKEN_FILE" 2>/dev/null)
    
    if [[ -n "$RESULTS" ]]; then
        echo "$RESULTS"
    else
        echo "No tokens found"
        exit 1
    fi
fi