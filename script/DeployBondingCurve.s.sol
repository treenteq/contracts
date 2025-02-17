// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {DatasetBondingCurve} from "../src/DatasetBondingCurve.sol";
import {DatasetToken} from "../src/DeployDataset.sol";

contract DeployBondingCurve is Script {
    function run() external returns (DatasetBondingCurve, DatasetToken) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployerAddress = vm.addr(deployerPrivateKey);
        address usdcAddress = vm.envAddress("USDC_ADDRESS");

        vm.startBroadcast(deployerPrivateKey);

        // First deploy the DatasetToken contract
        DatasetToken datasetToken = new DatasetToken(
            "ipfs://",
            deployerAddress,
            usdcAddress
        );

        // Then deploy the BondingCurve contract
        DatasetBondingCurve bondingCurve = new DatasetBondingCurve(
            address(datasetToken),
            usdcAddress,
            deployerAddress
        );

        // Set the bonding curve in the dataset token contract
        datasetToken.setBondingCurve(address(bondingCurve));

        vm.stopBroadcast();

        return (bondingCurve, datasetToken);
    }
}
