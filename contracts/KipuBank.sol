// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title KipuBank
 * @author Rafael Euclides Damasco
 * @notice A smart contract that allows users to deposit and withdraw ETH into a personal vault.
 */
contract KipuBank {
    // ==================================================================
    // State Variables
    // ==================================================================

    /**
     * @notice The address of the contract owner, who can update the bank capacity.
     */
    address public owner;

    /**
     * @notice The maximum amount of ETH that can be deposited in a single withdrawal transaction.
     */
    uint256 public immutable withdrawalLimit;

    /**
     * @notice The maximum amount of ETH that the entire bank can hold. Can be updated by the owner.
     */
    uint256 public bankCap;

    /**
     * @notice A mapping from user addresses to their vault balances in wei.
     */
    mapping(address => uint256) private vaults;

    /**
     * @notice The total amount of ETH currently held by the bank.
     */
    uint256 public totalBankBalance;

    /**
     * @notice The total number of deposit transactions made to the bank.
     */
    uint256 public depositCount;

    /**
     * @notice The total number of withdrawal transactions made from the bank.
     */
    uint256 public withdrawalCount;

    /**
     * @notice Emitted when a user successfully deposits ETH.
     * @param user The address of the user who deposited.
     * @param amount The amount of ETH deposited in wei.
     */
    event Deposit(address indexed user, uint256 amount);

    /**
     * @notice Emitted when a user successfully withdraws ETH.
     * @param user The address of the user who withdrew.
     * @param amount The amount of ETH withdrawn in wei.
     */
    event Withdrawal(address indexed user, uint256 amount);

    /**
     * @notice Emitted when the bank capacity is updated.
     * @param newCap The new bank capacity in wei.
     */
    event BankCapUpdated(uint256 newCap);

    /**
     * @notice Reverts if a function is called by an address other than the owner.
     */
    error NotOwner();

    /**
     * @notice Reverts if a user tries to deposit or withdraw zero ETH.
     */
    error AmountMustBeGreaterThanZero();

    /**
     * @notice Reverts if a deposit would cause the bank's total balance to exceed its capacity.
     * @param availableSpace The remaining ETH capacity of the bank.
     * @param amount The amount the user tried to deposit.
     */
    error BankCapExceeded(uint256 availableSpace, uint256 amount);

    /**
     * @notice Reverts if a user tries to withdraw an amount greater than the fixed withdrawal limit.
     * @param requested The amount the user tried to withdraw.
     * @param limit The maximum allowed withdrawal amount.
     */
    error WithdrawalLimitExceeded(uint256 requested, uint256 limit);

    /**
     * @notice Reverts if a user tries to withdraw more ETH than they have in their vault.
     * @param available The user's current vault balance.
     * @param requested The amount the user tried to withdraw.
     */
    error InsufficientBalance(uint256 available, uint256 requested);

    /**
     * @notice Reverts if the ETH transfer fails during a withdrawal.
     */
    error TransferFailed();

    /**
     * @notice Modifier to check if the caller is the contract owner.
     */
    modifier onlyOwner() {
        if (msg.sender != owner) {
            revert NotOwner();
        }
        _;
    }

    /**
     * @notice Modifier to check if an amount is greater than zero.
     * @param _amount The amount to check.
     */
    modifier nonZeroAmount(uint256 _amount) {
        if (_amount == 0) {
            revert AmountMustBeGreaterThanZero();
        }
        _;
    }

    /**
     * @notice Initializes the KipuBank contract with a bank capacity and a withdrawal limit.
     * @param _bankCap The maximum total ETH the bank can hold.
     * @param _withdrawalLimit The maximum ETH per withdrawal transaction.
     */
    constructor(uint256 _bankCap, uint256 _withdrawalLimit) {
        owner = msg.sender;
        bankCap = _bankCap;
        withdrawalLimit = _withdrawalLimit;
    }

    /**
     * @notice Allows the owner to update the bank's capacity.
     * @param _newCap The new capacity for the bank.
     */
    function setBankCap(uint256 _newCap) external onlyOwner {
        bankCap = _newCap;
        emit BankCapUpdated(_newCap);
    }

    /**
     * @notice Allows a user to deposit ETH into their personal vault.
     * The amount is determined by the value sent with the transaction (`msg.value`).
     * The transaction will revert if the deposit amount is zero or if it exceeds the bank's capacity.
     */
    function deposit() external payable nonZeroAmount(msg.value) {
        uint256 newTotalBalance = totalBankBalance + msg.value;
        if (newTotalBalance > bankCap) {
            revert BankCapExceeded(bankCap - totalBankBalance, msg.value);
        }

        vaults[msg.sender] += msg.value;
        totalBankBalance = newTotalBalance;
        depositCount++;

        emit Deposit(msg.sender, msg.value);
    }

    /**
     * @notice Allows a user to withdraw a specified amount of ETH from their vault.
     * @param _amount The amount of ETH to withdraw.
     * The transaction will revert if the amount is zero, exceeds the user's balance,
     * or is greater than the single transaction withdrawal limit.
     */
    function withdraw(uint256 _amount) external nonZeroAmount(_amount) {
        if (_amount > withdrawalLimit) {
            revert WithdrawalLimitExceeded(_amount, withdrawalLimit);
        }
        uint256 userBalance = vaults[msg.sender];
        if (_amount > userBalance) {
            revert InsufficientBalance(userBalance, _amount);
        }

        vaults[msg.sender] -= _amount;
        totalBankBalance -= _amount;
        withdrawalCount++;

        _safeTransfer(msg.sender, _amount);
        emit Withdrawal(msg.sender, _amount);
    }

    /**
     * @notice Retrieves the ETH balance of the caller's personal vault.
     * @return The amount of ETH in wei.
     */
    function getVaultBalance() external view returns (uint256) {
        return vaults[msg.sender];
    }

    /**
     * @notice Internal function to safely transfer ETH to a specified address.
     * @dev Reverts with a custom error if the transfer fails.
     * @param _to The recipient address.
     * @param _amount The amount of ETH to send.
     */
    function _safeTransfer(address _to, uint256 _amount) private {
        (bool success, ) = _to.call{value: _amount}("");
        if (!success) {
            revert TransferFailed();
        }
    }
}