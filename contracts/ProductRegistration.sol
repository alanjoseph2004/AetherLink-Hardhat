// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title ProductTransportMarketplace
 * @dev Smart contract integrating product registration and transportation auctions
 */
contract ProductTransportMarketplace is AccessControl {
    bytes32 public constant PRODUCER_ROLE = keccak256("PRODUCER_ROLE");
    bytes32 public constant CARRIER_ROLE = keccak256("CARRIER_ROLE");
    
    // Product Definitions
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
        uint256 auctionId; // Reference to auction if one exists (0 if none)
    }
    
    // Auction Definitions
    enum AuctionStatus { Active, Completed, Cancelled }
    
    struct Auction {
        uint256 auctionId;
        uint256 productId; // Reference to the registered product
        string title;               
        string description;         
        address producer;          
        uint256 startTime;
        uint256 endTime;
        string originLocation;      
        string destinationLocation; 
        uint256 startingPrice;      
        uint256 currentLowestBid;   
        address lowestBidder;       
        uint256 bidCount;           
        AuctionStatus status;
        string specialRequirements; 
        uint256 weight;             
        uint256 lastUpdated;
    }
    
    struct Bid {
        address carrier;
        uint256 amount;
        uint256 timestamp;
        string notes;
    }
    
    // Storage
    mapping(uint256 => Product) public products;
    uint256 public productCounter;
    
    mapping(uint256 => Auction) public auctions;
    mapping(uint256 => Bid[]) public auctionBids;
    uint256 public auctionCounter;
    
    // Events for Products
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
    
    // Events for Auctions
    event AuctionCreated(
        uint256 indexed auctionId,
        uint256 indexed productId,
        string title,
        address indexed producer,
        uint256 startTime,
        uint256 endTime,
        uint256 startingPrice
    );
    
    event BidPlaced(
        uint256 indexed auctionId,
        address indexed carrier,
        uint256 amount,
        uint256 timestamp
    );
    
    event AuctionCompleted(
        uint256 indexed auctionId,
        uint256 indexed productId,
        address indexed winner,
        uint256 lowestBid,
        uint256 timestamp
    );
    
    event AuctionCancelled(
        uint256 indexed auctionId,
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
     * @return productId ID of the newly registered product
     */
    function registerProduct(
        string memory name,
        string memory details,
        string memory quantity,
        uint256 price
    ) 
        public 
        onlyRole(PRODUCER_ROLE)
        returns (uint256)
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
            lastUpdated: block.timestamp,
            auctionId: 0 // No auction yet
        });
        
        emit ProductRegistered(
            productCounter,
            msg.sender,
            name,
            quantity,
            price,
            block.timestamp
        );
        
        return productCounter;
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
     * @dev Create a new auction for a registered product
     * @param productId ID of the registered product
     * @param title Title of the auction
     * @param description Detailed description
     * @param duration Duration of the auction in seconds
     * @param originLocation Starting location
     * @param destinationLocation Ending location
     * @param startingPrice Starting price in wei
     * @param specialRequirements Any special requirements
     * @param weight Weight in kg if applicable
     * @return auctionId ID of the newly created auction
     */
    function createProductAuction(
        uint256 productId,
        string memory title,
        string memory description,
        uint256 duration,
        string memory originLocation,
        string memory destinationLocation,
        uint256 startingPrice,
        string memory specialRequirements,
        uint256 weight
    ) 
        public 
        onlyRole(PRODUCER_ROLE)
        returns (uint256)
    {
        Product storage product = products[productId];
        
        require(product.productId != 0, "Product does not exist");
        require(product.producer == msg.sender, "Only product producer can create auction");
        require(product.status == ProductStatus.Active, "Product must be active");
        require(product.auctionId == 0, "Product already has an active auction");
        
        require(bytes(title).length > 0, "Title cannot be empty");
        require(bytes(description).length > 0, "Description cannot be empty");
        require(duration > 0, "Auction duration must be greater than zero");
        require(bytes(originLocation).length > 0, "Origin location cannot be empty");
        require(bytes(destinationLocation).length > 0, "Destination location cannot be empty");
        
        auctionCounter++;
        
        auctions[auctionCounter] = Auction({
            auctionId: auctionCounter,
            productId: productId,
            title: title,
            description: description,
            producer: msg.sender,
            startTime: block.timestamp,
            endTime: block.timestamp + duration,
            originLocation: originLocation,
            destinationLocation: destinationLocation,
            startingPrice: startingPrice,
            currentLowestBid: startingPrice,
            lowestBidder: address(0),
            bidCount: 0,
            status: AuctionStatus.Active,
            specialRequirements: specialRequirements,
            weight: weight,
            lastUpdated: block.timestamp
        });
        
        // Link the product to this auction
        product.auctionId = auctionCounter;
        
        emit AuctionCreated(
            auctionCounter,
            productId,
            title,
            msg.sender,
            block.timestamp,
            block.timestamp + duration,
            startingPrice
        );
        
        return auctionCounter;
    }
    
    /**
     * @dev Place a bid on an auction
     * @param auctionId ID of the auction
     * @param bidAmount Bid amount in wei
     * @param notes Optional notes from carrier
     */
    function placeBid(uint256 auctionId, uint256 bidAmount, string memory notes) 
        public 
        onlyRole(CARRIER_ROLE) 
    {
        Auction storage auction = auctions[auctionId];
        
        require(auction.auctionId != 0, "Auction does not exist");
        require(auction.status == AuctionStatus.Active, "Auction is not active");
        require(block.timestamp < auction.endTime, "Auction has ended");
        require(bidAmount < auction.currentLowestBid, "Bid must be lower than current lowest bid");
        
        // Ensure the associated product is still active
        Product storage product = products[auction.productId];
        require(product.status == ProductStatus.Active, "Product is no longer active");
        
        auction.lowestBidder = msg.sender;
        auction.currentLowestBid = bidAmount;
        auction.bidCount++;
        auction.lastUpdated = block.timestamp;
        
        // Store the bid in the auction's bid history
        auctionBids[auctionId].push(Bid({
            carrier: msg.sender,
            amount: bidAmount,
            timestamp: block.timestamp,
            notes: notes
        }));
        
        emit BidPlaced(auctionId, msg.sender, bidAmount, block.timestamp);
    }
    
    /**
     * @dev Complete an auction and award to lowest bidder
     * @param auctionId ID of the auction to complete
     */
    function completeAuction(uint256 auctionId) public {
        Auction storage auction = auctions[auctionId];
        
        require(auction.auctionId != 0, "Auction does not exist");
        require(auction.status == AuctionStatus.Active, "Auction is not active");
        require(
            block.timestamp >= auction.endTime || 
            msg.sender == auction.producer || 
            hasRole(DEFAULT_ADMIN_ROLE, msg.sender),
            "Only producer or admin can complete auction early, or auction must have reached end time"
        );
        
        // Mark the auction as completed
        auction.status = AuctionStatus.Completed;
        auction.lastUpdated = block.timestamp;
        
        emit AuctionCompleted(
            auctionId,
            auction.productId,
            auction.lowestBidder,
            auction.currentLowestBid,
            block.timestamp
        );
    }
    
    /**
     * @dev Cancel an auction (only by producer or admin)
     * @param auctionId ID of the auction to cancel
     */
    function cancelAuction(uint256 auctionId) public {
        Auction storage auction = auctions[auctionId];
        
        require(auction.auctionId != 0, "Auction does not exist");
        require(auction.status == AuctionStatus.Active, "Auction is not active");
        require(
            auction.producer == msg.sender || hasRole(DEFAULT_ADMIN_ROLE, msg.sender),
            "Not authorized"
        );
        
        // Mark the auction as cancelled
        auction.status = AuctionStatus.Cancelled;
        auction.lastUpdated = block.timestamp;
        
        // Remove the auction reference from the product
        Product storage product = products[auction.productId];
        product.auctionId = 0;
        
        emit AuctionCancelled(auctionId, block.timestamp);
    }
    
    /**
     * @dev Get auction details
     * @param auctionId ID of the auction
     * @return Auction memory containing all auction details
     */
    function getAuction(uint256 auctionId) public view returns (Auction memory) {
        require(auctionId > 0 && auctionId <= auctionCounter, "Invalid auction ID");
        require(auctions[auctionId].auctionId != 0, "Auction does not exist");
        
        return auctions[auctionId];
    }
    
    /**
     * @dev Get all bids for an auction
     * @param auctionId ID of the auction
     * @return Array of Bids
     */
    function getAuctionBids(uint256 auctionId) public view returns (Bid[] memory) {
        require(auctionId > 0 && auctionId <= auctionCounter, "Invalid auction ID");
        require(auctions[auctionId].auctionId != 0, "Auction does not exist");
        
        return auctionBids[auctionId];
    }
    
    /**
     * @dev Get all products by a specific producer
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
        for (uint256 i = startId; i <= productCounter && totalProducerProducts < count; i++) {
            if (products[i].producer == producer) {
                totalProducerProducts++;
            }
        }
        
        // Create array to store matching products
        Product[] memory result = new Product[](totalProducerProducts);
        uint256 resultIndex = 0;
        
        // Populate the array
        for (uint256 i = startId; i <= productCounter && resultIndex < totalProducerProducts; i++) {
            if (products[i].producer == producer) {
                result[resultIndex] = products[i];
                resultIndex++;
            }
        }
        
        return result;
    }
    
    /**
     * @dev Get active auctions
     * @param startId Start ID for pagination
     * @param count Number of auctions to return
     * @return Array of Auctions
     */
    function getActiveAuctions(uint256 startId, uint256 count) 
        public 
        view 
        returns (Auction[] memory) 
    {
        require(count > 0, "Count must be greater than zero");
        
        uint256 resultCount = 0;
        
        // Count active auctions
        for (uint256 i = startId; i <= auctionCounter && resultCount < count; i++) {
            if (auctions[i].status == AuctionStatus.Active) {
                resultCount++;
            }
        }
        
        // Create array of appropriate size
        Auction[] memory result = new Auction[](resultCount);
        
        // Populate the array
        uint256 resultIndex = 0;
        for (uint256 i = startId; i <= auctionCounter && resultIndex < resultCount; i++) {
            if (auctions[i].status == AuctionStatus.Active) {
                result[resultIndex] = auctions[i];
                resultIndex++;
            }
        }
        
        return result;
    }
    
    /**
     * @dev Get products that don't have auctions yet
     * @param producer Address of the producer
     * @return Array of Products without auctions
     */
    function getProductsWithoutAuctions(address producer) 
        public 
        view 
        returns (Product[] memory) 
    {
        uint256 resultCount = 0;
        
        // Count products by this producer that don't have auctions
        for (uint256 i = 1; i <= productCounter; i++) {
            if (products[i].producer == producer && products[i].auctionId == 0 && products[i].status == ProductStatus.Active) {
                resultCount++;
            }
        }
        
        // Create array of appropriate size
        Product[] memory result = new Product[](resultCount);
        
        // Populate the array
        uint256 resultIndex = 0;
        for (uint256 i = 1; i <= productCounter && resultIndex < resultCount; i++) {
            if (products[i].producer == producer && products[i].auctionId == 0 && products[i].status == ProductStatus.Active) {
                result[resultIndex] = products[i];
                resultIndex++;
            }
        }
        
        return result;
    }
    
    /**
     * @dev Grant producer role to an account
     * @param account Address to grant the role to
     */
    function grantProducerRole(address account) public onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(PRODUCER_ROLE, account);
    }
    
    /**
     * @dev Grant carrier role to an account
     * @param account Address to grant the role to
     */
    function grantCarrierRole(address account) public onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(CARRIER_ROLE, account);
    }
    
    /**
     * @dev Revoke producer role from an account
     * @param account Address to revoke the role from
     */
    function revokeProducerRole(address account) public onlyRole(DEFAULT_ADMIN_ROLE) {
        revokeRole(PRODUCER_ROLE, account);
    }
    
    /**
     * @dev Revoke carrier role from an account
     * @param account Address to revoke the role from
     */
    function revokeCarrierRole(address account) public onlyRole(DEFAULT_ADMIN_ROLE) {
        revokeRole(CARRIER_ROLE, account);
    }
    
    /**
     * @dev Check if an auction has ended and needs to be finalized
     * @param auctionId ID of the auction
     * @return boolean indicating if auction needs to be completed
     */
    function isAuctionEnded(uint256 auctionId) public view returns (bool) {
        Auction storage auction = auctions[auctionId];
        return (auction.status == AuctionStatus.Active && block.timestamp >= auction.endTime);
    }
    
    /**
     * @dev Get time remaining for an auction in seconds
     * @param auctionId ID of the auction
     * @return seconds remaining, 0 if auction ended
     */
    function getTimeRemaining(uint256 auctionId) public view returns (uint256) {
        Auction storage auction = auctions[auctionId];
        if (auction.status != AuctionStatus.Active || block.timestamp >= auction.endTime) {
            return 0;
        }
        return auction.endTime - block.timestamp;
    }
}