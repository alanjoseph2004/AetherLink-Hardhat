// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title Bidding
 * @dev Smart contract for transport bidding system with enhanced features
 */
contract Bidding is AccessControl {
    bytes32 public constant PRODUCER_ROLE = keccak256("PRODUCER_ROLE");
    bytes32 public constant CARRIER_ROLE = keccak256("CARRIER_ROLE");

    enum ContractStatus { Open, Awarded, Completed, Cancelled }

    struct Bid {
        uint256 contractId;
        address carrier;
        uint256 amount;
        string estimatedDeliveryTime;
        uint256 timestamp;
        bool isActive;
    }

    struct TransportationContract {
        uint256 contractId;
        address producer;
        string details;
        string pickupLocation;
        string deliveryLocation;
        uint256 weight;
        uint256 startTime;
        uint256 endTime;
        ContractStatus status;
        address awardedCarrier;
        uint256 awardedAmount;
        uint256 bidsCount;
        mapping(uint256 => Bid) bids;
        mapping(address => bool) hasBid;
        mapping(address => uint256) carrierBidIndex;
    }

    mapping(uint256 => TransportationContract) public contracts;
    uint256 public contractCounter;

    event TransportationContractCreated(
        uint256 indexed contractId, 
        address indexed producer, 
        string details, 
        string pickupLocation, 
        string deliveryLocation,
        uint256 weight,
        uint256 startTime, 
        uint256 endTime
    );
    
    event BidPlaced(
        uint256 indexed contractId, 
        address indexed carrier, 
        uint256 amount,
        string estimatedDeliveryTime
    );
    
    event BidUpdated(
        uint256 indexed contractId, 
        address indexed carrier, 
        uint256 newAmount,
        string estimatedDeliveryTime
    );
    
    event BidCancelled(
        uint256 indexed contractId, 
        address indexed carrier
    );
    
    event ContractAwarded(
        uint256 indexed contractId, 
        address indexed awardedCarrier, 
        uint256 awardedAmount
    );
    
    event ContractStatusChanged(
        uint256 indexed contractId,
        ContractStatus status
    );

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PRODUCER_ROLE, msg.sender);
        _grantRole(CARRIER_ROLE, msg.sender);
    }

    /**
     * @dev Create a new transportation contract
     * @param details Contract details
     * @param pickupLocation Location for pickup
     * @param deliveryLocation Location for delivery
     * @param weight Weight of goods in kg
     * @param endTime End time for bidding
     */
    function createTransportContract(
        string memory details, 
        string memory pickupLocation,
        string memory deliveryLocation,
        uint256 weight,
        uint256 endTime
    ) 
        public 
        onlyRole(PRODUCER_ROLE) 
    {
        require(endTime > block.timestamp, "End time must be in the future");
        require(bytes(details).length > 0, "Details cannot be empty");
        require(bytes(pickupLocation).length > 0, "Pickup location cannot be empty");
        require(bytes(deliveryLocation).length > 0, "Delivery location cannot be empty");
        require(weight > 0, "Weight must be greater than zero");

        contractCounter++;
        TransportationContract storage newContract = contracts[contractCounter]; // Get storage reference
        newContract.contractId = contractCounter;
        newContract.producer = msg.sender;
        newContract.details = details;
        newContract.pickupLocation = pickupLocation;
        newContract.deliveryLocation = deliveryLocation;
        newContract.weight = weight;
        newContract.startTime = block.timestamp;
        newContract.endTime = endTime;
        newContract.status = ContractStatus.Open;
        newContract.awardedCarrier = address(0);
        newContract.awardedAmount = 0;
        newContract.bidsCount = 0;

        emit TransportationContractCreated(
            contractCounter, 
            msg.sender, 
            details, 
            pickupLocation, 
            deliveryLocation,
            weight,
            block.timestamp, 
            endTime
        );
    }

    /**
     * @dev Place a new bid on a transportation contract
     * @param contractId ID of the contract
     * @param amount Bid amount in wei
     * @param estimatedDeliveryTime Estimated delivery time description
     */
    function placeBid(
        uint256 contractId, 
        uint256 amount,
        string memory estimatedDeliveryTime
    ) 
        public 
        onlyRole(CARRIER_ROLE)
    {
        TransportationContract storage transportContract = contracts[contractId];
        require(transportContract.contractId > 0, "Contract does not exist");
        require(block.timestamp < transportContract.endTime, "Bidding period has ended");
        require(transportContract.status == ContractStatus.Open, "Contract is not open for bidding");
        require(transportContract.producer != msg.sender, "Producer cannot bid on own contract");
        
        // If carrier already placed a bid, update it instead
        if (transportContract.hasBid[msg.sender]) {
            updateBid(contractId, amount, estimatedDeliveryTime);
            return;
        }

        uint256 bidIndex = transportContract.bidsCount;
        transportContract.bids[bidIndex] = Bid({
            contractId: contractId,
            carrier: msg.sender,
            amount: amount,
            estimatedDeliveryTime: estimatedDeliveryTime,
            timestamp: block.timestamp,
            isActive: true
        });
        
        transportContract.hasBid[msg.sender] = true;
        transportContract.carrierBidIndex[msg.sender] = bidIndex;
        transportContract.bidsCount++;

        emit BidPlaced(contractId, msg.sender, amount, estimatedDeliveryTime);
    }
    
    /**
     * @dev Update an existing bid
     * @param contractId ID of the contract
     * @param newAmount New bid amount
     * @param estimatedDeliveryTime Updated estimated delivery time
     */
    function updateBid(
        uint256 contractId, 
        uint256 newAmount,
        string memory estimatedDeliveryTime
    ) 
        public 
        onlyRole(CARRIER_ROLE)
    {
        TransportationContract storage transportContract = contracts[contractId];
        require(transportContract.contractId > 0, "Contract does not exist");
        require(block.timestamp < transportContract.endTime, "Bidding period has ended");
        require(transportContract.status == ContractStatus.Open, "Contract is not open for bidding");
        require(transportContract.hasBid[msg.sender], "No existing bid to update");
        
        uint256 bidIndex = transportContract.carrierBidIndex[msg.sender];
        Bid storage existingBid = transportContract.bids[bidIndex];
        
        require(existingBid.isActive, "Bid is not active");
        
        existingBid.amount = newAmount;
        existingBid.estimatedDeliveryTime = estimatedDeliveryTime;
        existingBid.timestamp = block.timestamp;
        
        emit BidUpdated(contractId, msg.sender, newAmount, estimatedDeliveryTime);
    }
    
    /**
     * @dev Cancel an existing bid
     * @param contractId ID of the contract
     */
    function cancelBid(uint256 contractId) public onlyRole(CARRIER_ROLE) {
        TransportationContract storage transportContract = contracts[contractId];
        require(transportContract.contractId > 0, "Contract does not exist");
        require(block.timestamp < transportContract.endTime, "Bidding period has ended");
        require(transportContract.status == ContractStatus.Open, "Contract is not open for bidding");
        require(transportContract.hasBid[msg.sender], "No existing bid to cancel");
        
        uint256 bidIndex = transportContract.carrierBidIndex[msg.sender];
        Bid storage existingBid = transportContract.bids[bidIndex];
        
        require(existingBid.isActive, "Bid already inactive");
        
        existingBid.isActive = false;
        
        emit BidCancelled(contractId, msg.sender);
    }

    /**
     * @dev Award contract to the lowest bidder
     * @param contractId ID of the contract
     */
    function awardContract(uint256 contractId) public {
        TransportationContract storage transportContract = contracts[contractId];
        require(transportContract.contractId > 0, "Contract does not exist");
        require(
            transportContract.producer == msg.sender || hasRole(DEFAULT_ADMIN_ROLE, msg.sender),
            "Not authorized"
        );
        require(
            block.timestamp >= transportContract.endTime || 
            transportContract.producer == msg.sender || 
            hasRole(DEFAULT_ADMIN_ROLE, msg.sender), 
            "Bidding time is not over"
        );
        require(transportContract.status == ContractStatus.Open, "Contract not open for awarding");

        uint256 lowestBid = type(uint256).max;
        address lowestBidder = address(0);

        for (uint256 i = 0; i < transportContract.bidsCount; i++) {
            Bid storage bid = transportContract.bids[i];
            if (bid.isActive && bid.amount < lowestBid) {
                lowestBid = bid.amount;
                lowestBidder = bid.carrier;
            }
        }

        require(lowestBidder != address(0), "No valid bids");

        transportContract.status = ContractStatus.Awarded;
        transportContract.awardedCarrier = lowestBidder;
        transportContract.awardedAmount = lowestBid;

        emit ContractAwarded(contractId, lowestBidder, lowestBid);
        emit ContractStatusChanged(contractId, ContractStatus.Awarded);
    }
    
    /**
     * @dev Update the status of a transportation contract
     * @param contractId ID of the contract
     * @param newStatus New status to set
     */
    function updateContractStatus(uint256 contractId, ContractStatus newStatus) public {
        TransportationContract storage transportContract = contracts[contractId];
        require(transportContract.contractId > 0, "Contract does not exist");
        
        // Validate authorization and status transitions
        if (newStatus == ContractStatus.Completed) {
            require(
                transportContract.producer == msg.sender || 
                hasRole(DEFAULT_ADMIN_ROLE, msg.sender),
                "Only producer or admin can mark as completed"
            );
            require(transportContract.status == ContractStatus.Awarded, "Contract must be awarded first");
        } else if (newStatus == ContractStatus.Cancelled) {
            require(
                transportContract.producer == msg.sender || 
                hasRole(DEFAULT_ADMIN_ROLE, msg.sender),
                "Only producer or admin can cancel"
            );
            require(transportContract.status != ContractStatus.Completed, "Cannot cancel completed contract");
        } else {
            revert("Invalid status transition");
        }
        
        transportContract.status = newStatus;
        
        emit ContractStatusChanged(contractId, newStatus);
    }

    /**
     * @dev Get all active bids for a contract
     * @param contractId ID of the contract
     * @return Array of active bids
     */
    function getActiveBids(uint256 contractId) public view returns (Bid[] memory) {
        TransportationContract storage transportContract = contracts[contractId];
        require(transportContract.contractId > 0, "Contract does not exist");
        
        // First, count active bids
        uint256 activeBidsCount = 0;
        for (uint256 i = 0; i < transportContract.bidsCount; i++) {
            if (transportContract.bids[i].isActive) {
                activeBidsCount++;
            }
        }
        
        // Then create and fill the array
        Bid[] memory activeBids = new Bid[](activeBidsCount);
        uint256 currentIndex = 0;
        
        for (uint256 i = 0; i < transportContract.bidsCount; i++) {
            if (transportContract.bids[i].isActive) {
                activeBids[currentIndex] = transportContract.bids[i];
                currentIndex++;
            }
        }
        
        return activeBids;
    }

    /**
     * @dev Get all bids for a contract
     * @param contractId ID of the contract
     * @return Array of all bids
     */
    function getAllBids(uint256 contractId) public view returns (Bid[] memory) {
        TransportationContract storage transportContract = contracts[contractId];
        require(transportContract.contractId > 0, "Contract does not exist");
        
        Bid[] memory bidsArray = new Bid[](transportContract.bidsCount);
        for (uint256 i = 0; i < transportContract.bidsCount; i++) {
            bidsArray[i] = transportContract.bids[i];
        }
        return bidsArray;
    }

    /**
     * @dev Get a specific bid
     * @param contractId ID of the contract
     * @param bidIndex Index of the bid
     * @return Bid memory containing bid details
     */
    function getBid(uint256 contractId, uint256 bidIndex) public view returns (Bid memory) {
        TransportationContract storage transportContract = contracts[contractId];
        require(transportContract.contractId > 0, "Contract does not exist");
        require(bidIndex < transportContract.bidsCount, "Invalid bid index");
        return transportContract.bids[bidIndex];
    }
    
    /**
     * @dev Get a carrier's bid for a contract
     * @param contractId ID of the contract
     * @param carrier Address of the carrier
     * @return Bid memory containing bid details
     */
    function getCarrierBid(uint256 contractId, address carrier) public view returns (Bid memory) {
        TransportationContract storage transportContract = contracts[contractId];
        require(transportContract.contractId > 0, "Contract does not exist");
        require(transportContract.hasBid[carrier], "Carrier has no bid for this contract");
        
        uint256 bidIndex = transportContract.carrierBidIndex[carrier];
        return transportContract.bids[bidIndex];
    }
    
    /**
     * @dev Check if a carrier has placed a bid
     * @param contractId ID of the contract
     * @param carrier Address of the carrier
     * @return bool True if carrier has an active bid
     */
    function hasActiveBid(uint256 contractId, address carrier) public view returns (bool) {
        TransportationContract storage transportContract = contracts[contractId];
        if (!transportContract.hasBid[carrier]) return false;
        
        uint256 bidIndex = transportContract.carrierBidIndex[carrier];
        return transportContract.bids[bidIndex].isActive;
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
     * @dev Grant carrier role to an account
     * @param account Address to grant the role to
     */
    function grantCarrierRole(address account) public onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(CARRIER_ROLE, account);
    }
    
    /**
     * @dev Revoke carrier role from an account
     * @param account Address to revoke the role from
     */
    function revokeCarrierRole(address account) public onlyRole(DEFAULT_ADMIN_ROLE) {
        revokeRole(CARRIER_ROLE, account);
    }
}