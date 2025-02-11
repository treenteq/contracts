// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console2} from "forge-std/Test.sol";
import {DatasetToken} from "../src/DeployDataset.sol";
import {DatasetBondingCurve} from "../src/DatasetBondingCurve.sol";

contract DatasetBondingCurveTest is Test {
    DatasetBondingCurve public bondingCurve;
    DatasetToken public datasetToken;
    address public owner;
    address public user1;
    address public user2;

    // Test dataset parameters
    string[] public tags;
    DatasetToken.OwnershipShare[] public shares;

    // Constants for time-based tests
    uint256 constant WEEK = 7 days;
    uint256 constant INITIAL_PRICE = 0.1 ether;

    function setUp() public {
        owner = address(this);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        // Deploy DatasetToken
        datasetToken = new DatasetToken("ipfs://", owner);

        // Deploy BondingCurve
        bondingCurve = new DatasetBondingCurve(address(datasetToken), owner);

        // Set bonding curve in dataset token
        datasetToken.setBondingCurve(address(bondingCurve));

        // Setup test data
        tags.push("AI");
        tags.push("ML");

        // Create ownership shares
        shares.push(DatasetToken.OwnershipShare(user1, 5000)); // 50%
        shares.push(DatasetToken.OwnershipShare(user2, 5000)); // 50%

        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);
    }

    function test_IndependentBondingCurves() public {
        vm.startPrank(owner);

        // Mint first dataset token with 0.1 ether initial price
        datasetToken.mintDatasetToken(
            shares,
            "Dataset 1",
            "Description 1",
            "QmHash1",
            "ipfs://QmHash1",
            INITIAL_PRICE,
            tags
        );

        // Mint second dataset token with 0.2 ether initial price
        datasetToken.mintDatasetToken(
            shares,
            "Dataset 2",
            "Description 2",
            "QmHash2",
            "ipfs://QmHash2",
            0.2 ether,
            tags
        );

        vm.stopPrank();

        // Check initial prices
        assertEq(
            bondingCurve.getCurrentPrice(0),
            INITIAL_PRICE,
            "First token should have 0.1 ether initial price"
        );
        assertEq(
            bondingCurve.getCurrentPrice(1),
            0.2 ether,
            "Second token should have 0.2 ether initial price"
        );

        // Purchase first token
        vm.prank(user1);
        datasetToken.purchaseDataset{value: INITIAL_PRICE}(0);

        // Check prices after purchase
        assertEq(
            bondingCurve.getCurrentPrice(0),
            0.15 ether,
            "First token price should increase by 1.5x"
        );
        assertEq(
            bondingCurve.getCurrentPrice(1),
            0.2 ether,
            "Second token price should remain unchanged"
        );
    }

    function test_PriceIncrease() public {
        vm.startPrank(owner);

        // Mint token with 0.1 ether initial price
        datasetToken.mintDatasetToken(
            shares,
            "Dataset 1",
            "Description 1",
            "QmHash1",
            "ipfs://QmHash1",
            INITIAL_PRICE,
            tags
        );
        vm.stopPrank();

        uint256 initialPrice = bondingCurve.getCurrentPrice(0);
        assertEq(
            initialPrice,
            INITIAL_PRICE,
            "Initial price should be 0.1 ether"
        );

        // First purchase
        vm.prank(user1);
        datasetToken.purchaseDataset{value: INITIAL_PRICE}(0);

        uint256 secondPrice = bondingCurve.getCurrentPrice(0);
        assertEq(
            secondPrice,
            0.15 ether,
            "Price should increase by 1.5x after first purchase"
        );

        // Second purchase
        vm.prank(user2);
        datasetToken.purchaseDataset{value: 0.15 ether}(0);

        uint256 thirdPrice = bondingCurve.getCurrentPrice(0);
        assertEq(
            thirdPrice,
            0.225 ether,
            "Price should increase by 1.5x after second purchase"
        );
    }

    function test_PriceDepreciationAfterOneWeek() public {
        vm.startPrank(owner);
        datasetToken.mintDatasetToken(
            shares,
            "Dataset 1",
            "Description 1",
            "QmHash1",
            "ipfs://QmHash1",
            INITIAL_PRICE,
            tags
        );
        vm.stopPrank();

        // Move time forward by one week
        vm.warp(block.timestamp + WEEK);

        uint256 priceAfterWeek = bondingCurve.getCurrentPrice(0);
        assertEq(
            priceAfterWeek,
            0.09 ether,
            "Price should decrease by 10% after one week"
        );
    }

    function test_PriceDepreciationAfterMultipleWeeks() public {
        vm.startPrank(owner);
        datasetToken.mintDatasetToken(
            shares,
            "Dataset 1",
            "Description 1",
            "QmHash1",
            "ipfs://QmHash1",
            INITIAL_PRICE,
            tags
        );
        vm.stopPrank();

        // Move time forward by two weeks
        vm.warp(block.timestamp + 2 * WEEK);

        uint256 priceAfterTwoWeeks = bondingCurve.getCurrentPrice(0);
        assertEq(
            priceAfterTwoWeeks,
            0.081 ether,
            "Price should decrease by 19% after two weeks"
        );
    }

    function test_PriceDepreciationResetAfterPurchase() public {
        vm.startPrank(owner);
        datasetToken.mintDatasetToken(
            shares,
            "Dataset 1",
            "Description 1",
            "QmHash1",
            "ipfs://QmHash1",
            INITIAL_PRICE,
            tags
        );
        vm.stopPrank();

        // Start at timestamp 1
        vm.warp(1);
        uint256 initialTimestamp = block.timestamp;
        console2.log("Initial timestamp:", initialTimestamp);
        console2.log("Initial base price:", bondingCurve.currentBasePrices(0));

        // Move time forward by one week
        vm.warp(initialTimestamp + WEEK);
        console2.log("Timestamp after first week:", block.timestamp);
        console2.log("Time passed:", block.timestamp - initialTimestamp);
        console2.log(
            "Base price before first depreciation:",
            bondingCurve.currentBasePrices(0)
        );

        uint256 priceAfterWeek = bondingCurve.getCurrentPrice(0);
        console2.log("Price after week:", priceAfterWeek);
        console2.log(
            "Base price after first depreciation:",
            bondingCurve.currentBasePrices(0)
        );
        assertEq(
            priceAfterWeek,
            0.09 ether,
            "Price should decrease by 10% after one week"
        );

        // Purchase at depreciated price
        vm.prank(user1);
        datasetToken.purchaseDataset{value: 0.09 ether}(0);

        uint256 purchaseTimestamp = block.timestamp;
        console2.log("Purchase timestamp:", purchaseTimestamp);

        // Check price immediately after purchase
        uint256 priceAfterPurchase = bondingCurve.getCurrentPrice(0);
        console2.log("Price after purchase:", priceAfterPurchase);
        console2.log(
            "Base price after purchase:",
            bondingCurve.currentBasePrices(0)
        );
        assertEq(
            priceAfterPurchase,
            0.135 ether,
            "Price should be 1.5x the depreciated price (0.09 * 1.5 = 0.135)"
        );

        // Move time forward by one week plus one second to ensure we're in the next week
        vm.warp(purchaseTimestamp + WEEK + 1);
        console2.log("Timestamp one week after purchase:", block.timestamp);
        console2.log(
            "Time since purchase:",
            block.timestamp - purchaseTimestamp
        );
        console2.log(
            "Base price before second depreciation:",
            bondingCurve.currentBasePrices(0)
        );

        // The base price is now 0.135 ETH, so after one week it should be 0.135 * 0.9 = 0.1215
        uint256 priceOneWeekAfterPurchase = bondingCurve.getCurrentPrice(0);
        console2.log(
            "Price one week after purchase:",
            priceOneWeekAfterPurchase
        );
        console2.log(
            "Base price after second depreciation:",
            bondingCurve.currentBasePrices(0)
        );
        assertEq(
            priceOneWeekAfterPurchase,
            0.1215 ether,
            "Price should decrease by 10% from 0.135 ETH (0.135 * 0.9 = 0.1215)"
        );
    }

    function test_PriceDepreciationWithMultiplePurchases() public {
        vm.startPrank(owner);
        datasetToken.mintDatasetToken(
            shares,
            "Dataset 1",
            "Description 1",
            "QmHash1",
            "ipfs://QmHash1",
            INITIAL_PRICE,
            tags
        );
        vm.stopPrank();

        // First purchase at initial price
        vm.prank(user1);
        datasetToken.purchaseDataset{value: INITIAL_PRICE}(0);

        // Price should be 0.15 ether after first purchase
        uint256 priceAfterFirstPurchase = bondingCurve.getCurrentPrice(0);
        assertEq(
            priceAfterFirstPurchase,
            0.15 ether,
            "Price should be 1.5x initial price after first purchase"
        );

        // Move time forward by one week
        vm.warp(block.timestamp + WEEK);

        uint256 priceAfterWeek = bondingCurve.getCurrentPrice(0);
        assertEq(
            priceAfterWeek,
            0.135 ether,
            "Price should decrease by 10% after one week (0.15 * 0.9 = 0.135)"
        );

        // Second purchase at depreciated price
        vm.prank(user2);
        datasetToken.purchaseDataset{value: 0.135 ether}(0);

        uint256 priceAfterSecondPurchase = bondingCurve.getCurrentPrice(0);
        assertEq(
            priceAfterSecondPurchase,
            0.2025 ether,
            "Price should increase by 1.5x from depreciated price (0.135 * 1.5 = 0.2025)"
        );
    }

    function test_SetBondingCurve() public {
        address newBondingCurve = makeAddr("newBondingCurve");

        vm.prank(owner);
        datasetToken.setBondingCurve(newBondingCurve);

        assertEq(
            address(datasetToken.bondingCurve()),
            newBondingCurve,
            "Bonding curve address should be updated"
        );
    }

    function test_OnlyOwnerCanSetBondingCurve() public {
        address newBondingCurve = makeAddr("newBondingCurve");

        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSignature(
                "OwnableUnauthorizedAccount(address)",
                user1
            )
        );
        datasetToken.setBondingCurve(newBondingCurve);
    }

    function test_CannotSetZeroAddressBondingCurve() public {
        vm.prank(owner);
        vm.expectRevert("Invalid bonding curve address");
        datasetToken.setBondingCurve(address(0));
    }
}
