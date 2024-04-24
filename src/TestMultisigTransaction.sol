// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract TestMultisigTransaction {
    address public owner;
    uint public test_val = 0;

    // Owner will be initialized to safe wallet (2 of 2 gnosis wallet).
    constructor (address _owner) {
        owner = _owner;
    }

    // Increment the value if the caller is multisig.
    function increase() external {
        if (msg.sender == owner) {
            test_val += 1;
        }
    }

    // Helper function to retrieve the test_val value.
    function getTestVal() external view returns (uint) {
        return test_val;
    }
}
