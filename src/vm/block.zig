const block_header = @import("./blockHeader.zig");
const transaction = @import("./transaction.zig");
const withdrawal = @import("./withdrawal.zig");
const receipt = @import("./receipt.zig");

pub const Block = struct {
    header: block_header.BlockHeader,
    transactions: []const transaction.SignedTransaction,
    uncles: []const block_header.BlockHeader,
    withdrawals: []const withdrawal.Withdrawal,
    transaction_builder: transaction.TransactionBuilder,
    receipt_builder: receipt.ReceiptBuilder,
};
