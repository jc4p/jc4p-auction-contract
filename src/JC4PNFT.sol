// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol"; // For on-chain JSON

contract JC4PNFT is ERC721 {
    uint256 public constant TOKEN_ID = 1;
    address public ownerOfToken; // As per spec for the single token owner

    string public constant NFT_NAME_METADATA = "JC4P Collectible";
    string public constant NFT_DESCRIPTION = "A unique 1-of-1 digital collectible for the JC4P auction.";
    string public constant NFT_IMAGE_URL = "https://images.kasra.codes/nft-card/nft.jpg";

    // Auction-related data to be included in metadata later
    // address internal auctionWinner;
    // uint256 internal winningBidAmount;
    // uint64 internal winnerFid;

    // --- Auction Configuration State Variables (from SPEC_SHEET.md) ---
    address public immutable auctionOwner; // Set to msg.sender on deployment
    uint256 public startTime;
    uint256 public endTime;
    uint256 public reservePrice;
    bool public auctionEnded;
    bool public softCloseEnabled;
    uint256 public softCloseWindow;     // seconds
    uint256 public softCloseExtension;  // seconds
    uint256 public minIncrementBps;     // e.g. 1000 = 10%

    // --- Bid State Variables (from SPEC_SHEET.md) ---
    address public firstBidder;
    uint64 public firstBidderFID;
    bool public hasFirstBid;

    address public highestBidder;
    uint64 public highestBidderFID;
    uint256 public highestBid;

    mapping(address => uint256) public bidCount;
    mapping(address => uint64) public bidderFID; // Stores the FID for a given bidder address

    uint256 public totalBids;

    // --- Events (from SPEC_SHEET.md) ---
    event BidPlaced(address indexed bidder, uint256 amount, uint64 fid);
    event AuctionExtended(uint256 newEndTime);
    event AuctionEnded(address indexed winner, uint256 amount); // Added indexed for winner

    // Auction-related data to be included in metadata (actual values set on auction end)
    address internal actualAuctionWinner_ForMetadata;
    uint256 internal winningBidAmount_ForMetadata;
    uint64 internal winnerFid_ForMetadata;

    constructor(
        string memory _name,                // Contract name for ERC721, e.g., "JC4P Auction NFT"
        string memory _symbol,              // Contract symbol for ERC721, e.g., "JC4P"
        uint256 _reservePrice,          // Auction specific
        uint256 _auctionDurationSeconds,  // Auction specific
        uint256 _minIncrementBps,       // Auction specific
        bool _softCloseEnabled,         // Auction specific
        uint256 _softCloseWindow,       // Auction specific
        uint256 _softCloseExtension     // Auction specific
    ) ERC721(_name, _symbol) {
        auctionOwner = msg.sender;
        startTime = block.timestamp;
        endTime = block.timestamp + _auctionDurationSeconds;
        reservePrice = _reservePrice;
        minIncrementBps = _minIncrementBps;
        softCloseEnabled = _softCloseEnabled;
        softCloseWindow = _softCloseWindow;
        softCloseExtension = _softCloseExtension;

        auctionEnded = false; // Explicitly set, though default is false
        // Other bid state variables default to zero/false/null which is correct initially
    }

    function _mintNFT(address to) internal {
        require(to != address(0), "ERC721: mint to the zero address");
        _mint(to, TOKEN_ID);
        ownerOfToken = to;
        
        // Set metadata variables upon minting to the winner
        actualAuctionWinner_ForMetadata = to;
        winningBidAmount_ForMetadata = highestBid; // This is the final winning bid amount
        winnerFid_ForMetadata = highestBidderFID; // This is the FID of the winner
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(tokenId == TOKEN_ID, "JC4PNFT: Only TOKEN_ID 1 exists");

        string memory auctionDataJson = ""; 

        // Example of how auction data could be integrated (needs Strings.toString or similar for uints)
        if (actualAuctionWinner_ForMetadata != address(0)) {
            // This part needs a robust uint to string conversion for production
            // For now, we'll construct a simplified version or leave it to be improved with a library.
            // string memory winnerFidStr = Strings.toString(winnerFid_ForMetadata);
            // string memory winningBidStr = Strings.toString(winningBidAmount_ForMetadata);
            auctionDataJson = string(abi.encodePacked(
                ',\"attributes\": [{\"trait_type\":\"Winner FID\",\"value\":\"', 
                // winnerFidStr, // Placeholder
                "FID_PLACEHOLDER",
                '\"},{\"trait_type\":\"Winning Bid (wei)\",\"value\":\"',
                // winningBidStr, // Placeholder
                "AMOUNT_PLACEHOLDER",
                '\"}]'
            ));
        }

        string memory json = Base64.encode(
            bytes(
                string(
                    abi.encodePacked(
                        '{',
                        '"name": "', NFT_NAME_METADATA, '",',
                        '"description": "', NFT_DESCRIPTION, '",',
                        '"image": "', NFT_IMAGE_URL, '"',
                        auctionDataJson, // Append auction data here
                        '}'
                    )
                )
            )
        );

        return string(abi.encodePacked("data:application/json;base64,", json));
    }

    // --- Functions to be added/modified for auction logic ---
    // constructor with auction params
    // placeBid
    // endAuction
    // withdraw
    // _calculateMinBid
    // _extendAuctionIfNeeded
    // And state variables from the spec sheet for auction

    // --- Helper to check ERC721 compliance for ownerOf ---
    // This ensures our ownerOfToken is consistent if used externally,
    // but ERC721.ownerOf(TOKEN_ID) is the canonical source.
    function getNFTOwner() public view returns (address) {
        return ownerOfToken; // This will be address(0) until _mintNFT is called
    }

    // Override supportsInterface to advertise ERC721
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    // --- Auction Logic Functions (to be implemented based on SPEC_SHEET.md) ---
    function placeBid(uint64 fid) external payable {
        require(!auctionEnded, "AuctionEnded: Auction has already ended");
        require(block.timestamp >= startTime, "AuctionNotStarted: Auction has not started yet");
        // End time check is subtle due to soft close. A bid must be placed *before* the current endTime.
        // The _extendAuctionIfNeeded will push endTime out if applicable.
        require(block.timestamp < endTime, "AuctionEnded: Auction has passed current end time");
        require(msg.value > 0, "BidTooLow: Bid amount must be greater than zero");

        uint256 currentMinBid = _calculateMinBid();
        require(msg.value >= currentMinBid, "BidTooLow: Bid does not meet minimum requirement");

        address oldHighestBidder = highestBidder;
        uint256 oldHighestBidAmount = highestBid;

        // Update bid state (highest bidder and their bid details)
        highestBid = msg.value;
        highestBidder = msg.sender;
        highestBidderFID = fid;

        // Refund previous highest bidder (if any and if different or if same bidder increasing bid)
        if (oldHighestBidder != address(0) && oldHighestBidAmount > 0) {
            // If the current bidder is the same as the old highest bidder, they are increasing their bid.
            // Their previous bid amount (oldHighestBidAmount) must be sent back to them.
            // If it's a new highest bidder, the oldHighestBidder (a different address) gets their oldHighestBidAmount back.
            (bool success, ) = oldHighestBidder.call{value: oldHighestBidAmount}("");
            require(success, "RefundFailed: Failed to refund previous bid");
        }

        // Track first bidder
        if (!hasFirstBid) {
            hasFirstBid = true;
            firstBidder = msg.sender;
            firstBidderFID = fid;
        }

        // Track bid counts
        bidCount[msg.sender]++;
        bidderFID[msg.sender] = fid; // Update/store FID for this bidder address
        totalBids++;

        // Extend auction if applicable (soft close)
        _extendAuctionIfNeeded();

        emit BidPlaced(msg.sender, msg.value, fid);
    }

    function _calculateMinBid() internal view returns (uint256) {
        if (!hasFirstBid) {
            return reservePrice;
        }
        // Calculate increment: highestBid * minIncrementBps / 10000 (100.00%)
        uint256 increment = (highestBid * minIncrementBps) / 10000;
        return highestBid + increment;
    }

    function _extendAuctionIfNeeded() internal {
        if (softCloseEnabled && (endTime - block.timestamp <= softCloseWindow)) {
            endTime = block.timestamp + softCloseExtension;
            emit AuctionExtended(endTime);
        }
    }

    function endAuction() external {
        require(!auctionEnded, "AuctionEnded: Auction already ended");
        require(block.timestamp >= endTime, "AuctionNotOver: Auction has not reached its end time yet");

        auctionEnded = true;

        if (hasFirstBid) { // This implies reserve was met by the first bid, and highestBid >= reservePrice
            // Mint NFT to the highest bidder
            _mintNFT(highestBidder);

            // Transfer funds to auction owner
            if (highestBid > 0) { // Ensure there are funds to send
                (bool success, ) = auctionOwner.call{value: highestBid}("");
                require(success, "PayoutFailed: Failed to transfer funds to auction owner");
            }
            emit AuctionEnded(highestBidder, highestBid);
        } else {
            // No valid bids met reserve, or no bids at all
            emit AuctionEnded(address(0), 0);
        }
    }

    // --- Optional Utility Functions (to be implemented based on SPEC_SHEET.md) ---
    // function getMostActiveBidder() public view returns (address);
    // function getBidderStats(address addr) public view returns (uint256 count, uint64 fid);
    // function getAuctionInfo() public view returns (address highest, uint256 amount, uint256 timeLeft);
} 