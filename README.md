# JC4P NFT Auction Contract

This project implements a single ERC-721 Non-Fungible Token (NFT) contract with built-in English auction logic for the token. The NFT is a unique 1-of-1 digital collectible.

## Features

This contract provides the following features, based on the initial specification and final implementation:

*   **ERC-721 Compliant NFT**: A single, unique token (Token ID 1) representing the collectible.
*   **Onchain English Auction Logic**: Fully contained within the NFT contract.
    *   **Reserve Price**: Minimum starting bid for the auction.
    *   **Auction Duration**: Configurable time limit for the auction.
    *   **Minimum Bid Increments**: Bids must exceed the previous highest bid by a specified percentage (configurable via Basis Points).
    *   **Soft Close Mechanism (Optional)**: If enabled, bids placed near the end of the auction extend the auction duration, preventing sniping.
    *   **First Bidder Tracking**: Stores the address and Farcaster ID (FID) of the first valid bidder.
    *   **Highest Bidder Tracking**: Continuously tracks the current highest bid, the bidder's address, and their FID.
    *   **Bid Counting**: Tracks the total number of bids and the number of bids per address.
*   **Dynamic Onchain Metadata**: The `tokenURI` function generates metadata JSON onchain, including:
    *   NFT Name (`JC4P Collectible`)
    *   Description
    *   Image URL
    *   Post-auction: Attributes for the winner's FID and the winning bid amount.
*   **Beneficiary Payout**: Upon successful auction completion (i.e., `endAuction` is called and a winner exists), the highest bid amount is transferred to a pre-configured beneficiary address.
*   **Auction Management**: 
    *   `auctionOwner`: The deployer of the contract, who sets initial auction parameters.
    *   `endAuction()`: Callable to finalize the auction after its `endTime` has passed. Mints the NFT to the highest bidder and triggers payout to the beneficiary.
*   **Withdraw Function**: An optional function allowing the designated `beneficiary` to withdraw any Ether held by the contract. This is primarily a fallback if the automatic payout in `endAuction` were to fail and leave funds in the contract (though `endAuction` is designed to revert if payout fails, making this withdraw function more relevant for accidentally sent funds or future extensibility).
*   **Utility Functions**:
    *   `getAuctionInfo()`: Returns current highest bidder, highest bid, and time left.
    *   `getBidderStats()`: Returns bid count and FID for a given address.

## Project Structure

```
.
├── docs/
│   └── SPEC_SHEET.md         # Original specification sheet for the project
├── script/                 # Deployment scripts
│   └── DeployJC4PNFT.s.sol
├── src/                    # Solidity source files
│   └── JC4PNFT.sol
├── test/                   # Test files
│   ├── JC4PNFT.t.sol
│   └── RejectingBeneficiary.sol # Helper for testing
├── lib/                    # Dependencies (installed via forge)
├── foundry.toml            # Foundry configuration
├── README.md               # This file
└── ...                     # Other project files (e.g., .gitignore)
```

## Prerequisites

