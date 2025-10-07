# KipuBank v2 – Release Notes

KipuBank v2 brings role-based access control, fund recovery tools, a USD-based withdrawal cap powered by Chainlink, and ERC‑20 multi‑token support while preserving the original ETH vault workflow and security model.

## Highlights

- **Access control (OpenZeppelin AccessControl)**
  - Roles: `DEFAULT_ADMIN_ROLE`, `RECOVERY_ROLE`
  - Keeps `owner` and `onlyOwner` where applicable

- **Administrative recovery/correction**
  - Functions: `adminReassignVault`, `adminAssignExcessToUser`, `adminTopUpUser`, `adminWithdrawFromUser`
  - Events: `VaultReassigned`, `ExcessAssigned`, `AdminTopUp`, `AdminWithdrawFromUser`

- **Chainlink Price Feed (ETH/USD) integration**
  - `getEthUsdPrice8()` normalized to 8 decimals
  - `quoteWeiInUsd8()` converts wei → USD (8 decimals)
  - Enforces a per‑withdrawal cap of 1,000 USD (8 decimals) in `withdraw()`
  - Event: `PriceFeedUpdated` (when applicable)

- **Multi‑token (ERC‑20) support**
  - `depositERC20()`, `withdrawERC20()` using `SafeERC20` (fee‑on‑transfer friendly)
  - Per‑token balances/accounting: `erc20Vaults`, `totalTokenBalance`
  - Per‑token capacity: `tokenCap` + `setTokenCap()`
  - Events: `ERC20Deposit`, `ERC20Withdrawal`, `TokenCapUpdated`

## Breaking changes

- **Constructor signature:** now requires the Chainlink ETH/USD price feed address.
  - `constructor(uint256 _bankCap, uint256 _withdrawalLimit, address _ethUsdFeed)`
- **Withdrawals:** ETH withdrawals are additionally capped at 1,000 USD (8‑decimal scale) based on the oracle price.
- **ABI:** New functions and events were added for recovery and ERC‑20 support.

## New/Updated functions (selection)

- Access control and recovery:
  - `adminReassignVault(address fromUser, address toUser, uint256 amount)`
  - `adminAssignExcessToUser(address user, uint256 amount)`
  - `adminTopUpUser(address user)` (payable)
  - `adminWithdrawFromUser(address fromUser, address payable to, uint256 amount)`
- Chainlink pricing:
  - `getEthUsdPrice8()`
  - `quoteWeiInUsd8(uint256 amountWei)`
- ERC‑20:
  - `depositERC20(address token, uint256 amount)`
  - `withdrawERC20(address token, uint256 amount)`
  - `setTokenCap(address token, uint256 newCap)`
  - `getVaultBalanceERC20(address token)`

## Deployment (v2) – Remix quick start

- Compile with Solidity `0.8.20`.
- Deploy with:
  - `_bankCap`: e.g. `100 ether`
  - `_withdrawalLimit`: if you rely mainly on the USD cap, set a high value (e.g. `1_000_000 ether`)
  - `_ethUsdFeed`: ETH/USD price feed address for your network (8 decimals)
    - Mainnet: `0x5f4ec3df9cbd43714fe2740f5e3616155c5b8419`
    - Sepolia: `0x694AA1769357215DE4FAC081bf1f309aDC325306`
- After deploy, you can:
  - Use `deposit()` for ETH and `depositERC20(token, amount)` for tokens (approve first).
  - Use `withdraw()` for ETH (subject to 1,000 USD cap) and `withdrawERC20(token, amount)` for tokens.
  - Optionally set per‑token capacity via `setTokenCap(token, newCap)`.

## Notes

- The USD cap applies to ETH withdrawals using the Chainlink ETH/USD price.
- For ERC‑20 tokens, USD caps can be added per token by mapping a price feed per token (optional, not enabled by default).
- Recovery role is powerful; grant `RECOVERY_ROLE` only to trusted operators and monitor emitted events.
