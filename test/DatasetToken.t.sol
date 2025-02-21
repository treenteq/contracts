// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console2} from "forge-std/Test.sol";
import {DatasetToken} from "../src/DeployDataset.sol";
import {DatasetBondingCurve} from "../src/DatasetBondingCurve.sol";
import {MockUSDC} from "./mocks/MockUSDC.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DatasetTokenTest is Test {
    DatasetToken public datasetToken;
    DatasetToken public datasetTokenImpl;
    DatasetBondingCurve public bondingCurve;
    DatasetBondingCurve public bondingCurveImpl;
    MockUSDC public mockUsdc;
    address public owner;
    address public user1;
    address public user2;
    address public user3;

    // Test data
    string constant BASE_URI = "https://api.example.com/metadata/";
    string constant DATASET_NAME = "Test Dataset";
    string constant DATASET_DESC = "Test Description";
    string constant CONTENT_HASH = "QmTest123ContentHash";
    string constant IPFS_HASH = "QmTest123IPFSHash";
    uint256 constant PRICE = 1_000_000; // 1 USDC
    string[] TAGS;
    DatasetToken.OwnershipShare[] shares;

    function setUp() public {
        // Set up addresses
        owner = makeAddr("owner");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");

        // Deploy mock USDC
        mockUsdc = new MockUSDC();

        // Set up test tags
        TAGS = new string[](3);
        TAGS[0] = "AI";
        TAGS[1] = "ML";
        TAGS[2] = "Data";

        // Deploy implementation contracts
        datasetTokenImpl = new DatasetToken();
        bondingCurveImpl = new DatasetBondingCurve();

        // Deploy and initialize proxies
        bytes memory datasetTokenData = abi.encodeWithSelector(
            DatasetToken.initialize.selector,
            BASE_URI,
            owner,
            address(mockUsdc)
        );
        ERC1967Proxy datasetTokenProxy = new ERC1967Proxy(
            address(datasetTokenImpl),
            datasetTokenData
        );
        datasetToken = DatasetToken(address(datasetTokenProxy));

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

        vm.prank(owner);
        datasetToken.setBondingCurve(address(bondingCurve));

        // Create ownership shares
        shares = new DatasetToken.OwnershipShare[](2);
        shares[0] = DatasetToken.OwnershipShare(user1, 7000); // 70%
        shares[1] = DatasetToken.OwnershipShare(user2, 3000); // 30%

        // Mint USDC to users
        mockUsdc.mint(user1, 100_000_000); // 100 USDC
        mockUsdc.mint(user2, 100_000_000); // 100 USDC
        mockUsdc.mint(user3, 100_000_000); // 100 USDC
    }

    function test_InitialState() public view {
        assertEq(datasetToken.owner(), owner);
        assertEq(datasetToken.getTotalTokens(), 0);
        assertEq(address(datasetToken.bondingCurve()), address(bondingCurve));
        assertEq(address(datasetToken.usdc()), address(mockUsdc));
    }

    function test_UpgradeDatasetToken() public {
        // Deploy new implementation
        DatasetToken newImpl = new DatasetToken();

        // Upgrade to new implementation
        vm.prank(owner);
        datasetToken.upgradeToAndCall(address(newImpl), "");

        // Verify upgrade
        assertEq(DatasetToken(address(datasetToken)).owner(), owner);
    }

    function test_MintDatasetToken() public {
        vm.startPrank(owner);
        datasetToken.mintDatasetToken(
            shares,
            DATASET_NAME,
            DATASET_DESC,
            CONTENT_HASH,
            IPFS_HASH,
            PRICE,
            TAGS
        );
        vm.stopPrank();

        assertEq(datasetToken.getTotalTokens(), 1);
        assertEq(datasetToken.balanceOf(user1, 0), 1);
        assertEq(datasetToken.balanceOf(user2, 0), 1);

        // Verify metadata
        (string memory name, , , , uint256 price, ) = datasetToken
            .getDatasetMetadata(0);

        assertEq(name, DATASET_NAME, "Name should match");
        assertEq(price, PRICE, "Price should match");
    }

    function test_PurchaseDataset() public {
        // First mint a token
        vm.startPrank(owner);
        datasetToken.mintDatasetToken(
            shares,
            DATASET_NAME,
            DATASET_DESC,
            CONTENT_HASH,
            IPFS_HASH,
            PRICE,
            TAGS
        );
        vm.stopPrank();

        // Record initial balances
        uint256 user1InitialBalance = mockUsdc.balanceOf(user1);
        uint256 user2InitialBalance = mockUsdc.balanceOf(user2);

        // Approve and purchase the token
        vm.startPrank(user3);
        mockUsdc.approve(address(datasetToken), PRICE);
        datasetToken.purchaseDataset(0);
        vm.stopPrank();

        // Verify token ownership remains unchanged
        assertEq(
            datasetToken.balanceOf(user1, 0),
            1,
            "User1 should still own the token"
        );
        assertEq(
            datasetToken.balanceOf(user2, 0),
            1,
            "User2 should still own the token"
        );
        assertEq(
            datasetToken.balanceOf(user3, 0),
            0,
            "User3 should not own the token"
        );

        // Verify payment distribution
        assertEq(
            mockUsdc.balanceOf(user1),
            user1InitialBalance + ((PRICE * 7000) / 10000),
            "User1 should receive 70% of payment"
        );
        assertEq(
            mockUsdc.balanceOf(user2),
            user2InitialBalance + ((PRICE * 3000) / 10000),
            "User2 should receive 30% of payment"
        );
    }

    function test_GetTokensByTag() public {
        vm.startPrank(owner);
        datasetToken.mintDatasetToken(
            shares,
            DATASET_NAME,
            DATASET_DESC,
            CONTENT_HASH,
            IPFS_HASH,
            PRICE,
            TAGS
        );
        vm.stopPrank();

        uint256[] memory aiTokens = datasetToken.getTokensByTag("AI");
        uint256[] memory mlTokens = datasetToken.getTokensByTag("ML");
        uint256[] memory dataTokens = datasetToken.getTokensByTag("Data");

        // All tags should point to the same token since we only minted one
        assertEq(aiTokens.length, 1, "Should have one AI token");
        assertEq(mlTokens.length, 1, "Should have one ML token");
        assertEq(dataTokens.length, 1, "Should have one Data token");

        // All should point to token ID 0
        assertEq(aiTokens[0], 0, "AI token should be token 0");
        assertEq(mlTokens[0], 0, "ML token should be token 0");
        assertEq(dataTokens[0], 0, "Data token should be token 0");
    }

    function test_GetAllDatasetMetadataEmpty() public view {
        DatasetToken.DatasetMetadata[] memory allMetadata = datasetToken
            .getAllDatasetMetadata();
        assertEq(
            allMetadata.length,
            0,
            "Should have no metadata when no tokens exist"
        );
    }

    function test_GetAllDatasetMetadataSingleToken() public {
        // Mint a single token
        vm.startPrank(owner);
        datasetToken.mintDatasetToken(
            shares,
            DATASET_NAME,
            DATASET_DESC,
            CONTENT_HASH,
            IPFS_HASH,
            PRICE,
            TAGS
        );
        vm.stopPrank();

        DatasetToken.DatasetMetadata[] memory allMetadata = datasetToken
            .getAllDatasetMetadata();

        // Verify length
        assertEq(allMetadata.length, 1, "Should have one metadata entry");

        // Verify metadata contents
        assertEq(allMetadata[0].name, DATASET_NAME, "Name should match");
        assertEq(
            allMetadata[0].description,
            DATASET_DESC,
            "Description should match"
        );
        assertEq(
            allMetadata[0].contentHash,
            CONTENT_HASH,
            "Content hash should match"
        );
        assertEq(allMetadata[0].ipfsHash, IPFS_HASH, "IPFS hash should match");
        assertEq(allMetadata[0].price, PRICE, "Initial price should match");
        assertEq(
            allMetadata[0].tags.length,
            TAGS.length,
            "Should have correct number of tags"
        );
        assertEq(
            allMetadata[0].owners.length,
            shares.length,
            "Should have correct number of owners"
        );

        // Verify tags
        for (uint256 i = 0; i < TAGS.length; i++) {
            assertEq(allMetadata[0].tags[i], TAGS[i], "Tag should match");
        }

        // Verify owners
        for (uint256 i = 0; i < shares.length; i++) {
            assertEq(
                allMetadata[0].owners[i].owner,
                shares[i].owner,
                "Owner address should match"
            );
            assertEq(
                allMetadata[0].owners[i].percentage,
                shares[i].percentage,
                "Owner percentage should match"
            );
        }
    }

    function test_GetAllDatasetMetadataMultipleTokens() public {
        // Mint first token
        vm.startPrank(owner);
        datasetToken.mintDatasetToken(
            shares,
            DATASET_NAME,
            DATASET_DESC,
            CONTENT_HASH,
            IPFS_HASH,
            PRICE,
            TAGS
        );

        // Create different metadata for second token
        string memory name2 = "Second Dataset";
        string memory desc2 = "Second Description";
        string memory hash2 = "QmTest456ContentHash";
        string memory ipfs2 = "QmTest456IPFSHash";
        uint256 price2 = 2_000_000; // 2 USDC

        // Create different ownership shares for second token
        DatasetToken.OwnershipShare[]
            memory shares2 = new DatasetToken.OwnershipShare[](2);
        shares2[0] = DatasetToken.OwnershipShare(user2, 6000); // 60%
        shares2[1] = DatasetToken.OwnershipShare(user3, 4000); // 40%

        // Mint second token
        datasetToken.mintDatasetToken(
            shares2,
            name2,
            desc2,
            hash2,
            ipfs2,
            price2,
            TAGS
        );
        vm.stopPrank();

        DatasetToken.DatasetMetadata[] memory allMetadata = datasetToken
            .getAllDatasetMetadata();

        // Verify length
        assertEq(allMetadata.length, 2, "Should have two metadata entries");

        // Verify first token metadata
        assertEq(
            allMetadata[0].name,
            DATASET_NAME,
            "First token name should match"
        );
        assertEq(allMetadata[0].price, PRICE, "First token price should match");
        assertEq(
            allMetadata[0].owners.length,
            shares.length,
            "First token should have correct number of owners"
        );

        // Verify second token metadata
        assertEq(allMetadata[1].name, name2, "Second token name should match");
        assertEq(
            allMetadata[1].price,
            price2,
            "Second token price should match"
        );
        assertEq(
            allMetadata[1].owners.length,
            shares2.length,
            "Second token should have correct number of owners"
        );

        // Verify second token owners
        assertEq(
            allMetadata[1].owners[0].owner,
            user2,
            "Second token first owner should match"
        );
        assertEq(
            allMetadata[1].owners[0].percentage,
            6000,
            "Second token first owner percentage should match"
        );
        assertEq(
            allMetadata[1].owners[1].owner,
            user3,
            "Second token second owner should match"
        );
        assertEq(
            allMetadata[1].owners[1].percentage,
            4000,
            "Second token second owner percentage should match"
        );
    }

    function test_GetAllDatasetMetadataPriceChanges() public {
        // Mint a token
        vm.startPrank(owner);
        datasetToken.mintDatasetToken(
            shares,
            DATASET_NAME,
            DATASET_DESC,
            CONTENT_HASH,
            IPFS_HASH,
            PRICE,
            TAGS
        );
        vm.stopPrank();

        // Get initial metadata
        DatasetToken.DatasetMetadata[] memory initialMetadata = datasetToken
            .getAllDatasetMetadata();
        uint256 initialPrice = initialMetadata[0].price;

        // Purchase the token to trigger price increase
        vm.startPrank(user3);
        mockUsdc.approve(address(datasetToken), PRICE);
        datasetToken.purchaseDataset(0);
        vm.stopPrank();

        // Get updated metadata
        DatasetToken.DatasetMetadata[] memory updatedMetadata = datasetToken
            .getAllDatasetMetadata();
        uint256 newPrice = updatedMetadata[0].price;

        // Price should have increased by 1.5x according to bonding curve
        assertEq(
            newPrice,
            (initialPrice * 15) / 10,
            "Price should increase by 1.5x after purchase"
        );
    }

    function test_PurchaseTracking() public {
        // First mint a token
        vm.startPrank(owner);
        datasetToken.mintDatasetToken(
            shares,
            DATASET_NAME,
            DATASET_DESC,
            CONTENT_HASH,
            IPFS_HASH,
            PRICE,
            TAGS
        );

        // Mint a second token
        datasetToken.mintDatasetToken(
            shares,
            "Second Dataset",
            DATASET_DESC,
            CONTENT_HASH,
            IPFS_HASH,
            PRICE,
            TAGS
        );
        vm.stopPrank();

        // Purchase first token with user3
        vm.startPrank(user3);
        mockUsdc.approve(address(datasetToken), PRICE * 2);
        datasetToken.purchaseDataset(0);

        // Verify purchase tracking
        uint256[] memory purchasedTokens = datasetToken.getPurchasedTokens(
            user3
        );
        assertEq(purchasedTokens.length, 1, "Should have one purchased token");
        assertEq(purchasedTokens[0], 0, "Should have purchased token 0");
        assertTrue(
            datasetToken.hasPurchased(user3, 0),
            "Should have purchased token 0"
        );
        assertFalse(
            datasetToken.hasPurchased(user3, 1),
            "Should not have purchased token 1"
        );

        // Purchase second token
        datasetToken.purchaseDataset(1);

        // Verify updated purchase tracking
        purchasedTokens = datasetToken.getPurchasedTokens(user3);
        assertEq(purchasedTokens.length, 2, "Should have two purchased tokens");
        assertEq(purchasedTokens[0], 0, "First purchase should be token 0");
        assertEq(purchasedTokens[1], 1, "Second purchase should be token 1");
        assertTrue(
            datasetToken.hasPurchased(user3, 0),
            "Should have purchased token 0"
        );
        assertTrue(
            datasetToken.hasPurchased(user3, 1),
            "Should have purchased token 1"
        );
        vm.stopPrank();

        // Verify no purchases for other users
        uint256[] memory user1Purchases = datasetToken.getPurchasedTokens(
            user1
        );
        assertEq(user1Purchases.length, 0, "User1 should have no purchases");
        assertFalse(
            datasetToken.hasPurchased(user1, 0),
            "User1 should not have purchased token 0"
        );
    }
}
