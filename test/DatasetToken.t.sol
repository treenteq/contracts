// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console2} from "forge-std/Test.sol";
import {DatasetToken} from "../src/DeployDataset.sol";
import {DatasetBondingCurve} from "../src/DatasetBondingCurve.sol";

contract DatasetTokenTest is Test {
    DatasetToken public datasetToken;
    DatasetBondingCurve public bondingCurve;
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
    uint256 constant PRICE = 1 ether;
    string[] TAGS;
    DatasetToken.OwnershipShare[] shares;

    function setUp() public {
        // Set up addresses
        owner = makeAddr("owner");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");

        // Set up test tags
        TAGS = new string[](3);
        TAGS[0] = "AI";
        TAGS[1] = "ML";
        TAGS[2] = "Data";

        // Deploy contract
        vm.prank(owner);
        datasetToken = new DatasetToken(BASE_URI, owner);

        // Deploy and set up bonding curve
        bondingCurve = new DatasetBondingCurve(address(datasetToken), owner);
        vm.prank(owner);
        datasetToken.setBondingCurve(address(bondingCurve));

        // Setup test data
        TAGS = new string[](3);
        TAGS[0] = "AI";
        TAGS[1] = "ML";
        TAGS[2] = "Data";

        // Create ownership shares
        shares = new DatasetToken.OwnershipShare[](2);
        shares[0] = DatasetToken.OwnershipShare(user1, 7000); // 70%
        shares[1] = DatasetToken.OwnershipShare(user2, 3000); // 30%

        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);
    }

    function test_InitialState() public view {
        assertEq(datasetToken.owner(), owner);
        assertEq(datasetToken.getTotalTokens(), 0);
        assertEq(address(datasetToken.bondingCurve()), address(bondingCurve));
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
        (
            string memory name, // description
            ,
            ,
            ,
            // contentHash
            // ipfsHash
            uint256 price, // tags

        ) = datasetToken.getDatasetMetadata(0);

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
        uint256 user1InitialBalance = user1.balance;
        uint256 user2InitialBalance = user2.balance;

        // Purchase the token
        vm.prank(user3);
        vm.deal(user3, PRICE);
        datasetToken.purchaseDataset{value: PRICE}(0);

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
            user1.balance,
            user1InitialBalance + ((PRICE * 7000) / 10000),
            "User1 should receive 70% of payment"
        );
        assertEq(
            user2.balance,
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
        uint256 price2 = 2 ether;

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
        vm.deal(user3, PRICE);
        datasetToken.purchaseDataset{value: PRICE}(0);
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
}
