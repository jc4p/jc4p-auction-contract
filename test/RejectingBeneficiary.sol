// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract RejectingBeneficiary {
    bool public shouldReject = false;
    address public owner;

    event Received(uint256 amount);

    constructor() {
        owner = msg.sender;
    }

    function setShouldReject(bool _reject) external {
        require(msg.sender == owner, "Only owner");
        shouldReject = _reject;
    }

    receive() external payable {
        if (shouldReject) {
            revert("Beneficiary configured to reject ETH");
        }
        emit Received(msg.value);
    }
} 