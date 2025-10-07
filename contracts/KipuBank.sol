// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title KipuBank
 * @author Rafael Euclides Damasco
 * @notice A smart contract that allows users to deposit and withdraw ETH into a personal vault.
 */

import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV2V3Interface.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract KipuBank is AccessControl {

    using SafeERC20 for IERC20;

    bytes32 public constant RECOVERY_ROLE = keccak256("RECOVERY_ROLE"); // + V2 Update

    AggregatorV3Interface public ethUsdFeed; // + V2 Update

    uint256 public constant MAX_WITHDRAW_USD_8 = 1_000 * 1e8; // + V2 Update

    uint256 public constant MAX_PRICE_AGE = 1 hours; // + V2 Update

    address public owner;

  
    uint256 public immutable withdrawalLimit;

   
    uint256 public bankCap;

    
    mapping(address => uint256) private vaults;

    
    uint256 public totalBankBalance;

   
    uint256 public depositCount;

    uint256 public withdrawalCount;

    mapping(address => mapping(address => uint256)) private erc20Vaults; // + V2 Update

    mapping(address => uint256) public totalTokenBalance; // + V2 Update

    mapping(address => uint256) public tokenCap; // + V2 Update

    event PriceFeedUpdated(address indexed newFeed, address indexed operator); // + V2 Update

    event ERC20Deposit(address indexed token, address indexed user, uint256 amount); // + V2 Update

    event ERC20Withdrawal(address indexed token, address indexed user, uint256 amount); // + V2 Update

    event TokenCapUpdated(address indexed token, uint256 newCap); // + V2 Update

    event Deposit(address indexed user, uint256 amount);

    event Withdrawal(address indexed user, uint256 amount);

    event BankCapUpdated(uint256 newCap);

    event VaultReassigned(address indexed fromUser, address indexed toUser, uint256 amount, address indexed operator); // + V2 Update

    event ExcessAssigned(address indexed user, uint256 amount, address indexed operator); // + V2 Update

    event AdminTopUp(address indexed user, uint256 amount, address indexed operator); // + V2 Update

    event AdminWithdrawFromUser(address indexed fromUser, address indexed to, uint256 amount, address indexed operator); // + V2 Update

    error NotOwner();

    error AmountMustBeGreaterThanZero();

    error BankCapExceeded(uint256 availableSpace, uint256 amount);

    error WithdrawalLimitExceeded(uint256 requested, uint256 limit);

    error InsufficientBalance(uint256 available, uint256 requested);

    error TransferFailed();

    error InvalidAddress(); // + V2 Update

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
     * @notice + V2 Update - Set the contract owner as admin and add a role to recover founds
     * @notice Initializes the KipuBank contract with a bank capacity and a withdrawal limit.
     * @param _bankCap The maximum total ETH the bank can hold.
     * @param _withdrawalLimit The maximum ETH per withdrawal transaction.
     */
    constructor(uint256 _bankCap, uint256 _withdrawalLimit, address _ethUsdFeed) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(RECOVERY_ROLE, msg.sender);

        owner = msg.sender;
        bankCap = _bankCap;
        withdrawalLimit = _withdrawalLimit;
        ethUsdFeed = AggregatorV3Interface(_ethUsdFeed);
    }

    /**
     * @notice + V2 Update
     * @notice Reassigns vault balance from one user to another without changing the bank total.
     * @dev Useful to correct wrongly credited balances. Keeps totalBankBalance unchanged.
     */
    function adminReassignVault(address fromUser, address toUser, uint256 amount)
        external
        onlyRole(RECOVERY_ROLE)
        nonZeroAmount(amount)
    {
        if (fromUser == address(0) || toUser == address(0)) revert InvalidAddress();
        uint256 fromBal = vaults[fromUser];
        if (amount > fromBal) revert InsufficientBalance(fromBal, amount);

        vaults[fromUser] = fromBal - amount;
        vaults[toUser] += amount;

        emit VaultReassigned(fromUser, toUser, amount, msg.sender);
    }

    /**
     * @notice + V2 Update
     * @notice Assigns to a user part of the ETH that entered the contract through external means (e.g., force-send).
     * @dev Requires available excess ETH: address(this).balance >= totalBankBalance + amount.
     */
    function adminAssignExcessToUser(address user, uint256 amount)
        external
        onlyRole(RECOVERY_ROLE)
        nonZeroAmount(amount)
    {
        if (user == address(0)) revert InvalidAddress();

        uint256 contractBal = address(this).balance;
        if (contractBal < totalBankBalance + amount) {
            revert BankCapExceeded(contractBal - totalBankBalance, amount);
        }

        uint256 newTotal = totalBankBalance + amount;
        if (newTotal > bankCap) revert BankCapExceeded(bankCap - totalBankBalance, amount);

        vaults[user] += amount;
        totalBankBalance = newTotal;

        emit ExcessAssigned(user, amount, msg.sender);
    }

    /**
     * @notice + V2 Update
     * @notice Admin tops up a user's vault by sending ETH along with the call.
     * @dev Preserves accounting consistency: msg.value is added to the user's vault and to totalBankBalance.
     */
    function adminTopUpUser(address user)
        external
        payable
        onlyRole(RECOVERY_ROLE)
        nonZeroAmount(msg.value)
    {
        if (user == address(0)) revert InvalidAddress();

        uint256 newTotal = totalBankBalance + msg.value;
        if (newTotal > bankCap) revert BankCapExceeded(bankCap - totalBankBalance, msg.value);

        vaults[user] += msg.value;
        totalBankBalance = newTotal;

        emit AdminTopUp(user, msg.value, msg.sender);
    }

    /**
     * @notice + V2 Update
     * @notice Admin withdraws from a user's vault and sends the ETH to a recipient.
     * @dev Use with extreme caution. Keeps consistency by reducing totalBankBalance and transferring ETH.
     */
    function adminWithdrawFromUser(address fromUser, address payable to, uint256 amount)
        external
        onlyRole(RECOVERY_ROLE)
        nonZeroAmount(amount)
    {
        if (fromUser == address(0) || to == address(0)) revert InvalidAddress();

        uint256 fromBal = vaults[fromUser];
        if (amount > fromBal) revert InsufficientBalance(fromBal, amount);

        vaults[fromUser] = fromBal - amount;
        totalBankBalance -= amount;

        _safeTransfer(to, amount);
        emit AdminWithdrawFromUser(fromUser, to, amount, msg.sender);
    }

    /**
     * @notice + V2 Update
     * @notice Returns the ETH/USD price with 8 decimal places (e.g., 2_500.12345678 => 250012345678).
     * @dev Performs basic checks: price > 0, not stale.
     */
    function getEthUsdPrice8() public view returns (uint256 price8) {
        (
            uint80 roundId,
            int256 answer,
            , // startedAt
            uint256 updatedAt,
            uint80 answeredInRound
        ) = ethUsdFeed.latestRoundData();

        require(answeredInRound >= roundId, "stale round");
        require(updatedAt != 0 && block.timestamp - updatedAt <= MAX_PRICE_AGE, "stale price");
        require(answer > 0, "invalid price");

        uint8 decimals = ethUsdFeed.decimals();
        // Normalize to 8 decimal places
        if (decimals == 8) {
            return uint256(answer);
        } else if (decimals > 8) {
            return uint256(answer) / (10 ** (decimals - 8));
        } else {
            return uint256(answer) * (10 ** (8 - decimals));
        }
    }

    /**
     * @notice + V2 Update
     * @notice Converts a value in wei to USD with 8 decimal places, using the price feed.
     */
    function quoteWeiInUsd8(uint256 amountWei) public view returns (uint256 usdAmount8) {
        uint256 price8 = getEthUsdPrice8(); // 8 decimals
        // usd(8) = amountWei * price(8) / 1e18
        return (amountWei * price8) / 1e18;
    }

    /**
     * @notice + V2 Update
     * @notice Sets/updates the cap for an ERC-20 token (0 = no limit).
     */
    function setTokenCap(address token, uint256 newCap) external onlyOwner {
        tokenCap[token] = newCap;
        emit TokenCapUpdated(token, newCap);
    }

    /**
     * @notice + V2 Update
     * @notice Deposits an ERC-20 token into the caller's vault.
     * @dev Supports fee-on-transfer tokens: credits the actual amount received.
     */
    function depositERC20(address token, uint256 amount)
        external
        nonZeroAmount(amount)
    {
        IERC20 t = IERC20(token);
        uint256 beforeBal = t.balanceOf(address(this));
        t.safeTransferFrom(msg.sender, address(this), amount);
        uint256 afterBal = t.balanceOf(address(this));
        uint256 received = afterBal - beforeBal;
        if (received == 0) revert AmountMustBeGreaterThanZero();

        uint256 cap = tokenCap[token];
        if (cap > 0) {
            uint256 newTotal = totalTokenBalance[token] + received;
            if (newTotal > cap) {
                revert BankCapExceeded(cap - totalTokenBalance[token], received);
            }
            totalTokenBalance[token] = newTotal;
        } else {
            totalTokenBalance[token] += received;
        }

        erc20Vaults[token][msg.sender] += received;
        emit ERC20Deposit(token, msg.sender, received);
    }

    /**
     * @notice + V2 Update
     * @notice Withdraws an ERC-20 token from the caller's vault.
     * @dev For fee-on-transfer tokens, the user may receive less than 'amount' due to the token's fee.
     */
    function withdrawERC20(address token, uint256 amount)
        external
        nonZeroAmount(amount)
    {
        uint256 bal = erc20Vaults[token][msg.sender];
        if (amount > bal) revert InsufficientBalance(bal, amount);

        erc20Vaults[token][msg.sender] = bal - amount;
        totalTokenBalance[token] -= amount;

        IERC20(token).safeTransfer(msg.sender, amount);
        emit ERC20Withdrawal(token, msg.sender, amount);
    }

    /**
     * @notice + V2 Update
     * @notice Returns the vault balance for an ERC-20 token.
     */
    function getVaultBalanceERC20(address token) external view returns (uint256) {
        return erc20Vaults[token][msg.sender];
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

        // + V2 Update - USD limit (8 decimal scale): 1000 USD
        uint256 usdValue8 = quoteWeiInUsd8(_amount);
        require(usdValue8 <= MAX_WITHDRAW_USD_8, "withdraw > 1000 USD");

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