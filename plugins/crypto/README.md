# crypto

Prices of the coins you follow, in the bar, with the change over the last day,
from CoinGecko's free API. Clicking a coin opens it on CoinGecko.

## Settings

| setting | default | |
| --- | --- | --- |
| `crypto.coins` | `"bitcoin, ethereum"` | CoinGecko ids, separated by commas |
| `crypto.currency` | `"usd"` | what prices are in |
| `crypto.intervalMinutes` | `5` | how often to ask |

## Methods and topic

- `crypto.refresh`: ask now.
- The topic `crypto` is `{ currency, coins: [{ id, symbol, name, price, change }], updated, error }`;
  `change` is the per cent over 24 hours, `error` why the last try failed.
