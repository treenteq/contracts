// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {DatasetToken} from "../src/DeployDataset.sol";

contract DeployDatasetScript is Script {
    function setUp() public {}

    function run() public {
        // Retrieve the private key from environment variable
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // Start broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);

        // Deploy the contract
        // Parameters:
        // 1. Base URI for metadata (e.g., IPFS gateway URL)
        // 2. Initial owner address (msg.sender in this case)
        new DatasetToken(
            "https://api.example.com/metadata/", // Replace with your actual metadata URI NOTE: Discuss with Rahul on how we were setting this up
            vm.addr(deployerPrivateKey) // Set deployer as initial owner
        );

        vm.stopBroadcast();
    }
}
