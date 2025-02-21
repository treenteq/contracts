// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {DatasetBondingCurve} from "../src/DatasetBondingCurve.sol";
import {DatasetToken} from "../src/DeployDataset.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployBondingCurve is Script {
    function run() external returns (DatasetBondingCurve, DatasetToken) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployerAddress = vm.addr(deployerPrivateKey);
        address usdcAddress = vm.envAddress("USDC_ADDRESS");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy implementation contracts
        DatasetToken datasetTokenImpl = new DatasetToken();
        DatasetBondingCurve bondingCurveImpl = new DatasetBondingCurve();

        // Prepare initialization data for DatasetToken
        bytes memory datasetTokenData = abi.encodeWithSelector(
            DatasetToken.initialize.selector,
            "ipfs://",
            deployerAddress,
            usdcAddress
        );

        // Deploy DatasetToken proxy
        ERC1967Proxy datasetTokenProxy = new ERC1967Proxy(
            address(datasetTokenImpl),
            datasetTokenData
        );
        DatasetToken datasetToken = DatasetToken(address(datasetTokenProxy));

        // Prepare initialization data for BondingCurve
        bytes memory bondingCurveData = abi.encodeWithSelector(
            DatasetBondingCurve.initialize.selector,
            address(datasetToken),
            usdcAddress,
            deployerAddress
        );

        // Deploy BondingCurve proxy
        ERC1967Proxy bondingCurveProxy = new ERC1967Proxy(
            address(bondingCurveImpl),
            bondingCurveData
        );
        DatasetBondingCurve bondingCurve = DatasetBondingCurve(
            address(bondingCurveProxy)
        );

        // Set the bonding curve in the dataset token contract
        datasetToken.setBondingCurve(address(bondingCurve));

        vm.stopBroadcast();

        return (bondingCurve, datasetToken);
    }
}

// Upgrade script for future upgrades
contract UpgradeContracts is Script {
    function run(address proxyAddress, string memory contractType) external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        if (
            keccak256(bytes(contractType)) == keccak256(bytes("DatasetToken"))
        ) {
            // Deploy new DatasetToken implementation
            DatasetToken newImpl = new DatasetToken();

            // Upgrade proxy to new implementation
            DatasetToken(proxyAddress).upgradeToAndCall(address(newImpl), "");
        } else if (
            keccak256(bytes(contractType)) == keccak256(bytes("BondingCurve"))
        ) {
            // Deploy new BondingCurve implementation
            DatasetBondingCurve newImpl = new DatasetBondingCurve();

            // Upgrade proxy to new implementation
            DatasetBondingCurve(proxyAddress).upgradeToAndCall(
                address(newImpl),
                ""
            );
        }

        vm.stopBroadcast();
    }
}
