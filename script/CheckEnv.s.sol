// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";

contract CheckEnv is Script {
    function run() external {
        console.log("--- Checking Environment Variables & RPC Connection ---");

        // 1. Read and process PRIVATE_KEY
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        if (privateKey == 0) {
            console.log("ERROR: PRIVATE_KEY environment variable not set, is zero, or not a valid hex number.");
            console.log("Please set it to your private key as a hexadecimal string (e.g., export PRIVATE_KEY=0xyourkey or export PRIVATE_KEY=yourkey).");
            revert("PRIVATE_KEY is required and must be a valid hex number.");
        }
        console.log("Successfully read PRIVATE_KEY from environment.");

        address derivedAddress = vm.addr(privateKey);
        console.log("Derived address from PRIVATE_KEY: %s", derivedAddress);

        // 2. Check RPC_URL (implicitly by using RPC-dependent cheatcodes)
        // The actual RPC URL used is the one provided via --rpc-url to `forge script`
        // or the default from foundry.toml if --rpc-url is omitted.
        // We will try to fetch some chain data. If this succeeds, the RPC is working.

        console.log("Attempting to fetch data from the RPC endpoint specified by --rpc-url...");

        uint256 chainId = block.chainid;
        console.log("Chain ID from RPC: %s", chainId);

        uint256 balance = derivedAddress.balance;
        console.log("Balance of derived address (%s) on this chain: %s wei", derivedAddress, balance);
        console.log("                                         (%s ether)", vm.toString(balance / 1e18));
        
        uint256 currentBlockNumber = block.number;
        console.log("Current block number from RPC: %s", currentBlockNumber);

        if (chainId == 0 && currentBlockNumber == 0 && balance == 0) {
             console.log("WARNING: Chain ID, Block Number, and Balance are all zero. This might indicate an issue with the RPC connection or an uninitialized chain (like a fresh local Anvil with no activity), or the derived address might be new and have no balance. Please verify the RPC URL and network status.");
        } else {
            console.log("Successfully fetched data from RPC.");
        }

        console.log("--- Environment & RPC Check Complete ---");
        console.log("To use this script, run: forge script script/CheckEnv.s.sol --rpc-url <YOUR_RPC_URL> -vv");
        console.log("Ensure PRIVATE_KEY is set in your environment.");
    }
} 