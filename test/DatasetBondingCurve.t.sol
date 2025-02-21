// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console2} from "forge-std/Test.sol";
import {DatasetToken} from "../src/DeployDataset.sol";
import {DatasetBondingCurve} from "../src/DatasetBondingCurve.sol";
import {MockUSDC} from "./mocks/MockUSDC.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DatasetBondingCurveTest is Test {
    DatasetBondingCurve public bondingCurve;
    DatasetBondingCurve public bondingCurveImpl;
    DatasetToken public datasetToken;
    DatasetToken public datasetTokenImpl;
    MockUSDC public mockUsdc;
    address public owner;
    address public user1;
    address public user2;

    // Test dataset parameters
    string[] public tags;
    DatasetToken.OwnershipShare[] public shares;

    // Constants for time-based tests
    uint256 constant WEEK = 7 days;
    uint256 constant INITIAL_PRICE = 100_000; // 0.1 USDC

    function setUp() public {
        owner = address(this);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        // Deploy mock USDC
        mockUsdc = new MockUSDC();

        // Deploy implementation contracts
        datasetTokenImpl = new DatasetToken();
        bondingCurveImpl = new DatasetBondingCurve();

        // Deploy and initialize DatasetToken proxy
        bytes memory datasetTokenData = abi.encodeWithSelector(
            DatasetToken.initialize.selector,
            "ipfs://",
            owner,
            address(mockUsdc)
        );
        ERC1967Proxy datasetTokenProxy = new ERC1967Proxy(
            address(datasetTokenImpl),
            datasetTokenData
        );
        datasetToken = DatasetToken(address(datasetTokenProxy));

        // Deploy and initialize BondingCurve proxy
        bytes memory bondingCurveData = abi.encodeWithSelector(
            DatasetBondingCurve.initialize.selector,
            address(datasetToken),
            address(mockUsdc),
            owner
        );
        ERC1967Proxy bondingCurveProxy = new ERC1967Proxy(
            address(bondingCurveImpl),
            bondingCurveData
        );
        bondingCurve = DatasetBondingCurve(address(bondingCurveProxy));

        // Set bonding curve in dataset token
        datasetToken.setBondingCurve(address(bondingCurve));

        // Setup test data
        tags.push("AI");
        tags.push("ML");

        // Create ownership shares
        shares.push(DatasetToken.OwnershipShare(user1, 5000)); // 50%
        shares.push(DatasetToken.OwnershipShare(user2, 5000)); // 50%

        // Mint USDC to users
        mockUsdc.mint(user1, 100_000_000); // 100 USDC
        mockUsdc.mint(user2, 100_000_000); // 100 USDC
    }

    function test_UpgradeBondingCurve() public {
        // Deploy new implementation
        DatasetBondingCurve newImpl = new DatasetBondingCurve();

        // Upgrade to new implementation
        bondingCurve.upgradeToAndCall(address(newImpl), "");

        // Verify upgrade
        assertEq(bondingCurve.owner(), owner);
    }

    function test_IndependentBondingCurves() public {
        vm.startPrank(owner);

        // Mint first dataset token with 0.1 USDC initial price
        datasetToken.mintDatasetToken(
            shares,
            "Dataset 1",
            "Description 1",
            "QmHash1",
            "ipfs://QmHash1",
            INITIAL_PRICE,
            tags
        );

        // Mint second dataset token with 0.2 USDC initial price
        datasetToken.mintDatasetToken(
            shares,
            "Dataset 2",
            "Description 2",
            "QmHash2",
            "ipfs://QmHash2",
            200_000, // 0.2 USDC
            tags
        );

        vm.stopPrank();

        // Check initial prices
        assertEq(
            bondingCurve.getCurrentPrice(0),
            INITIAL_PRICE,
            "First token should have 0.1 USDC initial price"
        );
        assertEq(
            bondingCurve.getCurrentPrice(1),
            200_000,
            "Second token should have 0.2 USDC initial price"
        );

        // Approve and purchase first token
        vm.startPrank(user1);
        mockUsdc.approve(address(datasetToken), INITIAL_PRICE);
        datasetToken.purchaseDataset(0);
        vm.stopPrank();

        // Check prices after purchase
        assertEq(
            bondingCurve.getCurrentPrice(0),
            150_000, // 0.15 USDC
            "First token price should increase by 1.5x"
        );
        assertEq(
            bondingCurve.getCurrentPrice(1),
            200_000,
            "Second token price should remain unchanged"
        );
    }

    function test_PriceIncrease() public {
        vm.startPrank(owner);

        // Mint token with 0.1 USDC initial price
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
            "Initial price should be 0.1 USDC"
        );

        // First purchase
        vm.startPrank(user1);
        mockUsdc.approve(address(datasetToken), INITIAL_PRICE);
        datasetToken.purchaseDataset(0);
        vm.stopPrank();

        uint256 secondPrice = bondingCurve.getCurrentPrice(0);
        assertEq(
            secondPrice,
            150_000, // 0.15 USDC
            "Price should increase by 1.5x after first purchase"
        );

        // Second purchase
        vm.startPrank(user2);
        mockUsdc.approve(address(datasetToken), 150_000);
        datasetToken.purchaseDataset(0);
        vm.stopPrank();

        uint256 thirdPrice = bondingCurve.getCurrentPrice(0);
        assertEq(
            thirdPrice,
            225_000, // 0.225 USDC
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
            90_000, // 0.09 USDC
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
            81_000, // 0.081 USDC
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
            90_000, // 0.09 USDC
            "Price should decrease by 10% after one week"
        );

        // Purchase at depreciated price
        vm.startPrank(user1);
        mockUsdc.approve(address(datasetToken), 90_000);
        datasetToken.purchaseDataset(0);
        vm.stopPrank();

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
            135_000, // 0.135 USDC
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

        // The base price is now 0.135 USDC, so after one week it should be 0.135 * 0.9 = 0.1215 USDC
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
            121_500, // 0.1215 USDC
            "Price should decrease by 10% from 0.135 USDC (0.135 * 0.9 = 0.1215)"
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
        vm.startPrank(user1);
        mockUsdc.approve(address(datasetToken), INITIAL_PRICE);
        datasetToken.purchaseDataset(0);
        vm.stopPrank();

        // Price should be 150_000 USDC after first purchase
        uint256 priceAfterFirstPurchase = bondingCurve.getCurrentPrice(0);
        assertEq(
            priceAfterFirstPurchase,
            150_000, // 0.15 USDC
            "Price should be 1.5x initial price after first purchase"
        );

        // Move time forward by one week
        vm.warp(block.timestamp + WEEK);

        uint256 priceAfterWeek = bondingCurve.getCurrentPrice(0);
        assertEq(
            priceAfterWeek,
            135_000, // 0.135 USDC
            "Price should decrease by 10% after one week (0.15 * 0.9 = 0.135)"
        );

        // Second purchase at depreciated price
        vm.startPrank(user2);
        mockUsdc.approve(address(datasetToken), 135_000);
        datasetToken.purchaseDataset(0);
        vm.stopPrank();

        uint256 priceAfterSecondPurchase = bondingCurve.getCurrentPrice(0);
        assertEq(
            priceAfterSecondPurchase,
            202_500, // 0.2025 USDC
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
