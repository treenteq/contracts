// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

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
        uint256 price; // Price in wei
        string[] tags; // Array of tags for the dataset
        OwnershipShare[] owners; // Array of owners with their ownership percentages
    }

    // Mapping token ID to dataset metadata
    mapping(uint256 => DatasetMetadata) public tokenMetadata;

    // Mapping from token ID to whether it's listed for sale
    mapping(uint256 => bool) public isListed;

    // Mapping from tag to token IDs
    mapping(string => uint256[]) private _tagToTokenIds;

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

    /**
     * @dev Constructor to initialize the contract.
     * @param uri The base URI for metadata.
     * @param initialOwner The address of the initial owner.
     */
    constructor(
        string memory uri,
        address initialOwner
    ) ERC1155(uri) Ownable(initialOwner) {}

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
     * @dev Mint a new dataset token with multiple owners
     */
    function mintDatasetToken(
        OwnershipShare[] memory owners,
        string memory name,
        string memory description,
        string memory contentHash,
        string memory ipfsHash,
        uint256 price,
        string[] memory tags
    ) external onlyOwner {
        require(bytes(contentHash).length > 0, "Content hash is required");
        require(bytes(ipfsHash).length > 0, "IPFS hash is required");
        require(price > 0, "Price must be greater than 0");
        require(owners.length > 0, "At least one owner required");
        require(tags.length > 0, "At least one tag required");

        validateOwnershipShares(owners);

        uint256 tokenId = _currentTokenId++;

        // Store metadata
        tokenMetadata[tokenId].name = name;
        tokenMetadata[tokenId].description = description;
        tokenMetadata[tokenId].contentHash = contentHash;
        tokenMetadata[tokenId].ipfsHash = ipfsHash;
        tokenMetadata[tokenId].price = price;
        tokenMetadata[tokenId].tags = tags;

        // Store ownership information
        for (uint256 i = 0; i < owners.length; i++) {
            tokenMetadata[tokenId].owners.push(owners[i]);
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
            price,
            tags
        );
    }

    /**
     * @dev Purchase a dataset token
     */
    function purchaseDataset(uint256 tokenId) external payable nonReentrant {
        require(isListed[tokenId], "Dataset is not listed for sale");
        require(
            msg.value == tokenMetadata[tokenId].price,
            "Incorrect payment amount"
        );

        DatasetMetadata storage metadata = tokenMetadata[tokenId];
        uint256 totalAmount = msg.value;

        // Transfer ownership shares and payments
        for (uint256 i = 0; i < metadata.owners.length; i++) {
            address owner = metadata.owners[i].owner;
            require(balanceOf(owner, tokenId) > 0, "Owner has no tokens");

            // Calculate owner's share of the payment
            uint256 ownerShare = (totalAmount * metadata.owners[i].percentage) /
                10000;

            // Transfer token
            _safeTransferFrom(owner, msg.sender, tokenId, 1, "");

            // Transfer payment
            (bool success, ) = owner.call{value: ownerShare}("");
            require(success, "Payment transfer failed");
        }

        // Prepare arrays for event
        address[] memory sellers = new address[](metadata.owners.length);
        uint256[] memory amounts = new uint256[](metadata.owners.length);
        for (uint256 i = 0; i < metadata.owners.length; i++) {
            sellers[i] = metadata.owners[i].owner;
            amounts[i] = (totalAmount * metadata.owners[i].percentage) / 10000;
        }

        emit DatasetPurchased(tokenId, msg.sender, sellers, amounts);
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
        return tokenMetadata[tokenId].tags;
    }

    /**
     * @dev Get ownership shares for a token
     */
    function getTokenOwners(
        uint256 tokenId
    ) external view returns (OwnershipShare[] memory) {
        return tokenMetadata[tokenId].owners;
    }

    /**
     * @dev Update the price of a dataset
     * @param tokenId The ID of the token
     * @param newPrice The new price in wei
     */
    function updatePrice(uint256 tokenId, uint256 newPrice) external {
        require(newPrice > 0, "Price must be greater than 0");
        require(
            tokenMetadata[tokenId].owners.length > 0,
            "Dataset has no owners"
        );
        require(
            msg.sender == tokenMetadata[tokenId].owners[0].owner,
            "Only primary owner can update price"
        );

        tokenMetadata[tokenId].price = newPrice;
        emit PriceUpdated(tokenId, newPrice);
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
     * @param tokenId The ID of the token
     */
    function getDatasetIPFSHash(
        uint256 tokenId
    ) external view returns (string memory) {
        require(
            balanceOf(msg.sender, tokenId) > 0,
            "Caller does not own this dataset"
        );
        return tokenMetadata[tokenId].ipfsHash;
    }
}
