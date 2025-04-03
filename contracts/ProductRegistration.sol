// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title ProductRegistration
 * @dev Smart contract for product registration and management
 * Only producers can register products, and admins can assign producer roles
 */
contract ProductRegistration is AccessControl {
    bytes32 public constant PRODUCER_ROLE = keccak256("PRODUCER_ROLE");
    
    enum ProductStatus { Active, Inactive, Recalled }
    
    struct Product {
        uint256 productId;
        address producer;
        string name;
        string quantity;
        string details;
        uint256 price;
        ProductStatus status;
        uint256 timestamp;
        uint256 lastUpdated;
    }
    
    mapping(uint256 => Product) public products;
    uint256 public productCounter;
    
    event ProductRegistered(
        uint256 indexed productId,
        address indexed producer,
        string name,
        string quantity,
        uint256 price,
        uint256 timestamp
    );
    
    event ProductUpdated(
        uint256 indexed productId,
        address indexed producer,
        string quantity,
        uint256 price,
        ProductStatus status,
        uint256 timestamp
    );
    
    event ProductStatusChanged(
        uint256 indexed productId,
        ProductStatus status,
        uint256 timestamp
    );
    
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PRODUCER_ROLE, msg.sender);
    }
    
    /**
     * @dev Register a new product
     * @param name Name of the product
     * @param details Detailed description of the product
     * @param quantity Quantity information
     * @param price Price in wei
     */
    function registerProduct(
        string memory name,
        string memory details,
        string memory quantity,
        uint256 price
    ) 
        public 
        onlyRole(PRODUCER_ROLE) 
    {
        require(bytes(name).length > 0, "Name cannot be empty");
        require(bytes(details).length > 0, "Details cannot be empty");
        require(bytes(quantity).length > 0, "Quantity cannot be empty");
        
        productCounter++;
        
        products[productCounter] = Product({
            productId: productCounter,
            producer: msg.sender,
            name: name,
            quantity: quantity,
            details: details,
            price: price,
            status: ProductStatus.Active,
            timestamp: block.timestamp,
            lastUpdated: block.timestamp
        });
        
        emit ProductRegistered(
            productCounter,
            msg.sender,
            name,
            quantity,
            price,
            block.timestamp
        );
    }
    
    /**
     * @dev Update an existing product
     * @param productId ID of the product to update
     * @param quantity New quantity information
     * @param price New price in wei
     * @param details New product details
     */
    function updateProduct(
        uint256 productId,
        string memory quantity,
        uint256 price,
        string memory details
    ) 
        public 
    {
        Product storage product = products[productId];
        
        require(product.productId != 0, "Product does not exist");
        require(product.producer == msg.sender || hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Not authorized");
        
        if (bytes(quantity).length > 0) {
            product.quantity = quantity;
        }
        
        if (bytes(details).length > 0) {
            product.details = details;
        }
        
        product.price = price;
        product.lastUpdated = block.timestamp;
        
        emit ProductUpdated(
            productId,
            msg.sender,
            product.quantity,
            product.price,
            product.status,
            block.timestamp
        );
    }
    
    /**
     * @dev Change the status of a product
     * @param productId ID of the product
     * @param newStatus New status to set
     */
    function changeProductStatus(uint256 productId, ProductStatus newStatus) 
        public 
    {
        Product storage product = products[productId];
        
        require(product.productId != 0, "Product does not exist");
        require(
            product.producer == msg.sender || hasRole(DEFAULT_ADMIN_ROLE, msg.sender),
            "Not authorized"
        );
        
        product.status = newStatus;
        product.lastUpdated = block.timestamp;
        
        emit ProductStatusChanged(productId, newStatus, block.timestamp);
    }
    
    /**
     * @dev Get product details
     * @param productId ID of the product
     * @return Product memory containing all product details
     */
    function getProduct(uint256 productId) public view returns (Product memory) {
        require(productId > 0 && productId <= productCounter, "Invalid product ID");
        require(products[productId].productId != 0, "Product does not exist");
        
        return products[productId];
    }
    
    /**
     * @dev Get total number of products
     * @return Total number of products registered
     */
    function getProductCount() public view returns (uint256) {
        return productCounter;
    }
    
    /**
     * @dev Grant producer role to an account
     * @param account Address to grant the role to
     */
    function grantProducerRole(address account) public onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(PRODUCER_ROLE, account);
    }
    
    /**
     * @dev Revoke producer role from an account
     * @param account Address to revoke the role from
     */
    function revokeProducerRole(address account) public onlyRole(DEFAULT_ADMIN_ROLE) {
        revokeRole(PRODUCER_ROLE, account);
    }
    
    /**
     * @dev Get products by producer
     * @param producer Address of the producer
     * @param startId Start ID for pagination
     * @param count Number of products to return
     * @return Array of Products
     */
    function getProductsByProducer(address producer, uint256 startId, uint256 count) 
        public 
        view 
        returns (Product[] memory) 
    {
        require(count > 0, "Count must be greater than zero");
        
        // Count total products by this producer
        uint256 totalProducerProducts = 0;
        for (uint256 i = startId; i <= productCounter; i++) {
            if (products[i].producer == producer) {
                totalProducerProducts++;
            }
        }
        
        // Create array to store matching products
        Product[] memory result = new Product[](totalProducerProducts);
        uint256 resultIndex = 0;
        
        // Populate the array
        for (uint256 i = startId; i <= productCounter; i++) {
            if (products[i].producer == producer) {
                result[resultIndex] = products[i];
                resultIndex++;
                
                // Stop if we've reached the desired count
                if (resultIndex >= totalProducerProducts) {
                    break;
                }
            }
        }
        
        return result;
    }
}