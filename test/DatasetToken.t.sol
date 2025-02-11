// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {DatasetToken} from "../src/DeployDataset.sol";

contract DatasetTokenTest is Test {
    DatasetToken public datasetToken;
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
    }

    function test_InitialState() public view {
        assertEq(datasetToken.owner(), owner);
        assertEq(datasetToken.getTotalTokens(), 0);
    }

    function test_MintDatasetToken() public {
        // Create ownership shares
        DatasetToken.OwnershipShare[]
            memory shares = new DatasetToken.OwnershipShare[](2);
        shares[0] = DatasetToken.OwnershipShare(user1, 7000); // 70%
        shares[1] = DatasetToken.OwnershipShare(user2, 3000); // 30%

        // Mint token as owner
        vm.prank(owner);
        datasetToken.mintDatasetToken(
            shares,
            DATASET_NAME,
            DATASET_DESC,
            CONTENT_HASH,
            IPFS_HASH,
            PRICE,
            TAGS
        );

        // Verify token was minted
        assertEq(datasetToken.getTotalTokens(), 1);
        assertEq(datasetToken.balanceOf(user1, 0), 1);
        assertEq(datasetToken.balanceOf(user2, 0), 1);

        // Verify metadata
        (string memory name, , , , uint256 price) = datasetToken.tokenMetadata(
            0
        );
        assertEq(name, DATASET_NAME);
        assertEq(price, PRICE);
    }

    function test_PurchaseDataset() public {
        // First mint a token
        DatasetToken.OwnershipShare[]
            memory shares = new DatasetToken.OwnershipShare[](2);
        shares[0] = DatasetToken.OwnershipShare(user1, 7000); // 70%
        shares[1] = DatasetToken.OwnershipShare(user2, 3000); // 30%

        vm.prank(owner);
        datasetToken.mintDatasetToken(
            shares,
            DATASET_NAME,
            DATASET_DESC,
            CONTENT_HASH,
            IPFS_HASH,
            PRICE,
            TAGS
        );

        // Record initial balances
        uint256 user1InitialBalance = user1.balance;
        uint256 user2InitialBalance = user2.balance;

        // Purchase as user3
        vm.deal(user3, PRICE);
        vm.prank(user3);
        datasetToken.purchaseDataset{value: PRICE}(0);

        // Verify token ownership transfer
        assertEq(datasetToken.balanceOf(user3, 0), 2);
        assertEq(datasetToken.balanceOf(user1, 0), 0);
        assertEq(datasetToken.balanceOf(user2, 0), 0);

        // Verify payment distribution
        assertEq(user1.balance, user1InitialBalance + ((PRICE * 7000) / 10000)); // 70%
        assertEq(user2.balance, user2InitialBalance + ((PRICE * 3000) / 10000)); // 30%
    }

    function test_UpdatePrice() public {
        // First mint a token
        DatasetToken.OwnershipShare[]
            memory shares = new DatasetToken.OwnershipShare[](1);
        shares[0] = DatasetToken.OwnershipShare(user1, 10000); // 100%

        vm.prank(owner);
        datasetToken.mintDatasetToken(
            shares,
            DATASET_NAME,
            DATASET_DESC,
            CONTENT_HASH,
            IPFS_HASH,
            PRICE,
            TAGS
        );

        // Update price as primary owner
        uint256 newPrice = 2 ether;
        vm.prank(user1);
        datasetToken.updatePrice(0, newPrice);

        // Verify price update
        (, , , , uint256 price) = datasetToken.tokenMetadata(0);
        assertEq(price, newPrice);
    }

    function testFail_UpdatePriceNonOwner() public {
        // First mint a token
        DatasetToken.OwnershipShare[]
            memory shares = new DatasetToken.OwnershipShare[](1);
        shares[0] = DatasetToken.OwnershipShare(user1, 10000); // 100%

        vm.prank(owner);
        datasetToken.mintDatasetToken(
            shares,
            DATASET_NAME,
            DATASET_DESC,
            CONTENT_HASH,
            IPFS_HASH,
            PRICE,
            TAGS
        );

        // Try to update price as non-owner (should fail)
        vm.prank(user2);
        datasetToken.updatePrice(0, 2 ether);
    }

    function test_GetTokensByTag() public {
        // First mint two tokens with different tags
        DatasetToken.OwnershipShare[]
            memory shares = new DatasetToken.OwnershipShare[](1);
        shares[0] = DatasetToken.OwnershipShare(user1, 10000);

        string[] memory tags1 = new string[](1);
        tags1[0] = "AI";

        string[] memory tags2 = new string[](1);
        tags2[0] = "ML";

        vm.startPrank(owner);
        datasetToken.mintDatasetToken(
            shares,
            DATASET_NAME,
            DATASET_DESC,
            CONTENT_HASH,
            IPFS_HASH,
            PRICE,
            tags1
        );

        datasetToken.mintDatasetToken(
            shares,
            DATASET_NAME,
            DATASET_DESC,
            CONTENT_HASH,
            IPFS_HASH,
            PRICE,
            tags2
        );
        vm.stopPrank();

        // Verify tag indexing
        uint256[] memory aiTokens = datasetToken.getTokensByTag("AI");
        uint256[] memory mlTokens = datasetToken.getTokensByTag("ML");

        assertEq(aiTokens.length, 1);
        assertEq(mlTokens.length, 1);
        assertEq(aiTokens[0], 0);
        assertEq(mlTokens[0], 1);
    }
}
