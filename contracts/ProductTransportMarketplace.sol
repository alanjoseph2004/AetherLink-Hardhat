// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";

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
    
    // Transport Definitions
    enum TransportStatus { 
        NotStarted,
        InTransit,
        Delivered,
        Delayed,
        Disputed
    }

    struct Checkpoint {
        uint256 checkpointId;
        string location;
        uint256 timestamp;
        string notes;
        address updatedBy;
    }

    struct TransportRecord {
        uint256 transportId;
        uint256 auctionId;
        uint256 productId;
        address carrier;
        address producer;
        string originLocation;
        string destinationLocation;
        uint256 startTime;
        uint256 estimatedDeliveryTime;
        uint256 actualDeliveryTime;
        TransportStatus status;
        uint256 checkpointCount;
        bool producerConfirmed;
    }
    
    // Storage
    mapping(uint256 => Product) public products;
    uint256 public productCounter;
    
    mapping(uint256 => Auction) public auctions;
    mapping(uint256 => Bid[]) public auctionBids;
    uint256 public auctionCounter;
    
    mapping(uint256 => TransportRecord) public transportRecords;
    mapping(uint256 => mapping(uint256 => Checkpoint)) public transportCheckpoints;
    uint256 public transportCounter;
    
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
    
    // Events for Transport
    event TransportEvent(
        uint256 indexed transportId,
        uint256 indexed productId,
        string eventType,
        address actor,
        uint256 timestamp
    );

    event CheckpointAdded(
        uint256 indexed transportId,
        uint256 indexed checkpointId,
        string location,
        uint256 timestamp
    );
    
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PRODUCER_ROLE, msg.sender);
    }
    
    // PRODUCT FUNCTIONS
    
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
    
    function getProduct(uint256 productId) public view returns (Product memory) {
        require(productId > 0 && productId <= productCounter, "Invalid product ID");
        require(products[productId].productId != 0, "Product does not exist");
        
        return products[productId];
    }
    
    // AUCTION FUNCTIONS
    
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
    
    function getAuction(uint256 auctionId) public view returns (Auction memory) {
        require(auctionId > 0 && auctionId <= auctionCounter, "Invalid auction ID");
        require(auctions[auctionId].auctionId != 0, "Auction does not exist");
        
        return auctions[auctionId];
    }
    
    function getAuctionBids(uint256 auctionId) public view returns (Bid[] memory) {
        require(auctionId > 0 && auctionId <= auctionCounter, "Invalid auction ID");
        require(auctions[auctionId].auctionId != 0, "Auction does not exist");
        
        return auctionBids[auctionId];
    }
    
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
    
    // TRANSPORT FUNCTIONS
    
    function createTransport(
        uint256 auctionId,
        uint256 estimatedDeliveryTime
    ) 
        public
        returns (uint256)
    {
        Auction storage auction = auctions[auctionId];
        
        require(auction.auctionId != 0, "Auction does not exist");
        require(auction.status == AuctionStatus.Completed, "Auction must be completed");
        require(auction.lowestBidder == msg.sender, "Only winning carrier can create transport");
        
        // Get the associated product
        Product storage product = products[auction.productId];
        require(product.status == ProductStatus.Active, "Product must be active");
        
        transportCounter++;
        
        transportRecords[transportCounter] = TransportRecord({
            transportId: transportCounter,
            auctionId: auctionId,
            productId: auction.productId,
            carrier: msg.sender,
            producer: auction.producer,
            originLocation: auction.originLocation,
            destinationLocation: auction.destinationLocation,
            startTime: block.timestamp,
            estimatedDeliveryTime: estimatedDeliveryTime,
            actualDeliveryTime: 0,
            status: TransportStatus.InTransit,
            checkpointCount: 0,
            producerConfirmed: false
        });
        
        emit TransportEvent(
            transportCounter,
            auction.productId,
            "CREATED",
            msg.sender,
            block.timestamp
        );
        
        return transportCounter;
    }
    
    function addCheckpoint(
        uint256 transportId,
        string memory location,
        string memory notes
    ) 
        public
    {
        TransportRecord storage transport = transportRecords[transportId];
        
        require(transport.transportId != 0, "Transport does not exist");
        require(transport.carrier == msg.sender, "Only carrier can add checkpoints");
        require(transport.status == TransportStatus.InTransit || transport.status == TransportStatus.Delayed, 
            "Transport must be in transit or delayed");
        
        // Increment checkpoint counter
        transport.checkpointCount++;
        
        // Add the new checkpoint
        uint256 checkpointId = transport.checkpointCount;
        transportCheckpoints[transportId][checkpointId] = Checkpoint({
            checkpointId: checkpointId,
            location: location,
            timestamp: block.timestamp,
            notes: notes,
            updatedBy: msg.sender
        });
        
        emit CheckpointAdded(
            transportId,
            checkpointId,
            location,
            block.timestamp
        );
    }
    
    function updateTransportStatus(
        uint256 transportId,
        TransportStatus newStatus,
        string memory notes
    ) 
        public
    {
        TransportRecord storage transport = transportRecords[transportId];
        
        require(transport.transportId != 0, "Transport does not exist");
        require(
            transport.carrier == msg.sender || 
            transport.producer == msg.sender || 
            hasRole(DEFAULT_ADMIN_ROLE, msg.sender),
            "Not authorized"
        );
        
        // Special validation for certain status changes
        if (newStatus == TransportStatus.Delivered) {
            require(transport.carrier == msg.sender, "Only carrier can mark as delivered");
            transport.actualDeliveryTime = block.timestamp;
        }
        
        transport.status = newStatus;
        
        // Add an automatic checkpoint for status updates
        transport.checkpointCount++;
        transportCheckpoints[transportId][transport.checkpointCount] = Checkpoint({
            checkpointId: transport.checkpointCount,
            location: "Status Update",
            timestamp: block.timestamp,
            notes: notes,
            updatedBy: msg.sender
        });
        
        emit TransportEvent(
            transportId,
            transport.productId,
            "STATUS_UPDATED",
            msg.sender,
            block.timestamp
        );
    }
    
    function completeDelivery(
        uint256 transportId,
        string memory finalLocation
    ) 
        public
    {
        TransportRecord storage transport = transportRecords[transportId];
        
        require(transport.transportId != 0, "Transport does not exist");
        require(transport.carrier == msg.sender, "Only carrier can complete delivery");
        require(
            transport.status == TransportStatus.InTransit || 
            transport.status == TransportStatus.Delayed,
            "Transport must be in transit or delayed"
        );
        
        transport.status = TransportStatus.Delivered;
        transport.actualDeliveryTime = block.timestamp;
        
        // Add final checkpoint
        transport.checkpointCount++;
        transportCheckpoints[transportId][transport.checkpointCount] = Checkpoint({
            checkpointId: transport.checkpointCount,
            location: finalLocation,
            timestamp: block.timestamp,
            notes: "Delivery completed",
            updatedBy: msg.sender
        });
        
        emit TransportEvent(
            transportId,
            transport.productId,
            "DELIVERED",
            msg.sender,
            block.timestamp
        );
    }
    
    function confirmDelivery(uint256 transportId) public {
        TransportRecord storage transport = transportRecords[transportId];
        
        require(transport.transportId != 0, "Transport does not exist");
        require(transport.producer == msg.sender, "Only producer can confirm");
        require(transport.status == TransportStatus.Delivered, "Must be delivered first");
        require(!transport.producerConfirmed, "Already confirmed");
        
        transport.producerConfirmed = true;
        
        emit TransportEvent(
            transportId,
            transport.productId,
            "CONFIRMED",
            msg.sender,
            block.timestamp
        );
    }
    
    function raiseDispute(uint256 transportId, string memory reason) public {
        TransportRecord storage transport = transportRecords[transportId];
        
        require(transport.transportId != 0, "Transport does not exist");
        require(
            transport.carrier == msg.sender || 
            transport.producer == msg.sender,
            "Only carrier or producer can dispute"
        );
        
        transport.status = TransportStatus.Disputed;
        
        // Add dispute checkpoint
        transport.checkpointCount++;
        transportCheckpoints[transportId][transport.checkpointCount] = Checkpoint({
            checkpointId: transport.checkpointCount,
            location: "Dispute",
            timestamp: block.timestamp,
            notes: reason,
            updatedBy: msg.sender
        });
        
        emit TransportEvent(
            transportId,
            transport.productId,
            "DISPUTED",
            msg.sender,
            block.timestamp
        );
    }
    
    function getTransportCheckpoints(uint256 transportId) public view returns (Checkpoint[] memory) {
        TransportRecord storage transport = transportRecords[transportId];
        require(transport.transportId != 0, "Transport does not exist");
        
        Checkpoint[] memory checkpoints = new Checkpoint[](transport.checkpointCount);
        for (uint256 i = 1; i <= transport.checkpointCount; i++) {
            checkpoints[i-1] = transportCheckpoints[transportId][i];
        }
        return checkpoints;
    }
    
    function getTransport(uint256 transportId) public view returns (TransportRecord memory) {
        require(transportId > 0 && transportId <= transportCounter, "Invalid ID");
        require(transportRecords[transportId].transportId != 0, "Transport does not exist");
        return transportRecords[transportId];
    }
    
    function isTransportDelayed(uint256 transportId) public view returns (bool) {
        TransportRecord storage transport = transportRecords[transportId];
        require(transport.transportId != 0, "Transport does not exist");
        
        if (transport.status == TransportStatus.Delayed) {
            return true;
        }
        
        if (transport.status == TransportStatus.Delivered) {
            return false;
        }
        
        return (block.timestamp > transport.estimatedDeliveryTime);
    }
    
    // ROLE MANAGEMENT FUNCTIONS
    
    function grantProducerRole(address account) public onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(PRODUCER_ROLE, account);
    }
    
    function grantCarrierRole(address account) public onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(CARRIER_ROLE, account);
    }

    function revokeProducerRole(address account) public onlyRole(DEFAULT_ADMIN_ROLE) {
        revokeRole(PRODUCER_ROLE, account);
    }
    
    function revokeCarrierRole(address account) public onlyRole(DEFAULT_ADMIN_ROLE) {
        revokeRole(CARRIER_ROLE, account);
    }
    
    // UTILITY FUNCTIONS
    
    function isAuctionEnded(uint256 auctionId) public view returns (bool) {
        Auction storage auction = auctions[auctionId];
        return (auction.status == AuctionStatus.Active && block.timestamp >= auction.endTime);
    }
    
    function getTimeRemaining(uint256 auctionId) public view returns (uint256) {
        Auction storage auction = auctions[auctionId];
        if (auction.status != AuctionStatus.Active || block.timestamp >= auction.endTime) {
            return 0;
        }
        return auction.endTime - block.timestamp;
    }
}