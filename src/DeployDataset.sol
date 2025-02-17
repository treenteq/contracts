// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {DatasetBondingCurve} from "./DatasetBondingCurve.sol";
import {IUSDC} from "./interfaces/IUSDC.sol";

contract DatasetToken is ERC1155, Ownable, ReentrancyGuard {
    // Token ID counter
    uint256 private _currentTokenId;

    struct OwnershipShare {
        address owner;
        uint256 percentage; // Percentage multiplied by 100 (e.g., 33.33% = 3333)
    }

    struct DatasetMetadata {
        string name;
        string description;
        string contentHash;
        string ipfsHash; // IPFS hash for the dataset file
        string[] tags; // Array of tags for the dataset
        OwnershipShare[] owners; // Array of owners with their ownership percentages
        uint256 price; // Current price from bonding curve (not stored, dynamically fetched)
    }

    // USDC token contract
    IUSDC public usdc;

    // Mapping token ID to dataset metadata
    mapping(uint256 => DatasetMetadata) private _tokenMetadata;

    // Mapping from token ID to whether it's listed for sale
    mapping(uint256 => bool) public isListed;

    // Mapping from tag to token IDs
    mapping(string => uint256[]) private _tagToTokenIds;

    // The Bonding Curve contract
    DatasetBondingCurve public bondingCurve;

    // Mapping to track purchased tokens by address
    mapping(address => uint256[]) private _purchasedTokens;
    mapping(address => mapping(uint256 => bool)) private _hasPurchased;

    // Events
    event DatasetTokenMinted(
        address[] owners,
        uint256[] percentages,
        uint256 indexed tokenId,
        string name,
        string contentHash,
        string ipfsHash,
        uint256 price,
        string[] tags
    );

    event DatasetPurchased(
        uint256 indexed tokenId,
        address indexed buyer,
        address[] sellers,
        uint256[] amounts
    );

    event PriceUpdated(uint256 indexed tokenId, uint256 newPrice);

    event BondingCurveUpdated(address indexed newBondingCurve);

    /**
     * @dev Constructor to initialize the contract.
     * @param uri The base URI for metadata.
     * @param initialOwner The address of the initial owner.
     * @param usdcAddress The address of the USDC contract.
     */
    constructor(
        string memory uri,
        address initialOwner,
        address usdcAddress
    ) ERC1155(uri) Ownable(initialOwner) {
        require(usdcAddress != address(0), "Invalid USDC address");
        usdc = IUSDC(usdcAddress);
    }

    /**
     * @dev Set the USDC contract address
     * @param _usdcAddress The address of the USDC contract
     */
    function setUsdcAddress(address _usdcAddress) external onlyOwner {
        require(_usdcAddress != address(0), "Invalid USDC address");
        usdc = IUSDC(_usdcAddress);
    }

    /**
     * @dev Validate ownership percentages add up to 10000 (100%)
     */
    function validateOwnershipShares(
        OwnershipShare[] memory shares
    ) internal pure {
        uint256 totalPercentage;
        for (uint256 i = 0; i < shares.length; i++) {
            require(
                shares[i].percentage > 0,
                "Percentage must be greater than 0"
            );
            require(shares[i].owner != address(0), "Invalid owner address");
            totalPercentage += shares[i].percentage;
        }
        require(totalPercentage == 10000, "Total percentage must equal 100%");
    }

    /**
     * @dev Set the bonding curve contract address
     * @param _bondingCurve The address of the bonding curve contract
     */
    function setBondingCurve(address _bondingCurve) external onlyOwner {
        require(_bondingCurve != address(0), "Invalid bonding curve address");
        bondingCurve = DatasetBondingCurve(_bondingCurve);
        emit BondingCurveUpdated(_bondingCurve);
    }

    /**
     * @dev Mint a new dataset token with multiple owners
     */
    function mintDatasetToken(
        OwnershipShare[] memory owners,
        string memory name,
        string memory description,
        string memory contentHash,
        string memory ipfsHash,
        uint256 initialPrice,
        string[] memory tags
    ) external onlyOwner {
        require(bytes(contentHash).length > 0, "Content hash is required");
        require(bytes(ipfsHash).length > 0, "IPFS hash is required");
        require(initialPrice > 0, "Initial price must be greater than 0");
        require(owners.length > 0, "At least one owner required");
        require(tags.length > 0, "At least one tag required");
        require(address(bondingCurve) != address(0), "Bonding curve not set");

        validateOwnershipShares(owners);

        uint256 tokenId = _currentTokenId++;

        // Store metadata
        _tokenMetadata[tokenId].name = name;
        _tokenMetadata[tokenId].description = description;
        _tokenMetadata[tokenId].contentHash = contentHash;
        _tokenMetadata[tokenId].ipfsHash = ipfsHash;
        _tokenMetadata[tokenId].tags = tags;

        // Initialize bonding curve for this token
        bondingCurve.setInitialPrice(tokenId, initialPrice);

        // Store ownership information
        for (uint256 i = 0; i < owners.length; i++) {
            _tokenMetadata[tokenId].owners.push(owners[i]);
            _mint(owners[i].owner, tokenId, 1, "");
        }

        // Index tags
        for (uint256 i = 0; i < tags.length; i++) {
            _tagToTokenIds[tags[i]].push(tokenId);
        }

        isListed[tokenId] = true;

        // Prepare arrays for event
        address[] memory ownerAddresses = new address[](owners.length);
        uint256[] memory percentages = new uint256[](owners.length);
        for (uint256 i = 0; i < owners.length; i++) {
            ownerAddresses[i] = owners[i].owner;
            percentages[i] = owners[i].percentage;
        }

        emit DatasetTokenMinted(
            ownerAddresses,
            percentages,
            tokenId,
            name,
            contentHash,
            ipfsHash,
            initialPrice,
            tags
        );
    }

    /**
     * @dev Purchase a dataset token using USDC
     */
    function purchaseDataset(uint256 tokenId) external nonReentrant {
        require(isListed[tokenId], "Dataset is not listed for sale");
        require(
            !_hasPurchased[msg.sender][tokenId],
            "Already purchased this dataset"
        );
        uint256 currentPrice = bondingCurve.getCurrentPrice(tokenId);
        
        // Check USDC allowance
        require(
            usdc.allowance(msg.sender, address(this)) >= currentPrice,
            "Insufficient USDC allowance"
        );

        DatasetMetadata storage metadata = _tokenMetadata[tokenId];

        // Transfer USDC from buyer to contract
        require(
            usdc.transferFrom(msg.sender, address(this), currentPrice),
            "USDC transfer failed"
        );

        // Distribute payments to owners
        for (uint256 i = 0; i < metadata.owners.length; i++) {
            address owner = metadata.owners[i].owner;

            // Calculate owner's share of the payment
            uint256 ownerShare = (currentPrice * metadata.owners[i].percentage) /
                10000;

            // Transfer USDC to owner
            require(
                usdc.transfer(owner, ownerShare),
                "USDC transfer to owner failed"
            );
        }

        // Record the purchase
        _purchasedTokens[msg.sender].push(tokenId);
        _hasPurchased[msg.sender][tokenId] = true;

        // Record the purchase in the bonding curve
        bondingCurve.recordPurchase(tokenId);

        // Prepare arrays for event
        address[] memory sellers = new address[](metadata.owners.length);
        uint256[] memory amounts = new uint256[](metadata.owners.length);
        for (uint256 i = 0; i < metadata.owners.length; i++) {
            sellers[i] = metadata.owners[i].owner;
            amounts[i] = (currentPrice * metadata.owners[i].percentage) / 10000;
        }

        emit DatasetPurchased(tokenId, msg.sender, sellers, amounts);
    }

    /**
     * @dev Get all token IDs purchased by an address
     * @param buyer The address to check
     * @return tokens Array of token IDs purchased by the buyer
     */
    function getPurchasedTokens(
        address buyer
    ) public view returns (uint256[] memory tokens) {
        return _purchasedTokens[buyer];
    }

    /**
     * @dev Check if an address has purchased a specific token
     * @param buyer The address to check
     * @param tokenId The token ID to check
     * @return bool True if the address has purchased the token
     */
    function hasPurchased(
        address buyer,
        uint256 tokenId
    ) external view returns (bool) {
        return _hasPurchased[buyer][tokenId];
    }

    /**
     * @dev Get token IDs by tag
     */
    function getTokensByTag(
        string memory tag
    ) external view returns (uint256[] memory) {
        return _tagToTokenIds[tag];
    }

    /**
     * @dev Get all tags for a token
     */
    function getTokenTags(
        uint256 tokenId
    ) external view returns (string[] memory) {
        return _tokenMetadata[tokenId].tags;
    }

    /**
     * @dev Get ownership shares for a token
     */
    function getTokenOwners(
        uint256 tokenId
    ) external view returns (OwnershipShare[] memory) {
        return _tokenMetadata[tokenId].owners;
    }

    /**
     * @dev Get the current price of a dataset from the bonding curve
     * @param tokenId The ID of the token
     * @return The current price in wei
     */
    function getCurrentPrice(uint256 tokenId) public view returns (uint256) {
        require(address(bondingCurve) != address(0), "Bonding curve not set");
        return bondingCurve.getCurrentPrice(tokenId);
    }

    /**
     * @dev Get dataset metadata including current price
     */
    function getDatasetMetadata(
        uint256 tokenId
    )
        external
        view
        returns (
            string memory name,
            string memory description,
            string memory contentHash,
            string memory ipfsHash,
            uint256 currentPrice,
            string[] memory tags
        )
    {
        DatasetMetadata storage metadata = _tokenMetadata[tokenId];
        return (
            metadata.name,
            metadata.description,
            metadata.contentHash,
            metadata.ipfsHash,
            getCurrentPrice(tokenId),
            metadata.tags
        );
    }

    /**
     * @dev Get all dataset metadata for all tokens
     * @return allMetadata An array of all dataset metadata including current prices
     */
    function getAllDatasetMetadata()
        external
        view
        returns (DatasetMetadata[] memory allMetadata)
    {
        uint256 totalTokens = _currentTokenId;
        allMetadata = new DatasetMetadata[](totalTokens);

        for (uint256 i = 0; i < totalTokens; i++) {
            DatasetMetadata storage metadata = _tokenMetadata[i];
            allMetadata[i].name = metadata.name;
            allMetadata[i].description = metadata.description;
            allMetadata[i].contentHash = metadata.contentHash;
            allMetadata[i].ipfsHash = metadata.ipfsHash;
            allMetadata[i].tags = metadata.tags;
            allMetadata[i].owners = metadata.owners;
            allMetadata[i].price = getCurrentPrice(i);
        }

        return allMetadata;
    }

    /**
     * @dev Get the total number of tokens minted
     */
    function getTotalTokens() public view returns (uint256) {
        return _currentTokenId;
    }

    /**
     * @dev Get all token IDs owned by an address
     * @param owner The address to check
     */
    function getTokensByOwner(
        address owner
    ) public view returns (uint256[] memory) {
        uint256[] memory ownedTokens = new uint256[](_currentTokenId);
        uint256 ownedCount = 0;

        for (uint256 i = 0; i < _currentTokenId; i++) {
            if (balanceOf(owner, i) > 0) {
                ownedTokens[ownedCount] = i;
                ownedCount++;
            }
        }

        // Resize array to actual owned count
        uint256[] memory result = new uint256[](ownedCount);
        for (uint256 i = 0; i < ownedCount; i++) {
            result[i] = ownedTokens[i];
        }

        return result;
    }

    /**
     * @dev Get the IPFS hash for a purchased dataset
     */
    function getDatasetIPFSHash(
        uint256 tokenId
    ) external view returns (string memory) {
        require(
            balanceOf(msg.sender, tokenId) > 0,
            "Caller does not own this dataset"
        );
        return _tokenMetadata[tokenId].ipfsHash;
    }
}
