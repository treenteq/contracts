// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {DatasetToken} from "./DeployDataset.sol";
import {IUSDC} from "./interfaces/IUSDC.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {console2} from "forge-std/console2.sol";

contract DatasetBondingCurve is
    Initializable,
    OwnableUpgradeable,
    UUPSUpgradeable
{
    using Math for uint256;

    // The Dataset Token contract
    DatasetToken public datasetToken;
    // The USDC token contract
    IUSDC public usdc;

    // Bonding curve parameters
    uint256 public constant PRICE_MULTIPLIER = 1_500_000; // 1.5x increase per token (in USDC decimals)
    uint256 public constant DENOMINATOR = 1_000_000; // 1.0 in USDC decimals
    uint256 public constant WEEK = 7 days;
    uint256 public constant DEPRECIATION_RATE = 900_000; // 0.9 in USDC decimals (10% decrease per week)

    // Mapping to store initial prices for each token
    mapping(uint256 => uint256) public tokenInitialPrices;
    // Mapping to store the number of purchases for each token
    mapping(uint256 => uint256) public tokenPurchaseCount;
    // Mapping to store the last purchase timestamp for each token
    mapping(uint256 => uint256) public lastPurchaseTimestamp;
    // Mapping to store the current base price for each token (after depreciation)
    mapping(uint256 => uint256) public currentBasePrices;

    event PriceCalculated(uint256 indexed tokenId, uint256 price);
    event InitialPriceSet(uint256 indexed tokenId, uint256 initialPrice);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev Initializer function to replace constructor
     * @param datasetTokenAddress The address of the dataset token contract
     * @param usdcAddress The address of the USDC token contract
     * @param initialOwner The address of the initial owner
     */
    function initialize(
        address datasetTokenAddress,
        address usdcAddress,
        address initialOwner
    ) public initializer {
        require(
            datasetTokenAddress != address(0),
            "Invalid dataset token address"
        );
        require(usdcAddress != address(0), "Invalid USDC address");

        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();

        datasetToken = DatasetToken(datasetTokenAddress);
        usdc = IUSDC(usdcAddress);
    }

    /**
     * @dev Required override for UUPS proxy upgrade authorization
     */
    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    /**
     * @dev Set the initial price for a token's bonding curve
     * @param tokenId The ID of the token
     * @param initialPrice The initial price in USDC (with 6 decimals)
     */
    function setInitialPrice(uint256 tokenId, uint256 initialPrice) external {
        require(
            msg.sender == address(datasetToken),
            "Only dataset token contract can set initial price"
        );
        require(initialPrice > 0, "Initial price must be greater than 0");
        require(tokenInitialPrices[tokenId] == 0, "Initial price already set");

        tokenInitialPrices[tokenId] = initialPrice;
        currentBasePrices[tokenId] = initialPrice;
        lastPurchaseTimestamp[tokenId] = block.timestamp;
        emit InitialPriceSet(tokenId, initialPrice);
    }

    /**
     * @dev Calculate the price for a specific token based on its bonding curve
     * Price = currentBasePrice * (DEPRECIATION_RATE ^ weeksSinceLastPurchase)
     */
    function calculatePrice(uint256 tokenId) public returns (uint256) {
        require(tokenInitialPrices[tokenId] > 0, "Token initial price not set");

        uint256 price = currentBasePrices[tokenId];

        // Calculate weeks since last purchase
        uint256 timeSinceLastPurchase = block.timestamp -
            lastPurchaseTimestamp[tokenId];
        uint256 weeksSinceLastPurchase = timeSinceLastPurchase / WEEK;

        // Apply depreciation based on weeks without purchases
        for (uint256 i = 0; i < weeksSinceLastPurchase; i++) {
            price = (price * DEPRECIATION_RATE) / DENOMINATOR;
        }

        emit PriceCalculated(tokenId, price);
        return price;
    }

    /**
     * @dev View function to get the current price without emitting an event
     */
    function getCurrentPrice(uint256 tokenId) external view returns (uint256) {
        require(tokenInitialPrices[tokenId] > 0, "Token initial price not set");

        uint256 price = currentBasePrices[tokenId];
        console2.log("Base price:", price);

        // Calculate weeks since last purchase
        uint256 timeSinceLastPurchase = block.timestamp -
            lastPurchaseTimestamp[tokenId];
        uint256 weeksSinceLastPurchase = timeSinceLastPurchase / WEEK;
        console2.log("Weeks since last purchase:", weeksSinceLastPurchase);
        console2.log("Time since last purchase:", timeSinceLastPurchase);
        console2.log("Current timestamp:", block.timestamp);
        console2.log(
            "Last purchase timestamp:",
            lastPurchaseTimestamp[tokenId]
        );

        // Apply depreciation based on weeks without purchases
        for (uint256 i = 0; i < weeksSinceLastPurchase; i++) {
            price = (price * DEPRECIATION_RATE) / DENOMINATOR;
            console2.log("Price after depreciation step:", price);
        }

        return price;
    }

    /**
     * @dev Record a purchase of a token to update its bonding curve
     * @param tokenId The ID of the token that was purchased
     */
    function recordPurchase(uint256 tokenId) external {
        require(
            msg.sender == address(datasetToken),
            "Only dataset token contract can record purchases"
        );
        require(tokenInitialPrices[tokenId] > 0, "Token initial price not set");

        // Get the current price (with depreciation)
        uint256 currentPrice = calculatePrice(tokenId);

        // Set the base price to the current price
        currentBasePrices[tokenId] = currentPrice;

        // Calculate the new price for the next purchase (1.5x)
        currentBasePrices[tokenId] =
            (currentBasePrices[tokenId] * PRICE_MULTIPLIER) /
            DENOMINATOR;

        // Reset the last purchase timestamp
        lastPurchaseTimestamp[tokenId] = block.timestamp;
        tokenPurchaseCount[tokenId]++;
    }

    /**
     * @dev Update the dataset token contract address
     * @param newDatasetTokenAddress The new address of the dataset token contract
     */
    function updateDatasetTokenAddress(
        address newDatasetTokenAddress
    ) external onlyOwner {
        require(
            newDatasetTokenAddress != address(0),
            "Invalid dataset token address"
        );
        datasetToken = DatasetToken(newDatasetTokenAddress);
    }

    /**
     * @dev Update the USDC token contract address
     * @param newUsdcAddress The new address of the USDC token contract
     */
    function updateUsdcAddress(address newUsdcAddress) external onlyOwner {
        require(newUsdcAddress != address(0), "Invalid USDC address");
        usdc = IUSDC(newUsdcAddress);
    }
}
