// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import { IMulticall3 } from "forge-std/interfaces/IMulticall3.sol";
import {Enum} from "./Enum.sol";
import { IGnosisSafe } from "./IGnosisSafe.sol";
import {TestMultisigTransaction} from "../src/TestMultisigTransaction.sol";
import { LibSort } from "./LibSort.sol";

contract TestMultiSigWallet  is Script {
    address[]  approvals;
    TestMultisigTransaction sampleCont;
    function setUp() public {}

    function run() public { 
        address MULTICALL3_ADDRESS = 0xcA11bde05977b3631167028862bE2a173976CA11;
        address SAFE_WALLET = 0x6d6b118d600A941D8A8C31e053cB9717986B60a8;

        
        IMulticall3 multicall = IMulticall3(MULTICALL3_ADDRESS);
        
        vm.startBroadcast(vm.envUint("PRIVATE_KEY1"));
        IGnosisSafe safe = IGnosisSafe(payable(SAFE_WALLET));

        // Deploy the contract
        sampleCont = new TestMultisigTransaction(SAFE_WALLET);
        console.log(
            "The contract deployed at: ", address(sampleCont)
        );
        vm.stopBroadcast();

        // Retrieve the nonce of wallet. 
        uint256 nonce = safe.nonce();

        // Build the calldata.
        bytes memory data = buildCalldata();

        // Compute the safe transaction hash
        bytes32 hash = safe.getTransactionHash({
            to: address(sampleCont),
            value: 0,
            data: data,
            operation: Enum.Operation.Call,
            safeTxGas: 0,
            baseGas: 0,
            gasPrice: 0,
            gasToken: address(0),
            refundReceiver: address(0),
            _nonce: nonce
        });

        // Send tx to approve hash from one of owner.
        vm.startBroadcast(vm.envUint("PRIVATE_KEY1"));
        safe.approveHash(hash);
        vm.stopBroadcast();

        // Send tx to approve hash from the other owner.
        vm.startBroadcast(vm.envUint("PRIVATE_KEY2"));
        safe.approveHash(hash);
        
        uint256 threshold = safe.getThreshold();
        console.log("The threshold is", threshold);

        // Get owners
        address[] memory owners = safe.getOwners();

        // Ensure we have enough number of approvals.
        for (uint256 i; i < owners.length; i++) {
            address owner = owners[i];
            uint256 approved = safe.approvedHashes(owner, hash);
            if (approved == 1) {
                approvals.push(owner);
            }
        }

        // Execute transaction if enough approval. 
        if (approvals.length >= threshold) {
            bytes memory signatures = buildSignatures();

            bool success = safe.execTransaction({
                to: address(sampleCont),
                value: 0,
                data: data,
                operation: Enum.Operation.Call,
                safeTxGas: 0,
                baseGas: 0,
                gasPrice: 0,
                gasToken: address(0),
                refundReceiver: payable(address(0)),
                signatures: signatures
            });

            require(success);
            require(sampleCont.getTestVal() == 1);
        
        } else {
            revert ("WUT");
        }

        vm.stopBroadcast();
    }

    function buildCalldata() internal pure returns (bytes memory) { 
        return abi.encodeCall(TestMultisigTransaction.increase, ());
    }

    /**
     * @notice Builds the signatures by tightly packing them together.
     *         Ensures that they are sorted.
     */
    function buildSignatures() internal view returns (bytes memory) {
        address[] memory addrs = new address[](approvals.length);
        for (uint256 i; i < approvals.length; i++) {
            addrs[i] = approvals[i];
        }

        LibSort.sort(addrs);

        bytes memory signatures;
        uint8 v = 1;
        bytes32 s = bytes32(0);
        for (uint256 i; i < addrs.length; i++) {
            bytes32 r = bytes32(uint256(uint160(addrs[i])));
            signatures = bytes.concat(signatures, abi.encodePacked(r, s, v));
        }
        return signatures;
    }
}
