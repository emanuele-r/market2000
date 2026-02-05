// SPDX-License-Identifier: GPL-3.0
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
