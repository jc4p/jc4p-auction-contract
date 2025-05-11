// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {JC4PNFT} from "../src/JC4PNFT.sol";

contract DeployJC4PNFT is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        // --- Customizable Auction Parameters ---
        string memory nftName = "[TEST] JC4P Trading Card";
        string memory nftSymbol = "TESTJC4P";
        // address beneficiary = vm.envAddress("BENEFICIARY_ADDRESS"); // Example: Get from env or hardcode
        address beneficiary = 0x0db12C0A67bc5B8942ea3126a465d7a0b23126C7; // Or hardcode directly
        uint256 reservePrice = 0.1 ether;                 // e.g., 0.1 ETH
        uint256 auctionDurationSeconds = 3 * 24 * 60 * 60;  // 3 days
        uint256 minIncrementBps = 1000;                   // 1000 BPS = 10%
        bool softCloseEnabled = true;
        uint256 softCloseWindow = 15 * 60;                // 15 minutes
        uint256 softCloseExtension = 5 * 60;              // 5 minutes
        // --- End Customizable Auction Parameters ---

        if (beneficiary == address(0)) {
            console.log("ERROR: BENEFICIARY_ADDRESS environment variable not set or invalid.");
            console.log("Please set it or hardcode a beneficiary address in the script.");
            revert("Beneficiary address is required.");
        }
        if (deployerPrivateKey == 0) {
            console.log("ERROR: PRIVATE_KEY environment variable not set or invalid.");
            console.log("Please set it for deployment.");
            revert("Private key is required for deployment.");
        }

        vm.startBroadcast(deployerPrivateKey);

        JC4PNFT jc4pNft = new JC4PNFT(
            nftName,
            nftSymbol,
            beneficiary,
            reservePrice,
            auctionDurationSeconds,
            minIncrementBps,
            softCloseEnabled,
            softCloseWindow,
            softCloseExtension
        );

        vm.stopBroadcast();

        console.log("JC4PNFT Contract Deployed!");
        console.log("  Name: %s", nftName);
        console.log("  Symbol: %s", nftSymbol);
        console.log("  Beneficiary: %s", address(beneficiary));
        console.log("  Reserve Price: %s wei (%s ether)", reservePrice, vm.toString(reservePrice / 1e18));
        console.log("  Auction Duration: %s seconds", auctionDurationSeconds);
        console.log("  Min Increment BPS: %s (%s%)", minIncrementBps, vm.toString(minIncrementBps/100));
        console.log("  Soft Close Enabled: %s", softCloseEnabled);
        console.log("  Soft Close Window: %s seconds", softCloseWindow);
        console.log("  Soft Close Extension: %s seconds", softCloseExtension);
        console.log("  Deployed to: %s", address(jc4pNft));
        console.log("  Deployer (Auction Owner): %s", vm.addr(deployerPrivateKey));
    }
} 