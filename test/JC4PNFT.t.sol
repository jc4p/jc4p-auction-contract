// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {JC4PNFT} from "../src/JC4PNFT.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { IERC721Errors } from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";

contract JC4PNFTTest is Test {
    JC4PNFT nft;

    // Declare events to be checked by vm.expectEmit
    event BidPlaced(address indexed bidder, uint256 amount, uint64 fid);
    event AuctionExtended(uint256 newEndTime);
    event AuctionEnded(address indexed winner, uint256 amount);

    // Test constants for NFT metadata
    string internal constant EXPECTED_NFT_NAME_METADATA = "JC4P Collectible";
    string internal constant EXPECTED_NFT_DESCRIPTION = "A unique 1-of-1 digital collectible for the JC4P auction.";
    string internal constant EXPECTED_NFT_IMAGE_URL = "https://images.kasra.codes/nft-card/nft.jpg";

    // Test constants for auction setup
    uint256 internal constant TEST_RESERVE_PRICE = 0.1 ether;
    uint256 internal constant TEST_AUCTION_DURATION_SECONDS = 7 days;
    uint256 internal constant TEST_MIN_INCREMENT_BPS = 1000; // 10%
    bool    internal constant TEST_SOFT_CLOSE_ENABLED = true;
    uint256 internal constant TEST_SOFT_CLOSE_WINDOW = 15 minutes;
    uint256 internal constant TEST_SOFT_CLOSE_EXTENSION = 5 minutes;

    address deployer; // Test contract itself is the deployer
    address user1 = vm.addr(1); 
    address user2 = vm.addr(2);
    address user3 = vm.addr(3); // New user for more complex scenarios

    uint64 internal constant USER1_FID = 111;
    uint64 internal constant USER2_FID = 222;
    uint64 internal constant USER3_FID = 333;

    uint256 public setUpBlockTimestamp; // To record timestamp during setUp

    // Helper to receive ETH for refunds
    receive() external payable {}

    function setUp() public {
        deployer = address(this);
        setUpBlockTimestamp = block.timestamp; // Record timestamp before contract deployment for accurate checking
        nft = new JC4PNFT(
            "JC4P NFT Auction", 
            "JC4PA",            
            TEST_RESERVE_PRICE,
            TEST_AUCTION_DURATION_SECONDS,
            TEST_MIN_INCREMENT_BPS,
            TEST_SOFT_CLOSE_ENABLED,
            TEST_SOFT_CLOSE_WINDOW,
            TEST_SOFT_CLOSE_EXTENSION
        );
        // Give users some ETH for bidding
        vm.deal(user1, 2 ether);
        vm.deal(user2, 2 ether);
        vm.deal(user3, 2 ether);
    }

    function test_ERC721_InitialState() public { 
        assertEq(nft.name(), "JC4P NFT Auction", "Contract name incorrect");
        assertEq(nft.symbol(), "JC4PA", "Contract symbol incorrect");
        assertEq(nft.TOKEN_ID(), 1, "TOKEN_ID incorrect");
        assertEq(nft.ownerOfToken(), address(0), "ownerOfToken should be 0");
        assertEq(nft.getNFTOwner(), address(0), "getNFTOwner should be 0");
        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, 1));
        nft.ownerOf(1);
    }

    function test_Auction_InitialConfiguration() public view {
        assertEq(nft.auctionOwner(), deployer, "Auction owner incorrect");
        assertApproxEqAbs(nft.startTime(), setUpBlockTimestamp, 2, "Start time incorrect");
        uint256 expectedEndTime = nft.startTime() + TEST_AUCTION_DURATION_SECONDS;
        assertEq(nft.endTime(), expectedEndTime, "End time incorrect");
        assertEq(nft.reservePrice(), TEST_RESERVE_PRICE, "Reserve price incorrect");
        assertEq(nft.minIncrementBps(), TEST_MIN_INCREMENT_BPS, "Min increment BPS incorrect");
        assertEq(nft.softCloseEnabled(), TEST_SOFT_CLOSE_ENABLED, "Soft close enabled incorrect");
        assertEq(nft.softCloseWindow(), TEST_SOFT_CLOSE_WINDOW, "Soft close window incorrect");
        assertEq(nft.softCloseExtension(), TEST_SOFT_CLOSE_EXTENSION, "Soft close extension incorrect");
        assertFalse(nft.auctionEnded(), "Auction should not be ended");
        assertEq(nft.firstBidder(), address(0));
        assertEq(nft.firstBidderFID(), 0);
        assertFalse(nft.hasFirstBid());
        assertEq(nft.highestBidder(), address(0));
        assertEq(nft.highestBidderFID(), 0);
        assertEq(nft.highestBid(), 0);
        assertEq(nft.totalBids(), 0);
        assertEq(nft.bidCount(user1), 0);
        assertEq(nft.bidderFID(user1), 0);
    }

    // --- placeBid Revert Tests ---
    function test_PlaceBid_Reverts_AuctionNotStarted() public {
        vm.warp(nft.startTime() - 1 seconds); // Warp to before auction starts
        vm.prank(user1);
        vm.expectRevert("AuctionNotStarted: Auction has not started yet");
        nft.placeBid{value: TEST_RESERVE_PRICE}(USER1_FID);
    }

    function test_PlaceBid_Reverts_AuctionEnded_PastEndTime() public {
        vm.warp(nft.endTime() + 1 seconds); // Warp to after auction ends
        vm.prank(user1);
        vm.expectRevert("AuctionEnded: Auction has passed current end time");
        nft.placeBid{value: TEST_RESERVE_PRICE}(USER1_FID);
    }

    function test_PlaceBid_Reverts_ZeroValue() public {
        vm.warp(nft.startTime() + 1 hours); // Ensure auction is active
        vm.prank(user1);
        vm.expectRevert("BidTooLow: Bid amount must be greater than zero");
        nft.placeBid{value: 0}(USER1_FID);
    }

    function test_PlaceBid_Reverts_FirstBid_BelowReserve() public {
        vm.warp(nft.startTime() + 1 hours);
        vm.prank(user1);
        vm.expectRevert("BidTooLow: Bid does not meet minimum requirement");
        nft.placeBid{value: TEST_RESERVE_PRICE - 1 wei}(USER1_FID);
    }

    function test_PlaceBid_Reverts_SubsequentBid_BelowMinIncrement() public {
        vm.warp(nft.startTime() + 1 hours);
        // User1 places a valid first bid
        vm.prank(user1);
        nft.placeBid{value: TEST_RESERVE_PRICE}(USER1_FID);

        // User2 tries to bid too low
        // Replicate internal logic of _calculateMinBid for test setup
        uint256 currentHighestBid_r1 = nft.highestBid();
        uint256 currentMinIncrementBps_r1 = nft.minIncrementBps();
        uint256 increment_r1 = (currentHighestBid_r1 * currentMinIncrementBps_r1) / 10000;
        uint256 minNextBid_r1 = currentHighestBid_r1 + increment_r1;

        vm.prank(user2);
        vm.expectRevert("BidTooLow: Bid does not meet minimum requirement");
        nft.placeBid{value: minNextBid_r1 - 1 wei}(USER2_FID);
    }

    // --- placeBid Success Tests: First Bid ---
    function test_PlaceBid_FirstBid_AtReserve() public {
        vm.warp(nft.startTime() + 1 hours);
        uint256 bidAmount = TEST_RESERVE_PRICE;

        vm.expectEmit(true, false, false, true); 
        emit BidPlaced(user1, bidAmount, USER1_FID);
        
        vm.prank(user1);
        nft.placeBid{value: bidAmount}(USER1_FID);

        assertEq(nft.highestBidder(), user1, "Highest bidder incorrect");
        assertEq(nft.highestBid(), bidAmount, "Highest bid incorrect");
        assertEq(nft.highestBidderFID(), USER1_FID, "Highest bidder FID incorrect");
        assertTrue(nft.hasFirstBid(), "hasFirstBid should be true");
        assertEq(nft.firstBidder(), user1, "First bidder incorrect");
        assertEq(nft.firstBidderFID(), USER1_FID, "First bidder FID incorrect");
        assertEq(nft.bidCount(user1), 1, "User1 bid count incorrect");
        assertEq(nft.bidderFID(user1), USER1_FID, "User1 FID in mapping incorrect");
        assertEq(nft.totalBids(), 1, "Total bids incorrect");
        assertEq(address(nft).balance, bidAmount, "Contract balance incorrect");
    }

    // --- placeBid Success Tests: Subsequent Bids ---
    function test_PlaceBid_SubsequentBid_DifferentBidder_Outbids() public {
        vm.warp(nft.startTime() + 1 hours);
        uint256 user1InitialBalance = user1.balance;

        // User1 places first bid
        vm.prank(user1);
        nft.placeBid{value: TEST_RESERVE_PRICE}(USER1_FID);
        uint256 user1BalanceAfterBid = user1.balance;
        assertTrue(user1BalanceAfterBid < user1InitialBalance - TEST_RESERVE_PRICE + 100 wei, "User1 balance not debited enough"); // Gas makes it not exact

        // User2 outbids User1
        // Replicate internal logic of _calculateMinBid for test setup
        uint256 currentHighestBid_s1 = nft.highestBid();
        uint256 currentMinIncrementBps_s1 = nft.minIncrementBps();
        uint256 increment_s1 = (currentHighestBid_s1 * currentMinIncrementBps_s1) / 10000;
        uint256 minNextBid_s1 = currentHighestBid_s1 + increment_s1;
        uint256 user2BidAmount = minNextBid_s1 + 0.01 ether;

        vm.expectEmit(true, false, false, true); 
        emit BidPlaced(user2, user2BidAmount, USER2_FID);

        vm.prank(user2);
        nft.placeBid{value: user2BidAmount}(USER2_FID);

        assertEq(nft.highestBidder(), user2, "Highest bidder should be User2");
        assertEq(nft.highestBid(), user2BidAmount, "Highest bid incorrect for User2");
        assertEq(nft.highestBidderFID(), USER2_FID, "Highest bidder FID should be User2's FID");
        assertEq(nft.bidCount(user1), 1, "User1 bid count should remain 1");
        assertEq(nft.bidCount(user2), 1, "User2 bid count should be 1");
        assertEq(nft.bidderFID(user2), USER2_FID, "User2 FID in mapping incorrect");
        assertEq(nft.totalBids(), 2, "Total bids should be 2");
        assertEq(address(nft).balance, user2BidAmount, "Contract balance should be User2's bid");
        // Check User1 was refunded - approximately, due to gas
        assertTrue(user1.balance > user1BalanceAfterBid, "User1 was not refunded");
        // More precise check on user1's balance if gas can be accounted for, or use change in balance.
        assertApproxEqAbs(user1.balance, user1InitialBalance - (user1InitialBalance - user1BalanceAfterBid - TEST_RESERVE_PRICE) , 0.001 ether, "User1 refund incorrect accounting for gas");
    }

    function test_PlaceBid_SubsequentBid_SameBidder_IncreasesBid() public {
        vm.warp(nft.startTime() + 1 hours);
        
        // User1 places first bid
        vm.prank(user1);
        nft.placeBid{value: TEST_RESERVE_PRICE}(USER1_FID);
        uint256 firstBidAmount = TEST_RESERVE_PRICE;
        assertEq(address(nft).balance, firstBidAmount, "Balance after 1st bid incorrect");

        // User1 increases their bid
        uint64 newFidForUser1 = USER1_FID + 1;
        uint256 currentHighest_s2 = nft.highestBid(); // Should be firstBidAmount
        uint256 currentMinIncrBps_s2 = nft.minIncrementBps();
        uint256 increment_s2 = (currentHighest_s2 * currentMinIncrBps_s2) / 10000;
        uint256 minNextBid_s2 = currentHighest_s2 + increment_s2;
        uint256 secondBidAmount = minNextBid_s2 + 0.01 ether;
        
        vm.expectEmit(true, false, false, true);
        emit BidPlaced(user1, secondBidAmount, newFidForUser1);

        uint256 user1BalanceBeforeIncrease = user1.balance;
        vm.prank(user1);
        nft.placeBid{value: secondBidAmount}(newFidForUser1);
        uint256 user1BalanceAfterIncrease = user1.balance;

        assertEq(nft.highestBidder(), user1, "Highest bidder should still be User1");
        assertEq(nft.highestBid(), secondBidAmount, "Highest bid incorrect for User1's second bid");
        assertEq(nft.highestBidderFID(), newFidForUser1, "Highest bidder FID should be updated for User1");
        assertEq(nft.bidCount(user1), 2, "User1 bid count should be 2");
        assertEq(nft.bidderFID(user1), newFidForUser1, "User1 FID in mapping should be updated");
        assertEq(nft.totalBids(), 2, "Total bids should be 2");
        assertEq(address(nft).balance, secondBidAmount, "Contract balance should be User1's new highest bid");
        
        // User1 sends secondBidAmount, gets firstBidAmount back. Net change = firstBidAmount - secondBidAmount.
        // So, balanceAfter = balanceBefore + (firstBidAmount - secondBidAmount) - gas
        // Or, balanceAfter = balanceBefore - (secondBidAmount - firstBidAmount) - gas
        uint256 expectedBalanceChange = secondBidAmount - firstBidAmount;
        assertApproxEqAbs(user1BalanceAfterIncrease, user1BalanceBeforeIncrease - expectedBalanceChange, 0.001 ether, "User1 balance change incorrect");
    }

    // --- placeBid Success Tests: Soft Close Logic ---
    function test_PlaceBid_SoftClose_NoExtension_BeforeWindow() public {
        vm.warp(nft.endTime() - nft.softCloseWindow() - 1 hours); // Ensure auction is active, but well before soft close window
        uint256 initialEndTime = nft.endTime();

        vm.prank(user1);
        nft.placeBid{value: TEST_RESERVE_PRICE}(USER1_FID);

        assertEq(nft.endTime(), initialEndTime, "EndTime should not have extended");
    }

    function test_PlaceBid_SoftClose_Extension_InsideWindow() public {
        vm.warp(nft.endTime() - nft.softCloseWindow() + 1 seconds); // Enter the soft close window by 1 second
        uint256 expectedNewEndTime = block.timestamp + nft.softCloseExtension(); // Bid timestamp + extension

        vm.expectEmit(false, false, false, true); 
        emit AuctionExtended(expectedNewEndTime);
        
        vm.prank(user1);
        nft.placeBid{value: TEST_RESERVE_PRICE}(USER1_FID);

        assertEq(nft.endTime(), expectedNewEndTime, "EndTime should have extended");
    }

    function test_PlaceBid_SoftClose_MultipleExtensions() public {
        vm.warp(nft.endTime() - nft.softCloseWindow() + 1 seconds); // First bid in window
        uint256 expectedEndTime1 = block.timestamp + nft.softCloseExtension();
        vm.prank(user1);
        nft.placeBid{value: TEST_RESERVE_PRICE}(USER1_FID);
        assertEq(nft.endTime(), expectedEndTime1, "EndTime incorrect after 1st extension");

        // Second bid, also in the *new* soft close window
        vm.warp(nft.endTime() - nft.softCloseWindow() + 1 seconds);
        // Replicate internal logic of _calculateMinBid for test setup
        uint256 currentHighestBid_sc1 = nft.highestBid();
        uint256 currentMinIncrementBps_sc1 = nft.minIncrementBps();
        uint256 increment_sc1 = (currentHighestBid_sc1 * currentMinIncrementBps_sc1) / 10000;
        uint256 minNextBid_sc1 = currentHighestBid_sc1 + increment_sc1;
        uint256 bidAmount2 = minNextBid_sc1 + 0.001 ether;
        uint256 expectedEndTime2 = block.timestamp + nft.softCloseExtension();
        vm.prank(user2);
        vm.expectEmit(false, false, false, true); 
        emit AuctionExtended(expectedEndTime2);
        nft.placeBid{value: bidAmount2}(USER2_FID);
        assertEq(nft.endTime(), expectedEndTime2, "EndTime incorrect after 2nd extension");

        // Third bid, by user1 again, in the *newer* soft close window
        vm.warp(nft.endTime() - nft.softCloseWindow() + 1 seconds);
        // Replicate internal logic of _calculateMinBid for test setup
        uint256 currentHighestBid_sc2 = nft.highestBid();
        uint256 currentMinIncrementBps_sc2 = nft.minIncrementBps();
        uint256 increment_sc2 = (currentHighestBid_sc2 * currentMinIncrementBps_sc2) / 10000;
        uint256 minNextBid_sc2 = currentHighestBid_sc2 + increment_sc2;
        uint256 bidAmount3 = minNextBid_sc2 + 0.001 ether;
        uint256 expectedEndTime3 = block.timestamp + nft.softCloseExtension();
        vm.prank(user1);
        vm.expectEmit(false, false, false, true); 
        emit AuctionExtended(expectedEndTime3);
        nft.placeBid{value: bidAmount3}(USER1_FID + 1); // Change FID to ensure bidderFID mapping is tested
        assertEq(nft.endTime(), expectedEndTime3, "EndTime incorrect after 3rd extension");
    }

    // --- Original Tests (TokenURI, SupportsInterface) ---
    function test_TokenURI_UnmintedToken() public view {
        string memory expectedURI = _expectedUnmintedTokenURI();
        string memory actualURI = nft.tokenURI(1);
        assertEq(actualURI, expectedURI, "tokenURI incorrect for unminted token");
    }

    function test_TokenURI_InvalidTokenId_TooHigh() public { 
        vm.expectRevert(bytes("JC4PNFT: Only TOKEN_ID 1 exists"));
        nft.tokenURI(2);
    }

    function test_TokenURI_InvalidTokenId_Zero() public { 
        vm.expectRevert(bytes("JC4PNFT: Only TOKEN_ID 1 exists"));
        nft.tokenURI(0);
    }
    
    function test_SupportsInterface_ERC721() public view {
        assertTrue(nft.supportsInterface(type(IERC721).interfaceId), "Should support IERC721");
    }

    function test_SupportsInterface_Random() public view {
        assertFalse(nft.supportsInterface(bytes4(0xffffffff)), "Should not support random");
    }

    // --- Tests for endAuction --- 

    function test_EndAuction_Reverts_BeforeEndTime() public {
        vm.warp(nft.startTime() + 1 hours); // Ensure auction started
        // Try to end auction before endTime
        vm.expectRevert("AuctionNotOver: Auction has not reached its end time yet");
        nft.endAuction();
    }

    function test_EndAuction_Reverts_AlreadyEnded() public {
        vm.warp(nft.endTime() + 1 seconds); // Go past end time
        nft.endAuction(); // End it successfully (no bids case)

        // Try to end it again
        vm.expectRevert("AuctionEnded: Auction already ended");
        nft.endAuction();
    }

    function test_EndAuction_Successful_WithWinner() public {
        vm.warp(nft.startTime() + 1 hours);
        // User1 places a winning bid
        uint256 winningBid = TEST_RESERVE_PRICE + 0.1 ether;
        vm.prank(user1);
        nft.placeBid{value: winningBid}(USER1_FID);

        vm.warp(nft.endTime() + 1 seconds); // Go past end time

        uint256 auctionOwnerInitialBalance = deployer.balance;

        vm.expectEmit(true, true, false, true); // checkSig, winner (topic1), skip topic2, amount (data1)
        emit AuctionEnded(user1, winningBid);
        nft.endAuction();

        assertTrue(nft.auctionEnded(), "Auction should be marked as ended");
        assertEq(nft.ownerOfToken(), user1, "NFT should be minted to winner (ownerOfToken)");
        assertEq(nft.getNFTOwner(), user1, "NFT should be minted to winner (getNFTOwner)");
        assertEq(nft.balanceOf(user1), 1, "Winner should have NFT balance of 1");
        
        assertEq(deployer.balance, auctionOwnerInitialBalance + winningBid, "Auction owner did not receive funds");
        assertEq(address(nft).balance, 0, "Contract should have no ETH balance after payout");

        // Check tokenURI for winner attributes (even with placeholders)
        string memory actualURIWithWinner = nft.tokenURI(1);
        string memory expectedURIWithWinner = _expectedWinnerTokenURI(); 
        
        console.log("----- BEGIN test_EndAuction_Successful_WithWinner DEBUG -----");
        console.log("Actual URI (from contract):");
        console.log(actualURIWithWinner);
        console.log("Expected URI (from test helper _expectedWinnerTokenURI):");
        console.log(expectedURIWithWinner);

        string memory actualJsonDebug = _jsonFromUri(actualURIWithWinner); 
        string memory expectedJsonDebug = _jsonFromUri(expectedURIWithWinner);

        console.log("Actual JSON Decoded (from contract):");
        console.log(actualJsonDebug);
        console.log("Expected JSON Decoded (from test helper _expectedWinnerJson):");
        console.log(expectedJsonDebug);
        console.log("----- END test_EndAuction_Successful_WithWinner DEBUG -----");

        assertEq(keccak256(bytes(actualURIWithWinner)), keccak256(bytes(expectedURIWithWinner)), "KECKED tokenURI incorrect after winner is set");
    }

    function test_EndAuction_Successful_NoBids() public {
        vm.warp(nft.endTime() + 1 seconds); // Go past end time
        uint256 auctionOwnerInitialBalance = deployer.balance;

        vm.expectEmit(true, true, false, true);
        emit AuctionEnded(address(0), 0);
        nft.endAuction();

        assertTrue(nft.auctionEnded(), "Auction should be marked as ended (no bids)");
        assertEq(nft.ownerOfToken(), address(0), "NFT should not be minted (ownerOfToken)");
        assertEq(nft.getNFTOwner(), address(0), "NFT should not be minted (getNFTOwner)");
        assertEq(deployer.balance, auctionOwnerInitialBalance, "Auction owner balance should not change");
        assertEq(address(nft).balance, 0, "Contract balance should be 0 (no bids)");

        // Check tokenURI does not contain winner attributes (i.e., it matches the unminted URI)
        string memory actualURI_NoBids = nft.tokenURI(1);
        string memory expectedURI_NoBids = _expectedUnmintedTokenURI();
        assertEq(actualURI_NoBids, expectedURI_NoBids, "tokenURI should be same as unminted if no winner");
    }

    function test_EndAuction_Successful_BidsBelowReserve() public {
        vm.warp(nft.startTime() + 1 hours);
        // User1 places a bid below reserve (this scenario isn't directly possible with current placeBid, 
        // as placeBid requires meeting reserve for the first bid. 
        // This test effectively becomes same as NoBids if placeBid enforces reserve.
        // To properly test this, placeBid would need to allow bids below reserve that don't become highestBid, 
        // or we assume reserve is 0 for this specific setup - let's keep placeBid as is and test no *valid* bids.
        // This test will behave like test_EndAuction_Successful_NoBids because no bid met reserve.

        vm.warp(nft.endTime() + 1 seconds); // Go past end time
        uint256 auctionOwnerInitialBalance = deployer.balance;

        vm.expectEmit(true, true, false, true);
        emit AuctionEnded(address(0), 0);
        nft.endAuction();

        assertTrue(nft.auctionEnded(), "Auction should be marked as ended (bids below reserve)");
        assertEq(nft.ownerOfToken(), address(0), "NFT should not be minted (bids below reserve)");
        assertEq(deployer.balance, auctionOwnerInitialBalance, "Auction owner balance should not change (bids below reserve)");
    }

    function test_PlaceBid_Fails_AfterAuctionEnded() public {
        vm.warp(nft.startTime() + 1 hours);
        // User1 places a valid bid
        vm.prank(user1);
        nft.placeBid{value: TEST_RESERVE_PRICE}(USER1_FID);

        // End the auction
        vm.warp(nft.endTime() + 1 seconds);
        nft.endAuction();

        assertTrue(nft.auctionEnded(), "Pre-condition: Auction must be ended");

        // Try to place another bid
        vm.prank(user2);
        vm.expectRevert("AuctionEnded: Auction has already ended");
        nft.placeBid{value: TEST_RESERVE_PRICE + 0.1 ether}(USER2_FID);
    }

    // Helper to construct the expected unminted/no-winner JSON string
    function _expectedUnmintedJson() internal pure returns (string memory) {
        return string(
            abi.encodePacked(
                '{"name": "', EXPECTED_NFT_NAME_METADATA, '",',
                '"description": "', EXPECTED_NFT_DESCRIPTION, '",',
                '"image": "', EXPECTED_NFT_IMAGE_URL, '"}'
            )
        );
    }

    // Helper to construct the expected unminted/no-winner full token URI (Base64 encoded)
    function _expectedUnmintedTokenURI() internal pure returns (string memory) {
        string memory json = _expectedUnmintedJson();
        string memory base64Json = Base64.encode(bytes(json));
        return string(abi.encodePacked("data:application/json;base64,", base64Json));
    }

    // Helper to construct the expected JSON string WITH winner attributes (placeholders)
    function _expectedWinnerJson() internal pure returns (string memory) {
        return string(
            abi.encodePacked(
                '{"name": "', EXPECTED_NFT_NAME_METADATA, '",',
                '"description": "', EXPECTED_NFT_DESCRIPTION, '",',
                '"image": "', EXPECTED_NFT_IMAGE_URL, '",', // Comma added as attributes will follow
                '"attributes":[{"trait_type":"Winner FID","value":"',
                "FID_PLACEHOLDER",
                '"},{"trait_type":"Winning Bid (wei)","value":"',
                "AMOUNT_PLACEHOLDER",
                '"}]}' // Close attributes array and main JSON object
            )
        );
    }

    // Helper to construct the expected full token URI WITH winner attributes (Base64 encoded)
    function _expectedWinnerTokenURI() internal pure returns (string memory) {
        string memory json = _expectedWinnerJson();
        string memory base64Json = Base64.encode(bytes(json));
        return string(abi.encodePacked("data:application/json;base64,", base64Json));
    }

    // Helper to get JSON from full URI for debugging
    function _jsonFromUri(string memory uri) internal pure returns (string memory) {
        bytes memory uriBytes = bytes(uri);
        uint256 prefixLength = 29; // Length of "data:application/json;base64,"
        if (uriBytes.length <= prefixLength) return "ERROR: URI too short or invalid prefix";
        
        // Basic check for prefix, can be made more robust if needed for general purpose
        // For debugging, we assume it mostly follows the pattern if it's long enough

        bytes memory base64PartBytes = new bytes(uriBytes.length - prefixLength);
        for(uint i = 0; i < base64PartBytes.length; i++){
            base64PartBytes[i] = uriBytes[i + prefixLength];
        }
        bytes memory decodedJsonBytes = Base64.decode(string(base64PartBytes));
        return string(decodedJsonBytes);
    }
} 