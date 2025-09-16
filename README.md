# KipuBank Smart Contract

This repository contains the KipuBank smart contract, a project for the Web3Dev course exam. It's a simple, secure, and well-documented contract for managing ETH deposits and withdrawals.

## Description

KipuBank allows users to deposit ETH into a personal, on-chain vault. To ensure security and controlled usage, the contract enforces two key constraints:

1.  **Global Bank Cap**: A maximum total amount of ETH that the entire contract can hold. This value is set at deployment and can be updated later by the contract owner.
2.  **Withdrawal Limit**: A fixed limit on the amount of ETH that can be withdrawn in a single transaction, also set at deployment.

The contract is designed with security best practices in mind, including the checks-effects-interactions pattern, custom errors for clear feedback, and comprehensive NatSpec documentation.

## Getting Started

### Prerequisites

-   Remix

### Installation & Setup

1.  **Clone the repository:**
    1.1. Open Remix https://remix.ethereum.org
    1.2. Go to "Git" tab.
    1.3. Fill the inputs in the "Clone" section
      Clone from url: https://github.com/RafaelDamasco/kipu-bank
      branch: main

## Deployment

To deploy the `KipuBank` contract, follow these steps.

1.  **Compile:**
    1.1 Go to "Solidity Compiler"
    1.2 Compile the file KipuBank.sol

2.  **Deploy:**
    2.1 Fill the inputs:
      _bankCap: 10000000 (The maximum amount of ETH that the entire bank can hold. Can be updated by the owner.)
      _withdrawalLimit: 1000 (The maximum amount of ETH that can be deposited in a single withdrawal transaction.)
    2.2 Click to deploy/transact
    2.3 On top of the contract, fill the value
      value: 10 (Whitch will be the amount to be sent with transaction)
      Click on "Deposit" to get stated!

## Interacting with the Contract

### `deposit()`

Deposit an amount of ETH into your vault.

### `setBankCap(uint256 newCap)`

Allows the owner to update the bank's capacity.

### `withdraw(uint256 amount)`

Withdraw an amount of ETH from your vault. The amount must be less than or equal to the `withdrawalLimit`.

### `bankCap()`

The maximum amount of ETH that the entire bank can hold. Can be updated by the owner.

### `depositCount()`

The total number of deposit transactions made to the bank.

### `getVaultBalance()`

Check the balance of your personal vault.

The result will be your balance in wei.

### `owner()`

The address of the contract owner, who can update the bank capacity.

### `totalBankBalance()`

Check the total ETH held by the bank.

### `withdrawalCount()`

The total number of withdrawal transactions made from the bank.

### `withdrawalLimit()`

The maximum amount of ETH that the entire bank can hold. Can be updated by the owner.