*   [Foundry](https://getfoundry.sh/) installed.

## Setup

1.  **Clone the repository (if you haven't already):**
    ```bash
    # git clone <your-repo-url>
    # cd <your-repo-directory>
    ```

2.  **Install dependencies:**
    Foundry handles dependencies. If `lib/` is empty or you need to update, run:
    ```bash
    forge install
    ```
    This will typically install `@openzeppelin/contracts` and `solady` based on remappings if specified or from `foundry.toml` if configured. If you have specific versions pinned in `foundry.toml` or `remappings.txt`, they will be used.

## Testing

Run the test suite:

```bash
forge test
```

For more verbose output:

```bash
forge test -vvv
```

## Deployment

The contract `JC4PNFT.sol` takes several parameters in its constructor. You'll need to provide these when deploying.

**Constructor Parameters:**

1.  `string memory _name`: Name for the ERC721 token (e.g., "My Collectible Auction").
2.  `string memory _symbol`: Symbol for the ERC721 token (e.g., "MCA").
3.  `address _beneficiary`: The address that will receive the auction proceeds.
4.  `uint256 _reservePrice`: The minimum price to start the bidding (in wei).
5.  `uint256 _auctionDurationSeconds`: The duration of the auction in seconds (e.g., `7 days` which is `7 * 24 * 60 * 60`).
6.  `uint256 _minIncrementBps`: Minimum bid increment in Basis Points (BPS). 100 BPS = 1%. So, 10% is 1000 BPS.
7.  `bool _softCloseEnabled`: `true` to enable soft close, `false` otherwise.
8.  `uint256 _softCloseWindow`: If soft close is enabled, the window (in seconds) before `endTime` where a bid extends the auction (e.g., `15 minutes`).
9.  `uint256 _softCloseExtension`: If soft close is enabled, the duration (in seconds) by which the auction is extended (e.g., `5 minutes`).

**Using the Deployment Script (`script/DeployJC4PNFT.s.sol`)**

The provided script `script/DeployJC4PNFT.s.sol` allows you to deploy the contract. You will need to:

1.  **Set Environment Variables:** The script expects your private key and an RPC URL for the target network (e.g., Sepolia, or a local Anvil instance).
    ```bash
    export PRIVATE_KEY=<YOUR_PRIVATE_KEY>
    export RPC_URL=<YOUR_RPC_URL> 
    # For local Anvil: export RPC_URL=http://localhost:8545 
    # (ensure Anvil is running with an account funded from your PRIVATE_KEY or use one of its default keys)
    ```
    **IMPORTANT**: Never commit your private key to version control.

2.  **Modify Script Parameters (Optional but Recommended):**
    Open `script/DeployJC4PNFT.s.sol` and adjust the default constructor arguments within the `run()` function to your desired values for the specific auction.

3.  **Execute the Deployment Script:**

    *   **To a local Anvil node:**
        Start Anvil in a separate terminal: `anvil`
        Then run:
        ```bash
        forge script script/DeployJC4PNFT.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast
        ```
        If Anvil provides default private keys, you can use one of those directly if `PRIVATE_KEY` is not set, or use Foundry's keystore/ledger options.

    *   **To a testnet (e.g., Sepolia):**
        Ensure `RPC_URL` points to your Sepolia RPC endpoint (e.g., from Infura, Alchemy).
        Ensure your account (derived from `PRIVATE_KEY`) has Sepolia ETH for gas.
        ```bash
        forge script script/DeployJC4PNFT.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast --etherscan-api-key <YOUR_ETHERSCAN_API_KEY> --verify
        ```
        Replace `<YOUR_ETHERSCAN_API_KEY>` if you want to verify the contract on Etherscan.

**Deploying Multiple Instances / Different Parameters:**

*   **Specific Minimum Price (`_reservePrice`):**
    To deploy with a specific minimum price, modify the `_reservePrice` argument in `script/DeployJC4PNFT.s.sol` before running the script. For example, for 0.5 ETH:
    `uint256 reservePrice = 0.5 ether;`

*   **Another Auction (Different NFT Name/Symbol, etc.):**
    To deploy another, distinct auction contract:
    1.  Modify all relevant parameters in `script/DeployJC4PNFT.s.sol` (e.g., `_name`, `_symbol`, `_beneficiary`, `_reservePrice`, durations, etc.).
    2.  Run the deployment script again. Each run will deploy a new, independent instance of the `JC4PNFT` contract. Keep track of the deployed contract addresses.

*   **Different Minimum Raise (Minimum Bid Increment - `_minIncrementBps`):**
    To change the minimum percentage a new bid must be higher than the current highest bid:
    1.  Modify the `_minIncrementBps` parameter in `script/DeployJC4PNFT.s.sol`. For example, for a 5% minimum increment:
        `uint256 minIncrementBps = 500; // 500 BPS = 5%`
    2.  Run the deployment script.

**Example: Deploying for a 1 ETH Reserve Price**

In `script/DeployJC4PNFT.s.sol`, you would set:
`uint256 reservePrice = 1 ether;`
And then run the `forge script ...` command.

## Interacting with the Contract

Once deployed, you can interact with the contract using tools like `cast` (part of Foundry), Etherscan (if verified), or web3 libraries in a frontend application.

Key functions:
*   `placeBid(uint64 fid) payable`
*   `endAuction()`
*   `withdraw()` (by beneficiary if needed)
*   `tokenURI(uint256 tokenId)` (to get metadata)
*   View functions like `getAuctionInfo()`, `getBidderStats(address addr)`, etc.

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.