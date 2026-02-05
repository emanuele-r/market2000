from web3 import Web3, Account
import os
from solcx import compile_source, install_solc, set_solc_version
from dotenv import load_dotenv

install_solc("0.8.20")
set_solc_version("0.8.20")

load_dotenv("var.env")
ACCOUNT = Account.from_key(os.getenv("BUYER"))
# w3 = Web3(Web3.HTTPProvider("https://ethereum-sepolia-rpc.publicnode.com"))
w3 = Web3(Web3.HTTPProvider("https://sepolia-rollup.arbitrum.io/rpc"))


print("Account:", ACCOUNT.address)
balance = w3.eth.get_balance(ACCOUNT.address)
print("Balance (ETH):", w3.from_wei(balance, "ether"))


compiled_sol = compile_source(
    """// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

contract DonationContract {
    address public owner;

    constructor() {
        owner = msg.sender;
    }

    event DonationReceived(
        address indexed donor,
        uint256 amount,
        string motivation
    );
    event FundsWithdrawn(
        address indexed owner,
        uint256 amount,
        string motivation
    );
    mapping(address => uint256) public donations;
    address[] public donors;

    function donate(uint256 amount, string memory motivation) external payable {
        require(amount > 0, "ZERO_AMOUNT");
        require(bytes(motivation).length > 0, "MOTIVATION_REQUIRED");
        donations[msg.sender] = amount;
        donors.push(msg.sender);
        emit DonationReceived(msg.sender, amount, motivation);
    }

    function withdraw(uint256 amount, string memory motivation) external {
        require(msg.sender == owner, "NOT_OWNER");
        require(bytes(motivation).length > 0, "MOTIVATION_REQUIRED");
        require(amount <= address(this).balance, "INSUFFICIENT_BALANCE");

        (bool success, ) = owner.call{value: amount}("");
        require(success, "WITHDRAWAL_FAILED");
        emit FundsWithdrawn(owner, amount, motivation);
    }

    function getDonors() external view returns (address[] memory) {
        return donors;
    }

    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }
}

""",
    output_values=["abi", "bin"],
)

contract_id, contract_interface = compiled_sol.popitem()
abi = contract_interface["abi"]
bytecode = contract_interface["bin"]

print("ABI generated successfully")

contract = w3.eth.contract(abi=abi, bytecode=bytecode)

deploy_tx = contract.constructor().build_transaction(
    {
        "from": ACCOUNT.address,
        "nonce": w3.eth.get_transaction_count(ACCOUNT.address),
        "gas": w3.eth.estimate_gas(
            {
                "from": ACCOUNT.address,
                "data": contract.bytecode,
            }
        ),
        "gasPrice": w3.to_wei("25", "gwei"),
        "chainId": 421614,  # 11155111 sepolia
    }
)

signed_tx = w3.eth.account.sign_transaction(deploy_tx, ACCOUNT.key)
tx_hash = w3.eth.send_raw_transaction(signed_tx.raw_transaction)

print("Deploying... tx hash:", tx_hash.hex())
receipt = w3.eth.wait_for_transaction_receipt(tx_hash, timeout=300)

print("Contract deployed at:", receipt.contractAddress)
print(f"https://sepolia.etherscan.io/address/{receipt.contractAddress}")

# set_tx = storedData.functions.set(150).build_transaction(
#     {
#         "from": ACCOUNT.address,
#         "nonce": w3.eth.get_transaction_count(ACCOUNT.address),
#         "gas": 100000,
#         "gasPrice": w3.eth.gas_price,
#         "chainId": 11155111,
#     }
# )

# signed_set = w3.eth.account.sign_transaction(set_tx, ACCOUNT.key)
# set_tx_hash = w3.eth.send_raw_transaction(signed_set.raw_transaction)


# print("Stored value:", storedData.functions.get().transact())
