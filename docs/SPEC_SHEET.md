🧾 Spec Sheet: Single ERC-721 Contract with Built-in English Auction Logic
🎯 Overview
Contract Role: Acts as both ERC-721 NFT and on-chain English auction house

NFT: 1-of-1 (unique token with metadata baked into the contract)

Auction Type: English auction with:

Scaled minimum bid increments (e.g., 10%)

Soft-close window (optional)

Full bid and ownership logic baked in

🧠 State Variables
solidity
Copy
Edit
// ERC-721 Standard
string public name;
string public symbol;
uint256 public constant TOKEN_ID = 1;
address public ownerOfToken;

// Metadata (baked in)
string public tokenURI;

// Auction config
address public auctionOwner;
uint256 public startTime;
uint256 public endTime;
uint256 public reservePrice;
bool public auctionEnded;
bool public softCloseEnabled;
uint256 public softCloseWindow;     // seconds
uint256 public softCloseExtension; // seconds
uint256 public minIncrementBps;    // e.g. 1000 = 10%

// Bid state
address public firstBidder;
uint64 public firstBidderFID;
bool public hasFirstBid;

address public highestBidder;
uint64 public highestBidderFID;
uint256 public highestBid;

mapping(address => uint256) public bidCount;
mapping(address => uint64) public bidderFID;

uint256 public totalBids;
address public owner;
🔓 External/Public Functions
solidity
Copy
Edit
function constructor(
  string memory _name,
  string memory _symbol,
  string memory _tokenURI,
  uint256 _reservePrice,
  uint256 _auctionDuration,
  uint256 _minIncrementBps,
  bool _softCloseEnabled,
  uint256 _softCloseWindow,
  uint256 _softCloseExtension
) external;

function placeBid(uint64 fid) external payable;

function endAuction() external;

function tokenURI(uint256 tokenId) external view returns (string memory);

function withdraw() external; // optional, if funds are held in contract
🔐 Internal/Private Functions
solidity
Copy
Edit
function _mintNFT(address to) internal;

function _refund(address to, uint256 amount) internal;

function _calculateMinBid() internal view returns (uint256);

function _extendAuctionIfNeeded() internal;
📤 Events
solidity
Copy
Edit
event BidPlaced(address indexed bidder, uint256 amount, uint64 fid);
event AuctionExtended(uint256 newEndTime);
event AuctionEnded(address winner, uint256 amount);
🧾 Logic Description
Minting: NFT is minted directly to the winning bidder when the auction ends

Metadata: tokenURI is hardcoded/stored onchain

Bid Increments: Enforced via minIncrementBps (10% = 1000 BPS)

Soft Close: If enabled, placeBid() extends the auction if within softCloseWindow

First Bid Tracking: Captures address and FID of first bidder

Highest Bid Tracking: Stores highest bid, bidder, and FID

Bid Count Tracking: Counts number of bids per address for optional "most active" frontend logic

🧪 Optional Utility Functions
solidity
Copy
Edit
function getMostActiveBidder() public view returns (address);
function getBidderStats(address addr) public view returns (uint256 count, uint64 fid);
function getAuctionInfo() public view returns (address highest, uint256 amount, uint256 timeLeft);

